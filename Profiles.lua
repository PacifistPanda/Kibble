-- Kibble: profiles, with import / export.
--
-- A profile is a complete settings table (including the ignore list); each character uses one
-- (KibbleDB.profileKeys), new characters start on "Default". The button position and the minimap
-- angle are not part of a profile. An exported profile is a text string:
--
--   KIBBLE1:<base64 of "key=value" lines>:<checksum>
--
-- Importing never executes anything: the text is parsed line by line and every value must pass a
-- whitelist for its setting (unknown keys and invalid values are skipped and counted).

local ADDON, ns = ...
local K = ns.core
if not K then return end -- not a hunter

local floor = math.floor

local MAX_NAME = 32
local MAX_IGNORED = 60   -- ignored foods carried in an export (the dialog has room for this)
local PREFIX = "KIBBLE1"

local P = {}             -- the testable surface, exposed as ns.Profiles
ns.Profiles = P

---------------------------------------------------------------------------
-- What an import may contain
---------------------------------------------------------------------------

local BOOLEANS = {
	alertScreen = true, alertChat = true, alertSound = true, hungryHint = true, showFeeding = true,
	locked = true, showCount = true, showNoFood = true, petCare = true, showMinimap = true,
}
local NUMBERS = {
	throttle = { 15, 30, 60 }, lowFood = { 0, 5, 10, 20 }, size = { 32, 40, 52, 64 },
	opacity = { 1, 0.75, 0.5 }, restockTarget = { 20, 40, 80, 120 },
}
local STRINGS = {
	foodMode = { save = true, stack = true, best = true },
	visibility = { always = true, unhappy = true, hidden = true },
}

