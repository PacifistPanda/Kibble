-- Kibble: one-button hunter pet feeding for WoW Forever (1.60.1, interface 16001)
--
-- What it does
--   * One movable button (and a key binding) that casts Feed Pet on the best food in your bags.
--   * The button glows and pulses when your pet is not Happy (green).
--   * It warns you (on screen, in chat and with a sound) when you have no food your pet will eat.
--
-- Notes on WoW Forever's API (Midnight-era client)
--   * Pet info lives in C_PetInfo (GetPetHappiness, CanPetEatItem); legacy globals are only a fallback.
--   * Item/bag info lives in C_Item / C_Container.
--   * Feeding is a protected action: it only happens when YOU click the button or press its key.
--     The addon cannot feed automatically, and it cannot change the button's food during combat
--     (it catches up as soon as combat ends).
--   * Some values may be "secret" in combat; those are never compared, only skipped.

local ADDON, ns = ...
ns = ns or {}                     -- shared with Restock.lua / Panel.lua (see ns.core at the bottom)
local FEED_PET_SPELL_ID = 6991
local CALL_PET_SPELL_ID = 883
local REVIVE_PET_SPELL_ID = 982
local MEND_PET_SPELL_ID = 136
local FULL_GAIN_LEVEL_GAP = 5     -- food up to 5 levels below the pet gives full happiness
local BASE_SIZE = 40              -- reference size the fonts are scaled from
local FADED_ALPHA = 0.15          -- "only when pet isn't happy" mode: alpha while the pet is happy

-- Key binding labels (Options > Key Bindings > AddOns)
BINDING_HEADER_KIBBLE = "Kibble"
_G["BINDING_NAME_CLICK KibbleButton:LeftButton"] = "Feed pet"

local _, playerClass = UnitClass("player")
if playerClass ~= "HUNTER" then return end

---------------------------------------------------------------------------
-- Settings (saved in KibbleDB.settings; edited through the right-click menu)
---------------------------------------------------------------------------

local DEFAULTS = {
	alertScreen = true,    -- on-screen warning
	alertChat   = true,    -- red chat line
	alertSound  = false,   -- opt-in: sounds are never played unless the user turns this on
	soundChoice = "RAID_WARNING", -- key into SOUNDKIT, see SOUND_CHOICES
	hungryHint  = true,    -- "your pet is getting hungry" chat hint
	lowFood     = 0,       -- warn once when edible food drops to this many or fewer (0 = off)
	showFeeding = true,    -- countdown swipe on the button while the pet is feeding
	throttle    = 30,      -- seconds between repeated alerts
	size        = 40,
	opacity     = 1,
	locked      = false,
	showCount   = true,
	showNoFood  = true,
	foodMode    = "save",  -- "save" = cheapest food that still gives full happiness; "best" = highest level;
	                       -- "stack" = smallest stack among the foods that still give full happiness
	visibility  = "always", -- "always" | "unhappy" (fades while happy) | "hidden"
	petCare     = true,    -- the button also revives a dead pet / calls a missing one (Ctrl-click mends)
	restockTarget = 40,    -- vendor restock: buy up to this many of the chosen food
	showMinimap = true,    -- minimap button
	minimapAngle = 3.93,   -- radians around the minimap (225 degrees = bottom left)
}

local S = {}
for k, v in pairs(DEFAULTS) do S[k] = v end
S.ignored = {}             -- [itemID] = true; foods Kibble must never pick

local function LoadSettings()
	KibbleDB.settings = KibbleDB.settings or {}
	local saved = KibbleDB.settings
	for k, v in pairs(DEFAULTS) do
		if saved[k] == nil then saved[k] = v end
	end
	saved.ignored = saved.ignored or {}
	-- Settings version 2: sound alerts became opt-in. 1.1.0 defaulted them to on, so anyone who
	-- has a saved "on" from that default gets it switched off once; they can turn it back on.
	if (saved.settingsVersion or 1) < 2 then
		saved.alertSound = false
		saved.settingsVersion = 2
	end
	S = saved
end

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

local function IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v)
end

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Kibble:|r " .. msg)
end

local function SpellName(id, fallback)
	if C_Spell and C_Spell.GetSpellName then
		return C_Spell.GetSpellName(id) or fallback
	end
	return (GetSpellInfo and GetSpellInfo(id)) or fallback
end

local function SpellIcon(id, fallback)
	if C_Spell and C_Spell.GetSpellTexture then
		return C_Spell.GetSpellTexture(id) or fallback
	end
	return fallback
