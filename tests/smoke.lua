local path = arg[1]
local function proxy(store)
  store = store or {}
  local p
  p = setmetatable({}, { __index = function(t, k)
    if k == "SetAttribute" then return function(_, a, v) store[a] = v end end
    if k == "GetAttribute" then return function(_, a) return store[a] end end
    if k == "SetScript" then return function(_, ev, f) store["script:"..ev] = f end end
    if k == "HookScript" then return function(_, ev, f) store["hook:"..ev] = f end end
    if k == "IsShown" then return function() return true end end
    if k == "CreateAnimationGroup" or k == "CreateAnimation" or k == "CreateTexture" or k == "CreateMaskTexture" or k == "CreateFontString" then return function() return proxy() end end
    if k == "IsPlaying" then return function() return false end end
    if k == "SetAlpha" then return function(_, a) store.alpha = a end end
    if k == "SetSize" then return function(_, w, h) store.size = w end end
    return function() return p end
  end })
  return p, store
end
local btn, bstore = proxy()
local handlers = {}
local combat = false
local drivers = {}
CreateFrame = function(_, name)
  if name == "KibbleButton" then return btn end
  local f, st = proxy(); handlers.events = st; return f
end
UIParent = proxy(); DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) print("CHAT", m) end }
UnitClass = function() return "Hunter", "HUNTER" end
UnitExists = function() return true end; UnitIsDead = function() return false end
UnitLevel = function() return 20 end
C_PetInfo = { GetPetHappiness = function() return 3 end, CanPetEatItem = function(id) return id ~= 999 end }
local items = { [1] = { 10, 20 }, [2] = { 11, 5 }, [3] = { 12, 3 }, [4] = { 999, 9 } }  -- slot -> {id, count}
local lvl = { [10] = 5, [11] = 16, [12] = 25 }
C_Container = { GetContainerNumSlots = function(b) return b == 0 and 4 or 0 end,
  GetContainerItemInfo = function(b, s) local i = items[s]; return i and { itemID = i[1], stackCount = i[2] } end }