local function ValidValue(key, text)
	if BOOLEANS[key] then
		if text == "1" then return true end
		if text == "0" then return false end
		return nil
	elseif NUMBERS[key] then
		local n = tonumber(text)
		for _, allowed in ipairs(NUMBERS[key]) do
			if n == allowed then return n end
		end
		return nil
	elseif STRINGS[key] then
		return STRINGS[key][text] and text or nil
	elseif key == "soundChoice" then
		return (#text <= 40 and text:match("^[A-Z][A-Z0-9_]*$")) and text or nil
	end
	return nil
end

-- every setting except the ignore list has to be covered above (a test checks this)
function P.Covers(key)
	return BOOLEANS[key] ~= nil or NUMBERS[key] ~= nil or STRINGS[key] ~= nil or key == "soundChoice"
		or key == "ignored" or key == "settingsVersion"
end

---------------------------------------------------------------------------
-- Base64 and checksum (no libraries, no bit operations needed)
---------------------------------------------------------------------------

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_INDEX = {}
for i = 1, #B64 do B64_INDEX[B64:sub(i, i)] = i - 1 end

local function Base64Encode(data)
	local out = {}
	for i = 1, #data, 3 do
		local a, b, c = data:byte(i, i + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local c1, c2, c3, c4 = floor(n / 262144) % 64, floor(n / 4096) % 64, floor(n / 64) % 64, n % 64
		out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
			.. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
	end
	return table.concat(out)
end

local function Base64Decode(text)
	if #text % 4 ~= 0 or text:find("[^A-Za-z0-9+/=]") or text:find("=[^=]") then return nil end
	local out = {}
	for i = 1, #text, 4 do
		local s1, s2, s3, s4 = text:sub(i, i), text:sub(i + 1, i + 1), text:sub(i + 2, i + 2), text:sub(i + 3, i + 3)
		local v1, v2 = B64_INDEX[s1], B64_INDEX[s2]
		local v3, v4 = B64_INDEX[s3], B64_INDEX[s4]
		if not (v1 and v2) or (s3 == "=" and s4 ~= "=") then return nil end
		local n = v1 * 262144 + v2 * 4096 + (v3 or 0) * 64 + (v4 or 0)
		out[#out + 1] = string.char(floor(n / 65536) % 256)
		if s3 ~= "=" then out[#out + 1] = string.char(floor(n / 256) % 256) end
		if s4 ~= "=" then out[#out + 1] = string.char(n % 256) end
	end
	return table.concat(out)
end

-- Adler-32, to catch a string that was mangled or cut short on its way through chat or a forum.
local function Checksum(text)
	local a, b = 1, 0
	for i = 1, #text do
		a = (a + text:byte(i)) % 65521
		b = (b + a) % 65521
	end
	return string.format("%.0f", b * 65536 + a)
end

-- builds a well-formed string around arbitrary text (used by Export and by the tests)
function P.Encode(text)
	local body = Base64Encode(text)
	return PREFIX .. ":" .. body .. ":" .. Checksum(body)
end

---------------------------------------------------------------------------
-- Export / import
---------------------------------------------------------------------------

local function SortedKeys(t)
	local keys = {}
	for k in pairs(t) do keys[#keys + 1] = k end
	table.sort(keys)
	return keys
end

-- Returns the export string for a profile table, and whether the ignore list had to be cut.
function P.Export(profile)
	local lines = {}
	for _, key in ipairs(SortedKeys(K.Defaults)) do
		local v = profile[key]
		if BOOLEANS[key] then
			lines[#lines + 1] = key .. "=" .. (v and "1" or "0")
		elseif NUMBERS[key] or STRINGS[key] or key == "soundChoice" then
			lines[#lines + 1] = key .. "=" .. tostring(v)
		end
	end
	local ids = {}
	for id in pairs(profile.ignored or {}) do
		if type(id) == "number" then ids[#ids + 1] = id end
	end
	table.sort(ids)
	local truncated = #ids > MAX_IGNORED
	while #ids > MAX_IGNORED do ids[#ids] = nil end
	if #ids > 0 then lines[#lines + 1] = "ignored=" .. table.concat(ids, ",") end
	return P.Encode(table.concat(lines, "\n")), truncated
end

function P.NewProfile()
	local t = { ignored = {}, settingsVersion = 2 }
	for k, v in pairs(K.Defaults) do t[k] = v end
	return t
end

-- Returns profile, skippedCount   or   nil, errorMessage
function P.Import(str)
	str = (str or ""):gsub("%s+", "")
	if str == "" then return nil, "nothing to import" end
	local version, body, sum = str:match("^(KIBBLE%d+):([A-Za-z0-9+/=]+):(%d+)$")
	if not version then return nil, "that is not a Kibble export string" end
	if version ~= PREFIX then return nil, "this string was made by a newer Kibble; update the addon" end
	if Checksum(body) ~= sum then return nil, "the string is damaged (checksum mismatch); copy it again" end
	local text = Base64Decode(body)
	if not text then return nil, "the string is damaged (not valid base64)" end

	local profile, skipped, found = P.NewProfile(), 0, 0
	for line in text:gmatch("[^\n]+") do
		local key, value = line:match("^([%w_]+)=(.*)$")
		if not key then
			skipped = skipped + 1
		elseif key == "ignored" then
			local count = 0
			for id in value:gmatch("[^,]+") do
				local n = tonumber(id)
				if n and n >= 1 and n <= 9999999 and n == floor(n) and count < MAX_IGNORED then
					profile.ignored[n] = true
					count = count + 1
				else
					skipped = skipped + 1
				end
			end
			found = found + 1
		else
			local v = ValidValue(key, value)
			if v == nil or K.Defaults[key] == nil then
				skipped = skipped + 1
			else
				profile[key] = v
				found = found + 1
			end
		end
	end
	if found == 0 then return nil, "the string contains no settings" end
	return profile, skipped
end

---------------------------------------------------------------------------
-- Profile operations
---------------------------------------------------------------------------

local function Profiles() return K.Account().profiles end

function P.Names()
	local names = {}
	for name in pairs(Profiles()) do names[#names + 1] = name end
	table.sort(names, function(a, b) return a:lower() < b:lower() end)
	return names
end

-- the existing profile whose name matches (ignoring case), or nil
function P.Find(name)
	name = (name or ""):lower()
	for existing in pairs(Profiles()) do
		if existing:lower() == name then return existing end
	end
end

local function CleanName(name)
	name = (name or ""):match("^%s*(.-)%s*$")
	if name == "" then return nil, "give the profile a name" end
	if #name > MAX_NAME then return nil, "that name is too long (" .. MAX_NAME .. " characters at most)" end
	if name:find("[|%c]") then return nil, "that name contains a character that can't be used" end
	if P.Find(name) then return nil, "a profile with that name already exists" end
	return name
end

local function CopyProfile(src)
	local t = {}
	for k, v in pairs(src) do t[k] = v end
	t.ignored = {}
	for id in pairs(src.ignored or {}) do t.ignored[id] = true end
	return t
end

-- Creates a profile (a copy of `source`, or the defaults); returns its name or nil, error.
function P.Create(name, source)
	local clean, err = CleanName(name)
	if not clean then return nil, err end
	local from = source and Profiles()[source]
	Profiles()[clean] = from and CopyProfile(from) or P.NewProfile()
	return clean
end

function P.Rename(old, new)
	if old == "Default" then return nil, "the Default profile can't be renamed" end
	local clean, err = CleanName(new)
	if not clean then return nil, err end
	local db = K.Account()
	db.profiles[clean], db.profiles[old] = db.profiles[old], nil
	for key, name in pairs(db.profileKeys) do
		if name == old then db.profileKeys[key] = clean end
	end
	if K.ActiveProfile() == old then K.UseProfile(clean) end
	return clean
end

function P.Delete(name)
	if name == "Default" then return nil, "the Default profile can't be deleted" end
	if name == K.ActiveProfile() then return nil, "switch to another profile first" end
	local db = K.Account()
	if not db.profiles[name] then return nil, "no such profile" end
	db.profiles[name] = nil
	for key, used in pairs(db.profileKeys) do
		if used == name then db.profileKeys[key] = "Default" end
	end
	return true
end

-- Back to the defaults, in place (the active table stays the same table).
function P.Reset(name)
	local t = Profiles()[name]
	if not t then return nil, "no such profile" end
	for k in pairs(t) do t[k] = nil end
	for k, v in pairs(P.NewProfile()) do t[k] = v end
	if K.ActiveProfile() == name then K.UseProfile(name) end
	return true
end

-- Import a string as a new profile (named after `wanted` or "Imported") and switch to it.
function P.ImportAndUse(str, wanted)
	local profile, info = P.Import(str)
	if not profile then return nil, info end
	local base = (wanted and wanted ~= "") and wanted or "Imported"
	local name, n = base, 1
	while P.Find(name) do
		n = n + 1
		name = base .. " " .. n
	end
	local clean, err = CleanName(name)
	if not clean then return nil, err end
	Profiles()[clean] = profile
	local previous = K.ActiveProfile()
	K.UseProfile(clean)
	return clean, info, previous
end

---------------------------------------------------------------------------
-- The dialog (our own: one small reusable window)
---------------------------------------------------------------------------

local dialog

local function BuildDialog()
	local f = CreateFrame("Frame", "KibbleDialog", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(440, 200)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	if f.SetBackdrop then
		f:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
	end
	f:Hide()
	if UISpecialFrames then table.insert(UISpecialFrames, "KibbleDialog") end -- Esc closes it

	f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	f.title:SetPoint("TOP", 0, -18)

	f.text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	f.text:SetPoint("TOPLEFT", 24, -46)
	f.text:SetWidth(392)
	f.text:SetJustifyH("LEFT")

	-- single-line input (names)
	f.line = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	f.line:SetAutoFocus(false)
	f.line:SetHeight(24)
	f.line:SetMaxLetters(MAX_NAME)

	-- multi-line input (export / import strings)
	f.box = CreateFrame("EditBox", nil, f)
	f.box:SetMultiLine(true)
	f.box:SetAutoFocus(false)
	f.box:SetFontObject("GameFontHighlightSmall")
	f.box:SetMaxLetters(4000)
	f.box:SetTextInsets(6, 6, 6, 6)
	f.box.bg = f.box:CreateTexture(nil, "BACKGROUND")
	f.box.bg:SetAllPoints()
	f.box.bg:SetColorTexture(0, 0, 0, 0.6)

	f.ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.ok:SetSize(110, 24)
	f.ok:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 18)
	f.cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	f.cancel:SetSize(110, 24)
	f.cancel:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 18)

	local function Done(accept)
		local spec = f.spec
		f:Hide()
		if accept and spec and spec.onOK then
			spec.onOK(spec.input == "line" and f.line:GetText() or f.box:GetText())
		end
	end
	f.ok:SetScript("OnClick", function() Done(true) end)
	f.cancel:SetScript("OnClick", function() Done(false) end)
	f.line:SetScript("OnEnterPressed", function() Done(true) end)
	f.line:SetScript("OnEscapePressed", function() f:Hide() end)
	f.box:SetScript("OnEscapePressed", function() f:Hide() end)
	-- an export is for copying: put the text back if it gets edited
	f.box:SetScript("OnTextChanged", function(self, userInput)
		if userInput and f.spec and f.spec.readOnly then
			self:SetText(f.spec.value or "")
			self:HighlightText()
		end
	end)

	ns.Skin("Panel", f)
	ns.Skin("Button", f.ok)
	ns.Skin("Button", f.cancel)
	ns.Skin("EditBox", f.line)
	return f
end

-- spec: title, text, input = "line" | "multi" | nil, value, okText, cancelText (nil = no cancel),
--       readOnly, onOK(value)
local function ShowDialog(spec)
	dialog = dialog or BuildDialog()
	local f = dialog
	f.spec = spec
	f.title:SetText(spec.title or "Kibble")
	f.text:SetText(spec.text or "")
	f.ok:SetText(spec.okText or OKAY or "OK")
	f.cancel:SetText(spec.cancelText or CANCEL or "Cancel")
	f.cancel:SetShown(spec.cancelText ~= false)
	f.ok:ClearAllPoints()
	if spec.cancelText == false then
		f.ok:SetPoint("BOTTOM", f, "BOTTOM", 0, 18)
	else
		f.ok:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 18)
	end

	local textHeight = f.text:GetStringHeight()
	if not textHeight or textHeight < 14 then textHeight = 14 end
	local inputHeight = 0
	f.line:Hide()
	f.box:Hide()
	if spec.input == "line" then
		inputHeight = 24
		f.line:ClearAllPoints()
		f.line:SetPoint("TOPLEFT", f.text, "BOTTOMLEFT", 6, -12)
		f.line:SetWidth(380)
		f.line:SetText(spec.value or "")
		f.line:Show()
	elseif spec.input == "multi" then
		inputHeight = 150
		f.box:ClearAllPoints()
		f.box:SetPoint("TOPLEFT", f.text, "BOTTOMLEFT", 0, -12)
		f.box:SetSize(392, inputHeight)
		f.box:SetText(spec.value or "")
		f.box:Show()
	end
	f:SetHeight(46 + textHeight + (inputHeight > 0 and inputHeight + 12 or 0) + 66)
	f:Show()
	if spec.input == "line" then
		f.line:SetFocus()
		f.line:HighlightText()
	elseif spec.input == "multi" then
		f.box:SetFocus()
		if spec.readOnly then f.box:HighlightText() end
	end
end
P.ShowDialog = ShowDialog

local function Ask(title, text, value, onOK)
	ShowDialog({ title = title, text = text, input = "line", value = value, okText = OKAY or "OK", onOK = onOK })
end

local function Confirm(title, text, onOK)
	ShowDialog({ title = title, text = text, okText = YES or "Yes", cancelText = NO or "No", onOK = onOK })
end

---------------------------------------------------------------------------
-- Actions behind the menu and the slash commands
---------------------------------------------------------------------------

function ns.ShowExport()
	local active = K.ActiveProfile()
	local str, truncated = P.Export(K.Settings())
	local note = truncated and ("\nOnly the first " .. MAX_IGNORED .. " ignored foods are included.") or ""
	ShowDialog({
		title = "Export profile",
		text = "Profile \"" .. active .. "\". Press Ctrl-C to copy this text, then paste it where you want to share it." .. note,
		input = "multi", value = str, readOnly = true, okText = CLOSE or "Close", cancelText = false,
	})
end

function ns.ShowImport()
	ShowDialog({
		title = "Import profile",
		text = "Paste a Kibble export string. It becomes a new profile that you switch to.",
		input = "multi", value = "", okText = "Import",
		onOK = function(text)
			local name, info, previous = P.ImportAndUse(text)
			if not name then
				K.Print("import failed: " .. tostring(info))
			else
				K.Print(("imported as profile \"%s\" (you were on \"%s\")%s."):format(name, previous,
					info > 0 and (", " .. info .. " unrecognised or invalid value(s) skipped") or ""))
			end
		end,
	})
end

local function Report(ok, err, success)
	if ok then K.Print(success) else K.Print(err or "that didn't work.") end
end

local function AskNewProfile()
	Ask("New profile", "Name for the new profile (it starts with the default settings):", "", function(name)
		local created, err = P.Create(name)
		if created then K.UseProfile(created) end
		Report(created, err, ("created profile \"%s\"."):format(tostring(created)))
	end)
end

local function AskCopyProfile()
	local from = K.ActiveProfile()
	Ask("Copy profile", "Name for the copy of \"" .. from .. "\":", from .. " copy", function(name)
		local created, err = P.Create(name, from)
		if created then K.UseProfile(created) end
		Report(created, err, ("copied \"%s\" to \"%s\"."):format(from, tostring(created)))
	end)
end

local function AskRenameProfile()
	local old = K.ActiveProfile()
	Ask("Rename profile", "New name for \"" .. old .. "\":", old, function(name)
		local renamed, err = P.Rename(old, name)
		Report(renamed, err, ("renamed to \"%s\"."):format(tostring(renamed)))
	end)
end

function ns.BuildProfileMenu(root)
	local menu = root:CreateButton("Profiles")
	local active = K.ActiveProfile()
	menu:CreateTitle("This character uses: " .. active)
	for _, name in ipairs(P.Names()) do
		menu:CreateRadio(name, function() return K.ActiveProfile() == name end, function() K.UseProfile(name) end)
	end
	menu:CreateDivider()
	menu:CreateButton("New profile...", AskNewProfile)
	menu:CreateButton("Copy this profile...", AskCopyProfile)
	if active ~= "Default" then
		menu:CreateButton("Rename this profile...", AskRenameProfile)
	end
	menu:CreateButton("Reset this profile", function()
		local current = K.ActiveProfile()
		Confirm("Reset profile", "Reset \"" .. current .. "\" to the default settings? Its ignore list is cleared too.", function()
			Report(P.Reset(current), nil, ("profile \"%s\" reset."):format(current))
		end)
	end)
	local delete = menu:CreateButton("Delete a profile")
	local any = false
	for _, name in ipairs(P.Names()) do
		if name ~= "Default" and name ~= active then
			any = true
			delete:CreateButton(name, function()
				Confirm("Delete profile", "Delete the profile \"" .. name .. "\"? Characters using it go back to Default.", function()
					local ok, err = P.Delete(name)
					Report(ok, err, ("deleted profile \"%s\"."):format(name))
				end)
			end)
		end
	end
	if not any then delete:CreateTitle("No other profile to delete") end
	menu:CreateDivider()
	menu:CreateButton("Export this profile...", ns.ShowExport)
	menu:CreateButton("Import a profile...", ns.ShowImport)
end

-- /kibble profile            lists the profiles
-- /kibble profile <name>     switches this character to it
function ns.ProfileCommand(arg)
	arg = arg or ""
	if arg == "" then
		K.Print(("profiles: %s (this character uses \"%s\"). Switch with /kibble profile <name>; export and import with /kibble export, /kibble import.")
			:format(table.concat(P.Names(), ", "), K.ActiveProfile()))
		return
	end
	local name = P.Find(arg)
	if not name then
		K.Print(("no profile called \"%s\". Profiles: %s."):format(arg, table.concat(P.Names(), ", ")))
	elseif K.UseProfile(name) then
		K.Print(("now using profile \"%s\"."):format(name))
	end
end