end

local function FeedPetName() return SpellName(FEED_PET_SPELL_ID, "Feed Pet") end
local function FeedPetIcon() return SpellIcon(FEED_PET_SPELL_ID, 132165) end

local function PetIsOut()
	return UnitExists("pet") and not UnitIsDead("pet")
end

-- "out" = living pet, "dead" = pet unit exists but is dead, "none" = no pet unit
local function PetState()
	if not UnitExists("pet") then return "none" end
	if UnitIsDead("pet") then return "dead" end
	return "out"
end

-- 1 = unhappy (red), 2 = content (yellow), 3 = happy (green); nil if unknown/restricted
local function GetHappiness()
	if not PetIsOut() then return nil end
	local h
	if C_PetInfo and C_PetInfo.GetPetHappiness then
		h = C_PetInfo.GetPetHappiness()
	elseif GetPetHappiness then
		h = GetPetHappiness()
	end
	if h == nil or IsSecret(h) then return nil end
	return h
end

local function GetPetLevel()
	local lvl = UnitLevel("pet")
	if lvl == nil or IsSecret(lvl) then return nil end
	return lvl
end

local function GetItemLevel(itemID)
	local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
	local _, _, _, itemLevel = getInfo(itemID)
	if itemLevel == nil and C_Item and C_Item.RequestLoadItemDataByID then
		C_Item.RequestLoadItemDataByID(itemID) -- GET_ITEM_INFO_RECEIVED will trigger a rescan
	end
	return itemLevel
end

local function GetItemIcon(itemID)
	if C_Item and C_Item.GetItemIconByID then
		return C_Item.GetItemIconByID(itemID)
	end
	return GetItemIcon and GetItemIcon(itemID)
end

---------------------------------------------------------------------------
-- Food selection
---------------------------------------------------------------------------

local canEatCache = {}  -- [itemID] = true/false, cleared when the pet changes or levels

local function PetCanEat(itemID)
	local cached = canEatCache[itemID]
	if cached ~= nil then return cached end
	local ok = false
	if C_PetInfo and C_PetInfo.CanPetEatItem then
		ok = C_PetInfo.CanPetEatItem(itemID) and true or false
	end
	canEatCache[itemID] = ok
	return ok
end

local NUM_BAGS = NUM_BAG_SLOTS or 4

-- Edible items in the bags as { [itemID] = count }. Ignored foods are left out unless asked for.
local function ScanFood(includeIgnored)
	local counts = {}
	for bag = 0, NUM_BAGS do
		local slots = C_Container.GetContainerNumSlots(bag) or 0
		for slot = 1, slots do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID and (includeIgnored or not S.ignored[info.itemID])
				and PetCanEat(info.itemID) then
				counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1)
			end
		end
	end
	return counts
end

-- Picks the food to use from { [itemID] = count }; returns itemID, totalCount. Also used by
-- vendor restock (Restock.lua) to pick which of a vendor's foods to buy.
local function ChooseFood(counts)
	local petLevel = GetPetLevel()

	-- rank ("save" mode): food that gives full happiness first (lowest level of those, to save
	-- better food); otherwise the highest-level food available. "stack" mode is the same but picks
	-- the smallest stack of the full-happiness foods (frees bag space). "best" mode always takes
	-- the highest level.
	local best, bestFull, bestLevel, total = nil, false, nil, 0
	for itemID, count in pairs(counts) do
		total = total + count
		local lvl = GetItemLevel(itemID) or 0
		local full = S.foodMode ~= "best" and petLevel ~= nil and lvl >= petLevel - FULL_GAIN_LEVEL_GAP
		local better
		if best == nil then
			better = true
		elseif full ~= bestFull then
			better = full
		elseif full and S.foodMode == "stack" then
			local c, bc = count, counts[best]
			better = c < bc or (c == bc and (lvl < bestLevel or (lvl == bestLevel and itemID < best)))
		elseif full then
			better = lvl < bestLevel or (lvl == bestLevel and itemID < best)
		else
			better = lvl > bestLevel or (lvl == bestLevel and itemID < best)
		end
		if better then
			best, bestFull, bestLevel = itemID, full, lvl
		end
	end

	return best, total
end

-- Returns bestItemID, countOfThatItem, totalEdibleCount
local function FindBestFood()
	if not PetIsOut() then return nil, 0, 0 end
	local counts = ScanFood(false)
	local best, total = ChooseFood(counts)
	return best, best and counts[best] or 0, total
