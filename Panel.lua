-- Kibble: the Options > AddOns > Kibble panel, the minimap button and the addon-compartment entry.
-- The right-click menu on the button stays the full settings UI; the panel covers the on/off
-- options and has a button that opens that menu.

local ADDON, ns = ...
local K = ns.core

-- Addon compartment (the minimap "addons" list). The TOC names these globals, so they exist for
-- every class; only hunters have anything to open.
function Kibble_OnCompartmentClick(_, mouseButton)
	if not K then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Kibble:|r this addon is for hunters.")
	elseif mouseButton == "RightButton" and ns.OpenPanel then
		ns.OpenPanel()
	else
		K.OpenMenu()
	end
end

function Kibble_OnCompartmentEnter(_, owner)
	GameTooltip:SetOwner(owner or UIParent, "ANCHOR_LEFT")
	GameTooltip:AddLine("Kibble", 1, 0.82, 0.25)
	if K then
		GameTooltip:AddLine("Click: open the settings menu", 1, 1, 1)
		GameTooltip:AddLine("Right-click: open the options panel", 0.8, 0.8, 0.8)
	else
		GameTooltip:AddLine("Only active for hunters.", 0.8, 0.8, 0.8)
	end
	GameTooltip:Show()
end

function Kibble_OnCompartmentLeave()
	GameTooltip:Hide()
end

if not K then return end -- not a hunter

local atan2 = math.atan2 or math.atan

---------------------------------------------------------------------------
-- EllesmereUI skinning (optional; see EllesmereUI/SKINNING_API.md)
-- ns.Skin("Button", frame) restyles one of our widgets to match EllesmereUI. Widgets made
-- before EllesmereUI hands us its skin facade wait in a queue. Without EllesmereUI (or with
-- skinning switched off) nothing ever runs.
---------------------------------------------------------------------------

local skinQueue = {}

-- Higher-level skins built from the facade's primitives, with fallbacks for older EllesmereUI:
--   TabButton  a button styled as one of the window's own tabs (S.Tab); re-call after SetText to
--              re-mirror its label. Falls back to S.Button + S.StateButtonLabel.
--   TabState   shows it as the active tab (bright label + accent underline) or not; arg = boolean.
local COMPOSITE = {
	TabButton = function(S, w)
		if S.Tab then
			S.Tab(w)
		elseif S.Button then
			S.Button(w)
			if S.StateButtonLabel then S.StateButtonLabel(w) end
		end
	end,
	TabState = function(S, w, active)
		if S.SetTabSelection then S.SetTabSelection(w, active and true or false) end
	end,
}

local function RunSkin(S, kind, widget, arg)
	local composite = COMPOSITE[kind]
	if composite then
		pcall(composite, S, widget, arg)
	elseif S[kind] then
		pcall(S[kind], widget, arg)
	end
end