C_Item = { GetItemInfo = function(id) return "Food"..id, nil, nil, lvl[id] end, GetItemIconByID = function() return 1 end, RequestLoadItemDataByID = function() end }
C_Spell = { GetSpellName = function() return "Feed Pet" end, GetSpellTexture = function() return 1 end }
C_Timer = { After = function(_, f) f() end }
C_Texture = { GetAtlasInfo = function() return nil end }
InCombatLockdown = function() return combat end
RegisterStateDriver = function(_, st, ex) drivers[#drivers+1] = ex end
GetTime = function() return 1000 end
STANDARD_TEXT_FONT = "x"; NUM_BAG_SLOTS = 4; wipe = function(t) for k in pairs(t) do t[k]=nil end end
GameTooltip = proxy(); GameTooltip_Hide = function() end; SlashCmdList = {}; IsShiftKeyDown = function() return false end
-- menu recorder
local function node(label, tree) local n = { label = label, kids = {} }
  local function add(kind) return function(self, text, a, b) local c = node(text); c.kind = kind; c.isSel = a; c.set = b; table.insert(self.kids, c); return c end end
  n.CreateTitle = add("title"); n.CreateCheckbox = add("check"); n.CreateRadio = add("radio"); n.CreateButton = function(self, text, fn) local c = node(text); c.kind = "button"; c.fn = fn; table.insert(self.kids, c); return c end
  n.CreateDivider = function() end
  return n end
local menuRoot
MenuUtil = { CreateContextMenu = function(_, build) menuRoot = node("root"); build(nil, menuRoot) end }
RaidNotice_AddMessage = nil; UIErrorsFrame = { AddMessage = function(_, m) print("SCREEN", m) end }; ChatTypeInfo = {}
PlaySound = function() print("SOUND") end

local chunk = assert(loadfile(path)); chunk("Kibble")
FeedMeDB = { pos = { "TOP", "TOP", 7, 9 } }; KibbleDB = nil   -- pre-rename saved data
local ev = handlers.events["script:OnEvent"]
ev(nil, "ADDON_LOADED", "Kibble")
assert(KibbleDB.pos[3] == 7 and FeedMeDB == nil, "FeedMe -> Kibble migration keeps position, clears old var")
assert(KibbleDB.settings.size == 40 and KibbleDB.settings.foodMode == "save", "defaults merged")
assert(bstore.type2 == "", "type2 blocks right-click feed")
assert(drivers[#drivers] == "[@pet,exists,nodead] show; hide", "driver set")
ev(nil, "PLAYER_LOGIN")
print("macro (save mode, pet 20):", bstore.macrotext)
assert(bstore.macrotext:find("item:11"), "save mode should pick lowest level giving full gain (11 >= 15? no -> 12?)")

local function find(n, label) for _, k in ipairs(n.kids) do if k.label == label then return k end end error("no menu entry "..label) end
local function macro() return bstore.macrotext end

-- menu structure
bstore["hook:OnClick"](btn, "RightButton", true);  assert(menuRoot == nil, "no menu on mouse-down")
bstore["hook:OnClick"](btn, "RightButton", false); assert(menuRoot, "menu opens on right-click up")
for _, top in ipairs{"Alerts","Appearance","Food","Visibility"} do find(menuRoot, top) end
print("top-level:", (function() local t = {} for _, k in ipairs(menuRoot.kids) do t[#t+1] = k.label end return table.concat(t, " | ") end)())

-- best mode
local food = find(menuRoot, "Food")
find(food, "Always use the best food").set()
assert(macro():find("item:12"), "best mode picks highest level"); print("best mode ->", "item:12 OK")
find(food, "Save best food (cheapest that still fully feeds)").set()
assert(macro():find("item:11"))

-- ignore list: item 999 (not edible) must not be listed; ignoring 11 moves pick to 12
local ign = find(food, "Ignored foods")
local names = {} for _, k in ipairs(ign.kids) do names[#names+1] = k.label end
print("ignore list:", table.concat(names, ", "))
find(ign, "Food11").set(); assert(macro():find("item:12"), "ignored food skipped"); assert(KibbleDB.settings.ignored[11] == true)
find(ign, "Food11").set(); assert(KibbleDB.settings.ignored[11] == nil, "unignore clears key")
find(ign, "Food11").set(); find(ign, "Food12").set(); find(ign, "Food10").set()
assert(macro() == "", "all ignored -> empty macro"); print("all ignored -> empty macro OK")
for _, id in ipairs{10,11,12} do KibbleDB.settings.ignored[id] = nil end; ev(nil, "BAG_UPDATE_DELAYED")

-- size / opacity / visibility presets
local look = find(menuRoot, "Appearance")
find(look, "Large").set(); assert(KibbleDB.settings.size == 52 and bstore.size == 52, "size applied")
find(look, "50%").set();   assert(bstore.alpha == 0.5)
local vis = find(menuRoot, "Visibility")
find(vis, "Fade while pet is happy").set(); assert(math.abs(bstore.alpha - 0.075) < 1e-9, "fades while happy: "..tostring(bstore.alpha))
find(vis, "Hidden (use /kibble config to open this menu)").set(); assert(drivers[#drivers] == "hide")
find(vis, "Always show").set(); assert(drivers[#drivers] == "[@pet,exists,nodead] show; hide")

-- combat deferral: size change queued, applied at regen
combat = true; local sizeBefore = bstore.size
find(look, "Small").set(); assert(bstore.size == sizeBefore, "size not applied in combat")
find(vis, "Hidden (use /kibble config to open this menu)").set(); assert(drivers[#drivers] == "[@pet,exists,nodead] show; hide", "driver untouched in combat")
combat = false; ev(nil, "PLAYER_REGEN_ENABLED")
assert(bstore.size == 32 and drivers[#drivers] == "hide", "deferred layout applied after combat"); print("combat deferral OK")

-- alerts respect toggles + throttle setting
KibbleDB.settings.alertSound = false; KibbleDB.settings.alertChat = false
for k in pairs(items) do items[k] = nil end
ev(nil, "UNIT_PET", "player"); ev(nil, "BAG_UPDATE_DELAYED")   -- hadFood nil -> no "out of food" alert expected
print("slash:"); SlashCmdList.KIBBLE("config"); assert(menuRoot); SlashCmdList.KIBBLE("")
print("ALL OK")