end

---------------------------------------------------------------------------
-- The button
---------------------------------------------------------------------------

local button = CreateFrame("Button", "KibbleButton", UIParent, "SecureActionButtonTemplate")
button:SetSize(DEFAULTS.size, DEFAULTS.size) -- real size is applied from settings in ApplyLayout
button:RegisterForClicks("AnyUp", "AnyDown")
button:SetAttribute("type", "macro")
button:SetAttribute("type2", "") -- right-click opens the settings menu; it must not feed
button:SetMovable(true)
button:SetClampedToScreen(true)
button:RegisterForDrag("LeftButton")

-- Visibility is a secure state driver (shows while a living pet is out, also in combat);
-- it is registered from ApplyLayout once the saved settings are loaded.

-- Look: rounded corners using the modern action-button mask, a soft shadow,
-- a coloured happiness ring with a thin dark gap, and modern hover/press art.
-- Every atlas is checked first; if one is missing the button falls back to square corners.

local ROUND_MASK = "UI-HUD-ActionBar-IconFrame-Mask"

local function HasAtlas(name)
	return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

-- A texture with rounded corners: a solid colour or an icon, clipped by its own mask.
local function RoundedTexture(layer, sublevel, inset)
	local tex = button:CreateTexture(nil, layer, nil, sublevel)
	tex:SetPoint("TOPLEFT", -inset, inset)
	tex:SetPoint("BOTTOMRIGHT", inset, -inset)
	if HasAtlas(ROUND_MASK) then
		local mask = button:CreateMaskTexture()
		mask:SetAllPoints(tex)
		mask:SetAtlas(ROUND_MASK, false)
		tex:AddMaskTexture(mask)
	end
	return tex
end

local shadow = RoundedTexture("BACKGROUND", -8, 5)   -- soft drop shadow
shadow:SetColorTexture(0, 0, 0, 0.35)
shadow:SetPoint("TOPLEFT", -4, 3)
shadow:SetPoint("BOTTOMRIGHT", 5, -6)

local border = RoundedTexture("BACKGROUND", -6, 3)   -- happiness ring
border:SetColorTexture(0.3, 0.85, 0.4, 1)

local gap = RoundedTexture("BACKGROUND", -4, 1.5)    -- thin dark gap between ring and icon
gap:SetColorTexture(0.05, 0.05, 0.07, 1)

local icon = RoundedTexture("ARTWORK", 0, 0)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local shade = RoundedTexture("ARTWORK", 2, 0)        -- darkens the icon when there's no food
shade:SetColorTexture(0.25, 0, 0, 0.55)
shade:Hide()

local count = button:CreateFontString(nil, "OVERLAY")
count:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
count:SetPoint("BOTTOMRIGHT", -3, 3)
count:SetShadowOffset(1, -1)

local noFood = button:CreateFontString(nil, "OVERLAY")
noFood:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
noFood:SetPoint("CENTER", 0, 0)
noFood:SetTextColor(1, 0.35, 0.35)
noFood:SetText("NO\nFOOD")

-- hover / press: modern action-bar art if available, otherwise a soft rounded tint
if HasAtlas("UI-HUD-ActionBar-IconFrame-Mouseover") then
	local hl = button:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
	hl:SetAllPoints()
else
	local hl = RoundedTexture("HIGHLIGHT", 0, 0)
	hl:SetColorTexture(1, 1, 1, 0.15)
end
if HasAtlas("UI-HUD-ActionBar-IconFrame-Down") then
	local pushed = button:CreateTexture()
	pushed:SetAtlas("UI-HUD-ActionBar-IconFrame-Down")
	pushed:SetAllPoints()
	button:SetPushedTexture(pushed)
end
-- small "press" feel: nudge the icon down while held
button:HookScript("OnMouseDown", function() icon:SetPoint("TOPLEFT", 1, -1) icon:SetPoint("BOTTOMRIGHT", 1, -1) end)
button:HookScript("OnMouseUp", function() icon:SetPoint("TOPLEFT", 0, 0) icon:SetPoint("BOTTOMRIGHT", 0, 0) end)

-- countdown swipe while the pet is feeding (driven by its Feed Pet buff, see UpdateFeeding)
local feedCooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
feedCooldown:SetAllPoints(icon)
feedCooldown:SetDrawEdge(false)
feedCooldown:SetReverse(true)