function ns.Skin(kind, widget, arg)
	if not (EllesmereUI and EllesmereUI.RegisterSkin) then return end
	local S = ns.skin
	if S then
		RunSkin(S, kind, widget, arg)
		return
	end
	for _, q in ipairs(skinQueue) do -- not yet handed the facade: keep one entry per widget+kind
		if q[1] == kind and q[2] == widget then q[3] = arg; return end
	end
	skinQueue[#skinQueue + 1] = { kind, widget, arg }
end

-- true when EllesmereUI is styling our widgets with its tab look (the restock button then matches
-- the tab row's height instead of using the stock button size)
function ns.SkinActive()
	return ns.skin ~= nil and ns.skin.Tab ~= nil
end

if EllesmereUI and EllesmereUI.RegisterSkin then
	EllesmereUI.RegisterSkin("Kibble", function(S)
		ns.skin = S
		local queued = skinQueue
		skinQueue = {}
		for _, q in ipairs(queued) do RunSkin(S, q[1], q[2], q[3]) end
	end)
end

---------------------------------------------------------------------------
-- Options panel (canvas layout)
---------------------------------------------------------------------------

local panelCategory
local panelChecks = {}

local PANEL_OPTIONS = {
	{ "On-screen warning", "alertScreen" },
	{ "Chat message", "alertChat" },
	{ "Sound alerts (off by default)", "alertSound" },
	{ "\"Pet is getting hungry\" hint", "hungryHint" },
	{ "Show food count", "showCount" },
	{ "Show \"NO FOOD\" text", "showNoFood" },
	{ "Show feeding countdown", "showFeeding" },
	{ "Lock position", "locked" },
	{ "Don't feed a happy pet", "skipHappy" },
	{ "Revive / call a missing pet (Ctrl-click mends)", "petCare" },
	{ "Show minimap button", "showMinimap" },
}

local function RefreshPanel()
	local S = K.Settings()
	for _, row in ipairs(panelChecks) do
		row.box:SetChecked(S[row.key] and true or false)
	end
end

ns.RefreshPanel = RefreshPanel

local function BuildPanel()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
	local f = CreateFrame("Frame")
	f.name = "Kibble"

	local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Kibble")

	local sub = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	sub:SetText("One button to feed your hunter pet. Right-click the button for every setting.")

	local open = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	open:SetSize(190, 24)
	open:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -14)
	open:SetText("Open the Kibble menu")
	open:SetScript("OnClick", function() K.OpenMenu() end)
	ns.Skin("Button", open)

	local previous = open
	for _, opt in ipairs(PANEL_OPTIONS) do
		local label, key = opt[1], opt[2]
		local box = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
		box:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", previous == open and -2 or 0, previous == open and -14 or -2)
		local text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		text:SetPoint("LEFT", box, "RIGHT", 4, 1)
		text:SetText(label)
		box:SetScript("OnClick", function(self)
			K.Settings()[key] = self:GetChecked() and true or false
			K.Apply()
			if key == "showMinimap" then ns.UpdateMinimap() end
			if key == "showFeeding" then K.UpdateFeeding() end
		end)
		ns.Skin("Checkbox", box)
		panelChecks[#panelChecks + 1] = { box = box, key = key }
		previous = box
	end

	f:SetScript("OnShow", RefreshPanel)
	panelCategory = Settings.RegisterCanvasLayoutCategory(f, "Kibble")
	Settings.RegisterAddOnCategory(panelCategory)
end

function ns.OpenPanel()
	if panelCategory and Settings.OpenToCategory then
		Settings.OpenToCategory(panelCategory:GetID())
	else
		K.OpenMenu()
	end
end

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------

local mini

local function PlaceMinimapButton()
	local angle = K.Account().minimapAngle or 3.93
	local radius = Minimap:GetWidth() / 2 + 5
	mini:ClearAllPoints()
	mini:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function DragMinimapButton()
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	K.Account().minimapAngle = atan2(cy / scale - my, cx / scale - mx)
	PlaceMinimapButton()
end

local function BuildMinimapButton()
	mini = CreateFrame("Button", "KibbleMinimapButton", Minimap)
	mini:SetSize(31, 31)
	mini:SetFrameStrata("MEDIUM")
	mini:SetFrameLevel(8)
	mini:RegisterForClicks("AnyUp")
	mini:RegisterForDrag("LeftButton")

	local bg = mini:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(20, 20)
	bg:SetPoint("TOPLEFT", 7, -5)
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

	local icon = mini:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetPoint("TOPLEFT", 7, -6)
	icon:SetTexture("Interface\\AddOns\\Kibble\\icon.png")

	local ring = mini:CreateTexture(nil, "OVERLAY")
	ring:SetSize(53, 53)
	ring:SetPoint("TOPLEFT")
	ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

	mini:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	mini:SetScript("OnClick", function(_, mouseButton)
		if mouseButton == "RightButton" then ns.OpenPanel() else K.OpenMenu() end
	end)
	mini:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", DragMinimapButton) end)
	mini:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	mini:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Kibble", 1, 0.82, 0.25)
		GameTooltip:AddLine("Click: settings menu", 1, 1, 1)
		GameTooltip:AddLine("Right-click: options panel", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("Drag: move around the minimap", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	mini:SetScript("OnLeave", GameTooltip_Hide)
end

function ns.UpdateMinimap()
	if not mini then return end
	PlaceMinimapButton()
	mini:SetShown(K.Settings().showMinimap and true or false)
end

---------------------------------------------------------------------------

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN") -- Kibble's saved settings are loaded by now (ADDON_LOADED)
init:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	BuildPanel()
	BuildMinimapButton()
	ns.UpdateMinimap()
end)