-- gentle breathing pulse on the ring when the pet is not happy
local pulse = border:CreateAnimationGroup()
pulse:SetLooping("BOUNCE")
local fade = pulse:CreateAnimation("Alpha")
fade:SetFromAlpha(1)
fade:SetToAlpha(0.35)
fade:SetDuration(0.8)
fade:SetSmoothing("IN_OUT")

local HAPPY_COLORS = {
	[1] = { 0.95, 0.30, 0.30 }, -- unhappy
	[2] = { 1.00, 0.78, 0.25 }, -- content
	[3] = { 0.30, 0.85, 0.40 }, -- happy
}

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local currentFood        -- itemID the secure macro is set to
local pendingSecure = false   -- macro text needs updating once combat ends
local pendingLayout = false   -- size / visibility driver need applying once combat ends
local appliedDriver           -- visibility expression currently registered
local lastHappiness
local hadFood = nil      -- nil = unknown yet
local lastAlert = 0

-- Alert sounds offered in the menu. Only sounds that exist on this client are listed.
local SOUND_CHOICES = {
	{ "Raid warning", "RAID_WARNING" },
	{ "Whisper ping", "TELL_MESSAGE" },
	{ "Quest complete", "IG_QUEST_LIST_COMPLETE" },
	{ "Quest open", "IG_QUEST_LIST_OPEN" },
}

local function PlayAlertSound()
	local id = SOUNDKIT and (SOUNDKIT[S.soundChoice] or SOUNDKIT.RAID_WARNING)
	if id then PlaySound(id) end
end

-- Returns true if the alert was actually shown (false when throttled).
local function Alert(text)
	local now = GetTime()
	if now - lastAlert < S.throttle then return false end
	lastAlert = now
	if S.alertScreen then
		if RaidNotice_AddMessage and RaidWarningFrame then
			RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"])
		else
			UIErrorsFrame:AddMessage(text, 1, 0.2, 0.2)
		end
	end
	if S.alertChat then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff3333" .. text .. "|r")
	end
	if S.alertSound then PlayAlertSound() end
	return true
end

-- Size and visibility driver are protected, so they wait for the end of combat.
local function ApplyLayout()
	if InCombatLockdown() then
		pendingLayout = true
		return
	end
	pendingLayout = false
	local size = S.size
	button:SetSize(size, size)
	count:SetFont(STANDARD_TEXT_FONT, math.floor(12 * size / BASE_SIZE + 0.5), "OUTLINE")
	noFood:SetFont(STANDARD_TEXT_FONT, math.floor(10 * size / BASE_SIZE + 0.5), "OUTLINE")
	-- pet care: stay visible with a dead/missing pet so the button can revive / call it
	local expr = "[@pet,exists,nodead] show; hide"
	if S.visibility == "hidden" then
		expr = "hide"
	elseif S.petCare then
		expr = "show"
	end
	if expr ~= appliedDriver then
		appliedDriver = expr
		RegisterStateDriver(button, "visibility", expr)
	end
end

-- Opacity is not protected, so this works in combat. "unhappy" mode fades the button while
-- the pet is happy (or its mood is unknown).
local function UpdateAlpha(happiness)
	local alpha = S.opacity
	-- never fade it while it is offering to revive / call the pet
	if S.visibility == "unhappy" and PetIsOut() and (happiness == nil or happiness >= 3) then
		alpha = alpha * FADED_ALPHA
	end
	button:SetAlpha(alpha)
end

-- The click macro. With pet care on, the conditionals pick the action when you click, so it keeps
-- working through combat: revive a dead pet, call a missing one, Ctrl-click mends, otherwise feed.
local function BuildMacro(foodID)
	if not S.petCare then
		if foodID then
			return "/cast " .. FeedPetName() .. "\n/use item:" .. foodID
		end
		return "" -- no food: clicking just reports it
	end
	local casts = {
		"[@pet,dead] " .. SpellName(REVIVE_PET_SPELL_ID, "Revive Pet"),
		"[nopet] " .. SpellName(CALL_PET_SPELL_ID, "Call Pet"),
		"[@pet,exists,nodead,mod:ctrl] " .. SpellName(MEND_PET_SPELL_ID, "Mend Pet"),
	}
	local text
	if foodID then
		casts[#casts + 1] = "[@pet,exists,nodead] " .. FeedPetName()
		text = "/cast " .. table.concat(casts, "; ") .. "\n/use [@pet,exists,nodead,nomod:ctrl] item:" .. foodID
	else
		text = "/cast " .. table.concat(casts, "; ")
	end
	return text
end

local appliedMacroKey

local function ApplySecure(foodID)
	if InCombatLockdown() then
		pendingSecure = true
		return
	end
	pendingSecure = false
	-- the macro depends on the food and on the pet-care setting
	local key = (foodID or "none") .. (S.petCare and "+care" or "")
	if key == appliedMacroKey and button:GetAttribute("macrotext") then return end
	appliedMacroKey = key
	currentFood = foodID
	button:SetAttribute("macrotext", BuildMacro(foodID))
end

-- Feed Pet is an ordinary cast: while the pet eats it carries a buff, so the countdown is read
-- from that buff's duration. On WoW Forever it is "Feed Pet Effect", spell 1539, 20s (confirmed
-- in-game with /kibble buffs). We match that spell ID, or any pet buff whose name starts with
-- the Feed Pet spell name as a fallback.
local FEED_BUFF_ID = 1539

local function PetBuff(i)
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
	return C_UnitAuras.GetAuraDataByIndex("pet", i, "HELPFUL")
end

local function FindFeedBuff()
	local prefix = FeedPetName()
	for i = 1, 40 do
		local aura = PetBuff(i)
		if not aura then return nil end
		local name, id = aura.name, aura.spellId
		if not IsSecret(name) and not IsSecret(id) and not IsSecret(aura.duration)
			and not IsSecret(aura.expirationTime) then
			if id == FEED_BUFF_ID or (type(name) == "string" and name:find(prefix, 1, true) == 1) then
				return aura
			end
		end
	end
end

-- Shows the remaining feed time while the pet is eating; clears it otherwise.
local function UpdateFeeding()
	local aura = S.showFeeding and PetIsOut() and FindFeedBuff()
	if aura and aura.duration and aura.duration > 0 and aura.expirationTime then
		feedCooldown:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
	else
		feedCooldown:Clear()
	end
end

local lowWarned = false -- already warned about low food since it was last above the threshold
local lastPetState        -- "out" / "dead" / "none", to notice the pet dying or coming back

local function Refresh()
	local foodID, foodCount, total = FindBestFood()
	ApplySecure(foodID)

	local state = PetState()
	lastPetState = state
	-- the vendor restock button follows the pet's real state (Restock.lua); doing it here rides on
	-- the same debounced refresh as the main button instead of racing the pet frame on UNIT_PET
	if ns.UpdateRestock then ns.UpdateRestock() end
	if S.petCare and state ~= "out" then
		-- no living pet: the button offers to revive it (dead) or call it (missing)
		local spell = state == "dead" and REVIVE_PET_SPELL_ID or CALL_PET_SPELL_ID
		icon:SetTexture(SpellIcon(spell, FeedPetIcon()))
		icon:SetDesaturated(false)
		count:SetText("")
		noFood:Hide()
		shade:Hide()
		feedCooldown:Clear()
		pulse:Stop()
		border:SetAlpha(1)
		border:SetColorTexture(0.55, 0.55, 0.62, 1)
		UpdateAlpha(nil)
		return
	end

	-- visuals (safe in combat)
	local shownFood = currentFood or foodID
	if shownFood then
		icon:SetTexture(GetItemIcon(shownFood) or FeedPetIcon())
		icon:SetDesaturated(false)
		count:SetText(S.showCount and shownFood == foodID and foodCount or "")
		noFood:Hide()
		shade:Hide()
	else
		icon:SetTexture(FeedPetIcon())
		icon:SetDesaturated(true)
		count:SetText("")
		noFood:SetShown(S.showNoFood)
		shade:Show()
	end

	local happiness = GetHappiness()
	UpdateAlpha(happiness)
	local color = HAPPY_COLORS[happiness or 3]
	border:SetColorTexture(color[1], color[2], color[3], 1)
	if happiness and happiness < 3 then
		if not pulse:IsPlaying() then pulse:Play() end
	else
		pulse:Stop()
		border:SetAlpha(1)
	end

	-- alerts
	if PetIsOut() then
		local hasFood = total > 0
		if hadFood == true and not hasFood then
			Alert("Kibble: you are out of pet food!")
		elseif not hasFood and happiness and happiness < 3
			and (lastHappiness == nil or happiness < lastHappiness) then
			Alert("Kibble: your pet is hungry and you have no food it will eat!")
		end
		hadFood = hasFood
		-- low-food warning: once per dip below the threshold (the "out of food" alert covers zero)
		if S.lowFood > 0 and total > S.lowFood then
			lowWarned = false
		elseif S.lowFood > 0 and total > 0 and not lowWarned then
			if Alert(("Kibble: low on pet food (%d left)!"):format(total)) then
				lowWarned = true
			end
		end
		if S.hungryHint and happiness and lastHappiness and happiness < lastHappiness
			and happiness < 3 and hasFood then
			Print("your pet is getting hungry - click Kibble.")
		end
		lastHappiness = happiness
	end
end

---------------------------------------------------------------------------
-- Moving, tooltip, position
---------------------------------------------------------------------------

local function RestorePosition()
	button:ClearAllPoints()
	local p = KibbleDB.pos
	if p then
		button:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	else
		button:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
	end
end

button:SetScript("OnDragStart", function(self)
	if IsShiftKeyDown() and not S.locked and not InCombatLockdown() then
		self:StartMoving()
	end
end)

button:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local point, _, relPoint, x, y = self:GetPoint()
	KibbleDB.pos = { point, relPoint, x, y }
end)

local HAPPY_TEXT = { [1] = "|cffff2020Unhappy|r", [2] = "|cffffd800Content|r", [3] = "|cff20ff20Happy|r" }

button:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	local state = PetState()
	if S.petCare and state ~= "out" then
		GameTooltip:SetText("Kibble")
		GameTooltip:AddLine(state == "dead" and "Click to revive your pet." or "Click to call your pet.", 1, 1, 1)
		GameTooltip:AddLine("Right-click for settings." .. (S.locked and "" or " Shift-drag to move."), 0.7, 0.7, 0.7)
		GameTooltip:Show()
		button:SetAlpha(S.opacity)
		return
	end
	if currentFood then
		GameTooltip:SetItemByID(currentFood)
	else
		GameTooltip:SetText("Kibble")
		GameTooltip:AddLine("No food in your bags that this pet will eat.", 1, 0.2, 0.2)
	end
	local h = GetHappiness()
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Pet: " .. (HAPPY_TEXT[h] or "unknown"))
	GameTooltip:AddLine("Click to feed." .. (S.petCare and " Ctrl-click to mend." or "") ..
		" Right-click for settings." .. (S.locked and "" or " Shift-drag to move."), 0.7, 0.7, 0.7)
	GameTooltip:Show()
	button:SetAlpha(S.opacity) -- un-fade while hovered so the faded button is easy to find
end)
button:SetScript("OnLeave", function()
	GameTooltip_Hide()
	UpdateAlpha(GetHappiness())
end)

---------------------------------------------------------------------------
-- Right-click settings menu
---------------------------------------------------------------------------

local SIZE_PRESETS = { { "Small", 32 }, { "Medium", 40 }, { "Large", 52 }, { "Extra large", 64 } }
local OPACITY_PRESETS = { { "100%", 1 }, { "75%", 0.75 }, { "50%", 0.5 } }
local THROTTLE_PRESETS = { { "15 seconds", 15 }, { "30 seconds", 30 }, { "60 seconds", 60 } }
local LOW_FOOD_PRESETS = { { "Off", 0 }, { "5 or fewer", 5 }, { "10 or fewer", 10 }, { "20 or fewer", 20 } }
local RESTOCK_TARGETS = { 20, 40, 80, 120 }
local FOOD_MODES = {
	{ "Save best food (cheapest that still fully feeds)", "save" },
	{ "Smallest stack first (frees bag space)", "stack" },
	{ "Always use the best food", "best" },
}
local VISIBILITY_MODES = {
	{ "Always show", "always" },
	{ "Fade while pet is happy", "unhappy" },
	{ "Hidden (use /kibble config to open this menu)", "hidden" },
}

local function ItemName(itemID)
	local name = (C_Item and C_Item.GetItemInfo or GetItemInfo)(itemID)
	return name or ("item:" .. itemID)
end

local function Apply()
	ApplyLayout()
	Refresh()
end

local function AddChecks(parent, entries)
	for _, e in ipairs(entries) do
		local label, key, after = e[1], e[2], e[3]
		parent:CreateCheckbox(label, function() return S[key] end, function()
			S[key] = not S[key]
			if after then after() else Refresh() end
		end)
	end
end

local function AddRadios(parent, presets, key)
	for _, p in ipairs(presets) do
		local label, value = p[1], p[2]
		parent:CreateRadio(label, function() return S[key] == value end, function()
			S[key] = value
			Apply()
		end)
	end
end

local function BuildMenu(_, root)
	root:CreateTitle("Kibble")

	local alerts = root:CreateButton("Alerts")
	AddChecks(alerts, {
		{ "On-screen warning", "alertScreen" },
		{ "Chat message", "alertChat" },
		{ "Sound", "alertSound" },
		{ "\"Pet is getting hungry\" hint", "hungryHint" },
	})
	alerts:CreateDivider()
	alerts:CreateTitle("Warn when food is low")
	AddRadios(alerts, LOW_FOOD_PRESETS, "lowFood")
	alerts:CreateDivider()
	alerts:CreateTitle("Alert sound (turn on with \"Sound\" above)")
	for _, c in ipairs(SOUND_CHOICES) do
		local label, key = c[1], c[2]
		if SOUNDKIT and SOUNDKIT[key] then
			alerts:CreateRadio(label, function() return S.soundChoice == key end, function()
				S.soundChoice = key
				PlayAlertSound() -- preview
			end)
		end
	end
	alerts:CreateDivider()
	alerts:CreateTitle("Repeat alerts no more often than")
	AddRadios(alerts, THROTTLE_PRESETS, "throttle")

	local look = root:CreateButton("Appearance")
	look:CreateTitle("Size")
	AddRadios(look, SIZE_PRESETS, "size")
	look:CreateDivider()
	look:CreateTitle("Opacity")
	AddRadios(look, OPACITY_PRESETS, "opacity")
	look:CreateDivider()
	AddChecks(look, {
		{ "Show food count", "showCount" },
		{ "Show \"NO FOOD\" text", "showNoFood" },
		{ "Show feeding countdown", "showFeeding", function() UpdateFeeding() end },
		{ "Lock position", "locked", function() end },
		{ "Show minimap button", "showMinimap", function() if ns.UpdateMinimap then ns.UpdateMinimap() end end },
	})
	look:CreateButton("Reset position", function()
		if InCombatLockdown() then
			Print("can't move the button in combat.")
			return
		end
		KibbleDB.pos = nil
		RestorePosition()
	end)

	local food = root:CreateButton("Food")
	food:CreateTitle("Which food to use")
	AddRadios(food, FOOD_MODES, "foodMode")
	food:CreateDivider()
	food:CreateTitle("Vendor restock: buy up to")
	for _, n in ipairs(RESTOCK_TARGETS) do
		food:CreateRadio(tostring(n), function() return S.restockTarget == n end, function()
			S.restockTarget = n
			if ns.UpdateRestock then ns.UpdateRestock() end
		end)
	end
	food:CreateDivider()
	local ignore = food:CreateButton("Ignored foods")
	if not PetIsOut() then
		ignore:CreateTitle("Summon your pet to list its foods")
	else
		local ids = {}
		for id in pairs(ScanFood(true)) do ids[#ids + 1] = id end
		table.sort(ids, function(a, b) return ItemName(a) < ItemName(b) end)
		if #ids == 0 then
			ignore:CreateTitle("No food in your bags")
		else
			ignore:CreateTitle("Checked foods are never used")
			for _, id in ipairs(ids) do
				ignore:CreateCheckbox(ItemName(id), function() return S.ignored[id] == true end, function()
					S.ignored[id] = (not S.ignored[id]) or nil
					Refresh()
				end)
			end
		end
	end

	local vis = root:CreateButton("Visibility")
	AddRadios(vis, VISIBILITY_MODES, "visibility")
	vis:CreateDivider()
	AddChecks(vis, {
		{ "Revive / call a missing pet (Ctrl-click mends)", "petCare", Apply },
	})
end

local function OpenMenu()
	MenuUtil.CreateContextMenu(button:IsShown() and button or UIParent, BuildMenu)
end

local lastNoFoodMsg = 0
button:HookScript("OnClick", function(_, mouseButton, down)
	if mouseButton == "RightButton" then
		if not down then OpenMenu() end
	elseif PetIsOut() and not currentFood and not IsControlKeyDown() and GetTime() - lastNoFoodMsg > 1 then
		lastNoFoodMsg = GetTime()
		Print("no food your pet will eat in your bags.")
	end
end)

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local events = CreateFrame("Frame")

local function SafeRegister(event, ...)
	if select("#", ...) > 0 then
		pcall(events.RegisterUnitEvent, events, event, ...)
	else
		pcall(events.RegisterEvent, events, event)
	end
end

local refreshQueued = false
local function QueueRefresh()
	if refreshQueued then return end
	refreshQueued = true
	C_Timer.After(0.2, function()
		refreshQueued = false
		Refresh()
	end)
end

events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON then return end
		-- One-time migration from this addon's old name (FeedMe): keep the button position.
		if KibbleDB == nil and type(FeedMeDB) == "table" then
			KibbleDB = {}
			KibbleDB.pos = FeedMeDB.pos
		end
		FeedMeDB = nil
		KibbleDB = KibbleDB or {}
		LoadSettings()
		-- still inside the loading screen, so moving/sizing the secure button is allowed
		RestorePosition()
		ApplyLayout()
		UpdateAlpha(nil)
	elseif event == "PLAYER_LOGIN" then
		QueueRefresh()
	elseif event == "UNIT_PET" or event == "UNIT_LEVEL" then
		wipe(canEatCache)
		hadFood, lastHappiness, lowWarned = nil, nil, false
		QueueRefresh()
	elseif event == "UNIT_AURA" then
		UpdateFeeding()
	elseif event == "UNIT_HEALTH" then
		-- only the pet dying / coming back matters, so don't rescan the bags on every health tick
		if PetState() ~= lastPetState then QueueRefresh() end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pendingLayout then ApplyLayout() end
		if pendingSecure or pendingLayout then Refresh() end
	else
		QueueRefresh()
	end
end)

SafeRegister("ADDON_LOADED")
SafeRegister("PLAYER_LOGIN")
SafeRegister("PLAYER_REGEN_ENABLED")
SafeRegister("BAG_UPDATE_DELAYED")
SafeRegister("GET_ITEM_INFO_RECEIVED")
SafeRegister("UNIT_PET", "player")
SafeRegister("UNIT_LEVEL", "pet")
SafeRegister("UNIT_HAPPINESS", "pet")
SafeRegister("UNIT_AURA", "pet") -- the feeding buff drives the countdown
SafeRegister("UNIT_HEALTH", "pet") -- notice the pet dying / being revived (pet care)
SafeRegister("UNIT_POWER_UPDATE", "pet") -- Forever exposes happiness as a pet power, too

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------

SLASH_KIBBLE1 = "/kibble"
SlashCmdList.KIBBLE = function(msg)
	msg = (msg or ""):lower()
	if msg == "config" or msg == "options" or msg == "settings" then
		OpenMenu()
	elseif msg == "buffs" then
		-- diagnostic: feed your pet, then run this to see what the feeding buff is called
		local any = false
		for i = 1, 40 do
			local a = PetBuff(i)
			if not a then break end
			any = true
			if IsSecret(a.name) then
				Print(i .. ": (restricted in combat)")
			else
				Print(("%d: %s (spell %s, %ss)"):format(i, tostring(a.name), tostring(a.spellId), tostring(a.duration)))
			end
		end
		if not any then Print("your pet has no buffs (or no pet is out).") end
	elseif msg == "vendor" then
		-- diagnostic: with a vendor open, explains why the restock button is (not) showing
		if ns.VendorDiag then ns.VendorDiag() else Print("vendor diagnostics unavailable.") end
	elseif msg == "reset" then
		if InCombatLockdown() then Print("can't move the button in combat.") return end
		KibbleDB.pos = nil
		RestorePosition()
		Print("button position reset.")
	else
		local foodID, foodCount, total = FindBestFood()
		local h = GetHappiness()
		Print(("pet: %s | best food: %s (%d) | all edible food: %d"):format(
			HAPPY_TEXT[h] or "none/unknown",
			foodID and (select(2, (C_Item and C_Item.GetItemInfo or GetItemInfo)(foodID)) or ("item:" .. foodID)) or "none",
			foodCount, total))
		Print("Right-click the button (or /kibble config) for settings. Shift-drag moves it, /kibble reset puts it back. Key binding: Options > Key Bindings > AddOns.")
	end
end

---------------------------------------------------------------------------
-- Exports for Restock.lua and Panel.lua (only hunters get this far)
---------------------------------------------------------------------------

ns.core = {
	Settings    = function() return S end,   -- S is replaced when the saved settings load
	Print       = Print,
	IsSecret    = IsSecret,
	PetIsOut    = PetIsOut,
	PetCanEat   = PetCanEat,
	ChooseFood  = ChooseFood,
	ItemName    = ItemName,
	Refresh     = Refresh,
	Apply       = Apply,
	OpenMenu    = OpenMenu,
	PlayAlertSound = PlayAlertSound,
	UpdateFeeding  = UpdateFeeding,
	PeekCanEat     = function(itemID) return canEatCache[itemID] end, -- cached answer, for diagnostics
}
