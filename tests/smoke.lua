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
    if k == "SetTexture" then return function(_, v) lastTexture = v end end
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
cd = { last = nil }
local cdp
cdp = setmetatable({}, { __index = function(t, k)
  if k == "SetCooldown" then return function(_, st, d) cd.last = { st, d } end end
  if k == "Clear" then return function() cd.last = nil end end
  return function() return cdp end end })
local function recorder()
  local st = { shown = false, enabled = true, scripts = {} }
  local p
  p = setmetatable({}, { __index = function(t, k)
    if k == "SetText" then return function(_, v) st.text = v end end
    if k == "Show" then return function() st.shown = true end end
    if k == "Hide" then return function() st.shown = false end end
    if k == "SetShown" then return function(_, v) st.shown = v end end
    if k == "Enable" then return function() st.enabled = true end end
    if k == "Disable" then return function() st.enabled = false end end
    if k == "SetScript" then return function(_, e, f) st.scripts[e] = f end end
    if k == "SetPoint" then return function(_, pt, rel, rp, x, y) st.point = { pt, rel, rp, x, y } end end
    if k == "CreateTexture" or k == "CreateFontString" then return function() return proxy() end end
    return function() return p end
  end })
  return p, st
end
local rbtn, rst = recorder()   -- vendor restock button
local mbtn, mst = recorder()   -- minimap button
checks = {}
local function newCheck()
  local st = { checked = false, scripts = {} }
  local p
  p = setmetatable({}, { __index = function(t, k)
    if k == "SetChecked" then return function(_, v) st.checked = v end end
    if k == "GetChecked" then return function() return st.checked end end
    if k == "SetScript" then return function(_, e, f) st.scripts[e] = f end end
    return function() return p end
  end })
  st.obj = p
  return p, st
end
frames = {}
CreateFrame = function(_, name, _, template)
  if template == "CooldownFrameTemplate" then return cdp end
  if name == "KibbleButton" then return btn end
  if name == "KibbleRestockButton" then return rbtn end
  if name == "KibbleMinimapButton" then return mbtn end
  if template == "UICheckButtonTemplate" then local c, cst = newCheck(); checks[#checks + 1] = cst; return c end
  local f, st = proxy(); frames[#frames + 1] = { p = f, st = st }; handlers.events = frames[1].st; return f
end
UIParent = proxy(); DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) print("CHAT", m) end }
UnitClass = function() return "Hunter", "HUNTER" end
petExists, petDead = true, false
UnitExists = function() return petExists end; UnitIsDead = function() return petDead end
IsControlKeyDown = function() return false end
UnitLevel = function() return 20 end
C_PetInfo = { GetPetHappiness = function() return 3 end, CanPetEatItem = function(id) return id ~= 999 end }
local items = { [1] = { 10, 20 }, [2] = { 11, 5 }, [3] = { 12, 3 }, [4] = { 999, 9 } }  -- slot -> {id, count}
local lvl = { [10] = 5, [11] = 16, [12] = 25 }
scans = 0
C_Container = { GetContainerNumSlots = function(b) return b == 0 and 4 or 0 end,
  GetContainerItemInfo = function(b, s) scans = scans + 1; local i = items[s]; return i and { itemID = i[1], stackCount = i[2] } end,
  GetContainerNumFreeSlots = function(b) if b ~= 0 then return 0, 0 end local n = 0 for sl = 1, 4 do if not items[sl] then n = n + 1 end end return n, 0 end }
C_Item = { GetItemCount = function(id) local n = 0 for _, i in pairs(items) do if i[1] == id then n = n + i[2] end end return n end,
  GetItemMaxStackSizeByID = function() return 20 end, GetItemInfo = function(id) return "Food"..id, nil, nil, lvl[id] end, GetItemIconByID = function() return 1 end, RequestLoadItemDataByID = function() end }
spellNames = { [6991] = "Feed Pet", [883] = "Call Pet", [982] = "Revive Pet", [136] = "Mend Pet" }
C_Spell = { GetSpellName = function(id) return spellNames[id] end, GetSpellTexture = function(id) return 1000 + id end }
C_Timer = { After = function(_, f) f() end }
C_Texture = { GetAtlasInfo = function() return nil end }
InCombatLockdown = function() return combat end
RegisterStateDriver = function(_, st, ex) drivers[#drivers+1] = ex end
clock = 1000; GetTime = function() return clock end
STANDARD_TEXT_FONT = "x"; NUM_BAG_SLOTS = 4; wipe = function(t) for k in pairs(t) do t[k]=nil end end
-- vendor, minimap and options-panel stubs
merchant = {}; money = 100000; bought = {}
MerchantFrame = { IsShown = function() return true end, selectedTab = 1 }
GetMerchantNumItems = function() return #merchant end
GetMerchantItemID = function(i) return merchant[i] and merchant[i].id end
GetMerchantItemMaxStack = function(i) return merchant[i].maxStack end
C_MerchantFrame = { GetItemInfo = function(i) local m = merchant[i]; return m and { price = m.price, stackCount = m.stack, numAvailable = m.avail or -1, hasExtendedCost = m.ext, name = "V"..m.id } end }
GetMoney = function() return money end
C_CurrencyInfo = { GetCoinTextureString = function(c) return c .. "c" end }
pending = {}
BuyMerchantItem = function(index, n) bought[#bought + 1] = n; pending[#pending + 1] = { index, n } end
-- purchases reach the bags later, like the real client
function deliver()
  for _, b in ipairs(pending) do
    local m = merchant[b[1]]; money = money - (b[2] / m.stack) * m.price
    local placed = false
    for _, i in pairs(items) do if i[1] == m.id and not placed then i[2] = i[2] + b[2]; placed = true end end
    if not placed then for sl = 1, 4 do if not items[sl] and not placed then items[sl] = { m.id, b[2] }; placed = true end end end
  end
  pending = {}
end
cursor = { 575, 500 }
GetCursorPosition = function() return cursor[1], cursor[2] end
Minimap = { GetWidth = function() return 140 end, GetCenter = function() return 500, 500 end, GetEffectiveScale = function() return 1 end }
opened = nil
Settings = { RegisterCanvasLayoutCategory = function(f, name) panelRegistered = name; return { GetID = function() return 99 end } end,
  RegisterAddOnCategory = function() end, OpenToCategory = function(id) opened = id end }
GameTooltip = proxy(); GameTooltip_Hide = function() end; SlashCmdList = {}; IsShiftKeyDown = function() return false end
-- menu recorder
local function node(label, tree) local n = { label = label, kids = {} }
  local function add(kind) return function(self, text, a, b) local c = node(text); c.kind = kind; c.isSel = a; c.set = b; table.insert(self.kids, c); return c end end
  n.CreateTitle = add("title"); n.CreateCheckbox = add("check"); n.CreateRadio = add("radio"); n.CreateButton = function(self, text, fn) local c = node(text); c.kind = "button"; c.fn = fn; table.insert(self.kids, c); return c end
  n.CreateDivider = function() end
  return n end
local menuRoot
MenuUtil = { CreateContextMenu = function(_, build) menuRoot = node("root"); build(nil, menuRoot) end }
RaidNotice_AddMessage = nil; shown = {}; UIErrorsFrame = { AddMessage = function(_, m) shown[#shown+1] = m; print("SCREEN", m) end }; ChatTypeInfo = {}
played = {}; PlaySound = function(id) played[#played+1] = id end
SOUNDKIT = { RAID_WARNING = 1, TELL_MESSAGE = 2, IG_QUEST_LIST_COMPLETE = 3, IG_QUEST_LIST_OPEN = 4 }
petAuras = {}; C_UnitAuras = { GetAuraDataByIndex = function(unit, i, filter) assert(unit == "pet" and filter == "HELPFUL"); return petAuras[i] end }

local chunk = assert(loadfile(path))
local ns = {}
local dir = path:match("^(.*)/[^/]*$") or "."
chunk("Kibble", ns)
for _, f in ipairs{ "Restock.lua", "Panel.lua" } do assert(loadfile(dir .. "/" .. f))("Kibble", ns) end
FeedMeDB = { pos = { "TOP", "TOP", 7, 9 } }; KibbleDB = nil   -- pre-rename saved data
local ev = frames[1].st["script:OnEvent"]
ev(nil, "ADDON_LOADED", "Kibble")
assert(KibbleDB.pos[3] == 7 and FeedMeDB == nil, "FeedMe -> Kibble migration keeps position, clears old var")
assert(KibbleDB.settings.size == 40 and KibbleDB.settings.foodMode == "save", "defaults merged")
assert(bstore.type2 == "", "type2 blocks right-click feed")
assert(drivers[#drivers] == "show", "driver set")
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
assert(not macro():find("Feed Pet") and not macro():find("/use"), "all ignored -> no feed branch, no /use"); assert(macro():find("Revive Pet"), "pet care still there"); print("all ignored -> no feed branch OK")
for _, id in ipairs{10,11,12} do KibbleDB.settings.ignored[id] = nil end; ev(nil, "BAG_UPDATE_DELAYED")

-- size / opacity / visibility presets
local look = find(menuRoot, "Appearance")
find(look, "Large").set(); assert(KibbleDB.settings.size == 52 and bstore.size == 52, "size applied")
find(look, "50%").set();   assert(bstore.alpha == 0.5)
local vis = find(menuRoot, "Visibility")
find(vis, "Fade while pet is happy").set(); assert(math.abs(bstore.alpha - 0.075) < 1e-9, "fades while happy: "..tostring(bstore.alpha))
find(vis, "Hidden (use /kibble config to open this menu)").set(); assert(drivers[#drivers] == "hide")
find(vis, "Always show").set(); assert(drivers[#drivers] == "show")

-- combat deferral: size change queued, applied at regen
combat = true; local sizeBefore = bstore.size
find(look, "Small").set(); assert(bstore.size == sizeBefore, "size not applied in combat")
find(vis, "Hidden (use /kibble config to open this menu)").set(); assert(drivers[#drivers] == "show", "driver untouched in combat")
combat = false; ev(nil, "PLAYER_REGEN_ENABLED")
assert(bstore.size == 32 and drivers[#drivers] == "hide", "deferred layout applied after combat"); print("combat deferral OK")

-- alerts respect toggles + throttle setting
KibbleDB.settings.alertSound = false; KibbleDB.settings.alertChat = false
for k in pairs(items) do items[k] = nil end
ev(nil, "UNIT_PET", "player"); ev(nil, "BAG_UPDATE_DELAYED")   -- hadFood nil -> no "out of food" alert expected

-- ===== 1.2 features =====
assert(KibbleDB.settings.alertSound == false and KibbleDB.settings.lowFood == 0, "sound + low-food default OFF")
local alerts = find(menuRoot, "Alerts")
local function reset_food(items_) for k in pairs(items) do items[k] = nil end for k, v in pairs(items_) do items[k] = v end end
KibbleDB.settings.alertScreen = true; KibbleDB.settings.alertChat = false; KibbleDB.settings.throttle = 15

-- low-food warning
reset_food{ [1] = { 10, 50 } }; clock = clock + 100; ev(nil, "UNIT_PET", "player"); shown = {}
find(alerts, "10 or fewer").set(); assert(#shown == 0, "no warning while food above threshold")
items[1] = { 10, 8 }; clock = clock + 100; ev(nil, "BAG_UPDATE_DELAYED")
assert(#shown == 1 and shown[1]:find("low on pet food %(8 left%)"), "warns when dropping to threshold: "..tostring(shown[1]))
clock = clock + 100; ev(nil, "BAG_UPDATE_DELAYED"); assert(#shown == 1, "no repeat while still low")
items[1] = { 10, 50 }; ev(nil, "BAG_UPDATE_DELAYED")
items[1] = { 10, 6 }; clock = clock + 100; ev(nil, "BAG_UPDATE_DELAYED"); assert(#shown == 2, "re-armed after restocking")
find(alerts, "Off").set(); items[1] = { 10, 50 }; ev(nil, "BAG_UPDATE_DELAYED"); items[1] = { 10, 1 }; clock = clock + 100; ev(nil, "BAG_UPDATE_DELAYED")
assert(#shown == 2, "Off disables the warning"); assert(#played == 0, "no sound while sound is off (default)")
print("low-food warning OK")

-- sound opt-in + picker
find(alerts, "Whisper ping").set(); assert(played[#played] == 2, "picker previews the sound")
KibbleDB.settings.alertSound = true; KibbleDB.settings.lowFood = 10; items[1] = { 10, 50 }; ev(nil, "BAG_UPDATE_DELAYED")
local n = #played; items[1] = { 10, 4 }; clock = clock + 100; ev(nil, "BAG_UPDATE_DELAYED")
assert(#played == n + 1 and played[#played] == 2, "alert plays the chosen sound once sound is enabled")
KibbleDB.settings.alertSound = false; KibbleDB.settings.lowFood = 0
print("sound opt-in OK")

-- smallest-stack mode (pet level 20: foods 11 (lvl16) and 12 (lvl25) both give full happiness)
reset_food{ [1] = { 11, 30 }, [2] = { 12, 3 } }; ev(nil, "UNIT_PET", "player")
local food = find(menuRoot, "Food")
find(food, "Save best food (cheapest that still fully feeds)").set(); assert(macro():find("item:11"), "save mode -> lowest level")
find(food, "Smallest stack first (frees bag space)").set(); assert(macro():find("item:12"), "stack mode -> smallest stack: "..macro())
reset_food{ [1] = { 11, 3 }, [2] = { 12, 3 } }; ev(nil, "UNIT_PET", "player"); assert(macro():find("item:11"), "stack tie -> lower level")
reset_food{ [1] = { 10, 1 }, [2] = { 12, 9 } }; ev(nil, "UNIT_PET", "player"); assert(macro():find("item:12"), "stack mode still only prefers foods that fully feed")
find(food, "Save best food (cheapest that still fully feeds)").set()
print("smallest-stack mode OK")

-- feeding countdown: Feed Pet is a plain cast; the pet carries a buff while it eats
local look2 = find(menuRoot, "Appearance")
petAuras = {}
petAuras[1] = { name = "Mark of the Wild", spellId = 1126, duration = 3600, expirationTime = clock + 3000 }
ev(nil, "UNIT_AURA", "pet"); assert(cd.last == nil, "unrelated buffs do not start the countdown")
petAuras[2] = { name = "Feed Pet Effect", spellId = 1539, duration = 10, expirationTime = clock + 10 }
ev(nil, "UNIT_AURA", "pet"); assert(cd.last and cd.last[1] == clock and cd.last[2] == 10, "countdown starts from the buff (by spell id)")
petAuras[2] = nil; ev(nil, "UNIT_AURA", "pet"); assert(cd.last == nil, "countdown clears when the buff ends")
petAuras[2] = { name = "Nom Nom", spellId = 1539, duration = 6, expirationTime = clock + 6 }
ev(nil, "UNIT_AURA", "pet"); assert(cd.last and cd.last[2] == 6, "matches by spell id even if the name differs")
petAuras[2] = { name = "Feed Pet Effect", spellId = 99999, duration = 8, expirationTime = clock + 8 }
ev(nil, "UNIT_AURA", "pet"); assert(cd.last and cd.last[2] == 8, "also matches by name when the spell id differs")
petAuras[2] = { name = "SECRET", spellId = 1539, duration = 8, expirationTime = clock + 8 }; issecretvalue = function(v) return v == "SECRET" end
ev(nil, "UNIT_AURA", "pet"); assert(cd.last == nil, "restricted (secret) auras are skipped, not compared")
issecretvalue = nil
petAuras[2] = { name = "Feed Pet Effect", spellId = 1539, duration = 10, expirationTime = clock + 10 }
find(look2, "Show feeding countdown").set(); ev(nil, "UNIT_AURA", "pet"); assert(cd.last == nil, "countdown can be turned off")
find(look2, "Show feeding countdown").set(); ev(nil, "UNIT_AURA", "pet"); assert(cd.last, "and back on")
petAuras = {}; ev(nil, "UNIT_AURA", "pet")
print("feeding countdown OK")


-- ===== 1.3 features =====
local vis3 = find(menuRoot, "Visibility")
local CARE = "Revive / call a missing pet (Ctrl-click mends)"
chatlog = {}; DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) chatlog[#chatlog + 1] = m end }

-- pet-care macro
find(vis3, "Always show").set()
reset_food{ [1] = { 11, 30 } }; ev(nil, "UNIT_PET", "player")
for _, frag in ipairs{ "[@pet,dead] Revive Pet", "[nopet] Call Pet", "[@pet,exists,nodead,mod:ctrl] Mend Pet",
    "[@pet,exists,nodead] Feed Pet", "/use [@pet,exists,nodead,nomod:ctrl] item:11" } do
  assert(macro():find(frag, 1, true), "pet-care macro has "..frag.." :: "..macro())
end
find(vis3, CARE).set()
assert(macro() == "/cast Feed Pet\n/use item:11", "care off -> plain feed macro: "..macro())
assert(drivers[#drivers] == "[@pet,exists,nodead] show; hide", "care off -> old visibility driver")
find(vis3, CARE).set()
assert(macro():find("Revive Pet") and drivers[#drivers] == "show", "care back on")
print("pet-care macro OK")

-- dead / missing pet: icon + no nagging, and the button is not faded
petDead = true; ev(nil, "UNIT_HEALTH", "pet"); assert(lastTexture == 1982, "dead pet shows Revive Pet icon: "..tostring(lastTexture))
petDead = false; petExists = false; ev(nil, "UNIT_HEALTH", "pet"); assert(lastTexture == 1883, "missing pet shows Call Pet icon: "..tostring(lastTexture))
reset_food{}; chatlog = {}; clock = clock + 10
bstore["hook:OnClick"](btn, "LeftButton", false); assert(#chatlog == 0, "no 'no food' message while the pet is missing")
find(vis3, "Fade while pet is happy").set()
assert(bstore.alpha == KibbleDB.settings.opacity, "not faded while offering to call the pet: "..tostring(bstore.alpha))
petExists = true; ev(nil, "UNIT_PET", "player")
assert(bstore.alpha < KibbleDB.settings.opacity, "faded again once the pet is back and happy")
find(vis3, "Always show").set()
clock = clock + 10; bstore["hook:OnClick"](btn, "LeftButton", false); assert(#chatlog == 1 and chatlog[1]:find("no food"), "message returns with a living pet")
lastTexture = nil; ev(nil, "UNIT_HEALTH", "pet"); assert(lastTexture == nil, "health ticks without a state change do not refresh")
petDead = true; ev(nil, "UNIT_HEALTH", "pet"); assert(lastTexture == 1982, "pet dying refreshes")
petDead = false; ev(nil, "UNIT_HEALTH", "pet")
print("pet states OK")

-- ===== vendor restock =====
local rev = frames[2].st["script:OnEvent"]
lvl[20] = 15; lvl[21] = 15
merchant = {
  { id = 999, price = 10, stack = 1, maxStack = 20 },                 -- pet can't eat it
  { id = 21,  price = 5,  stack = 1, maxStack = 20, ext = true },     -- costs a token: skipped
  { id = 20,  price = 25, stack = 5, maxStack = 20 },                 -- bundles of 5, 20 per purchase
}
reset_food{ [1] = { 11, 3 } }; money = 100000; bought = {}; pending = {}; KibbleDB.settings.restockTarget = 40
rev(nil, "MERCHANT_SHOW")
assert(rst.shown and rst.enabled and rst.text == "Restock pet food (buy 40)", "restock button offered: "..tostring(rst.text))
assert(#bought == 0, "nothing is bought until the button is clicked")
rst.scripts.OnClick()
assert(#bought == 1 and bought[1] == 20, "first purchase is capped at the per-purchase maximum")
assert(rst.text == "Restocking..." and not rst.enabled, "button shows progress")
rev(nil, "BAG_UPDATE_DELAYED"); assert(#bought == 1, "waits until the bags show the first purchase")
deliver(); rev(nil, "BAG_UPDATE_DELAYED"); assert(#bought == 2 and bought[2] == 20, "second purchase after the first arrived")
deliver(); rev(nil, "BAG_UPDATE_DELAYED")
assert(C_Item.GetItemCount(20) == 40 and #bought == 2, "stops at the target")
assert(chatlog[#chatlog]:find("bought 40"), "reports the result: "..tostring(chatlog[#chatlog]))
assert(rst.text == "Pet food stocked (40)" and not rst.enabled, "stocked state: "..tostring(rst.text))
print("restock buy loop OK")

-- limits
reset_food{ [1] = { 11, 3 } }; money = 100; rev(nil, "MERCHANT_UPDATE")
assert(rst.text == "Restock pet food (buy 20)", "limited by gold (4 bundles): "..tostring(rst.text))
money = 100000
reset_food{ [1] = { 11, 3 }, [2] = { 10, 3 }, [3] = { 12, 3 }, [4] = { 999, 3 } }; rev(nil, "MERCHANT_UPDATE")
assert(rst.text == "Bags are full" and not rst.enabled, "bags full: "..tostring(rst.text))
reset_food{ [1] = { 11, 3 } }
local food3 = find(menuRoot, "Food")
find(food3, "20").set(); assert(rst.text == "Restock pet food (buy 20)", "target from the menu applies at once: "..tostring(rst.text))
KibbleDB.settings.restockTarget = 40
petExists = false; rev(nil, "UNIT_PET"); assert(not rst.shown, "hidden without a pet")
petExists = true; rev(nil, "UNIT_PET"); assert(rst.shown)
MerchantFrame.selectedTab = 2; rev(nil, "MERCHANT_UPDATE"); assert(not rst.shown, "hidden on the buyback tab"); MerchantFrame.selectedTab = 1
KibbleDB.settings.ignored[20] = true; rev(nil, "MERCHANT_UPDATE"); assert(not rst.shown, "ignored foods are not offered"); KibbleDB.settings.ignored[20] = nil
merchant = { { id = 21, price = 5, stack = 1, maxStack = 20, ext = true } }; rev(nil, "MERCHANT_UPDATE"); assert(not rst.shown, "extended-cost items are not offered")
merchant = { { id = 20, price = 25, stack = 5, maxStack = 20 } }; rev(nil, "MERCHANT_UPDATE"); assert(rst.shown)
bought = {}; rst.scripts.OnClick(); rev(nil, "MERCHANT_CLOSED"); assert(chatlog[#chatlog]:find("restock stopped"), "closing the vendor stops the run")
deliver(); rev(nil, "BAG_UPDATE_DELAYED"); assert(#bought == 1, "no further purchases after the vendor closed")
print("restock limits OK")

-- ===== options panel, minimap button, compartment =====
assert(type(Kibble_OnCompartmentClick) == "function" and type(Kibble_OnCompartmentEnter) == "function", "compartment globals")
frames[3].st["script:OnEvent"](frames[3].p, "PLAYER_LOGIN")
assert(panelRegistered == "Kibble" and #checks == 10, "panel registered with 10 options")
local panelFrame = frames[4].st
KibbleDB.settings.alertScreen = false; panelFrame["script:OnShow"](); assert(checks[1].checked == false and checks[2].checked == KibbleDB.settings.alertChat, "panel shows current settings")
KibbleDB.settings.alertScreen = true
checks[9].checked = false; checks[9].scripts.OnClick(checks[9].obj)
assert(KibbleDB.settings.petCare == false and macro():find("^/cast Feed Pet") and not macro():find("Revive"), "panel checkbox applies (care off -> plain feed macro): "..macro())
checks[9].checked = true; checks[9].scripts.OnClick(checks[9].obj); assert(KibbleDB.settings.petCare == true)
assert(mst.shown, "minimap button shown by default")
local ang = KibbleDB.settings.minimapAngle
assert(math.abs(mst.point[4] - math.cos(ang) * 75) < 1e-6 and math.abs(mst.point[5] - math.sin(ang) * 75) < 1e-6, "minimap placement")
mst.scripts.OnDragStart(mbtn); assert(mst.scripts.OnUpdate, "dragging tracks the cursor")
mst.scripts.OnUpdate(); assert(math.abs(KibbleDB.settings.minimapAngle) < 1e-6 and math.abs(mst.point[4] - 75) < 1e-6, "angle follows the cursor")
cursor = { 500, 575 }; mst.scripts.OnUpdate(); assert(math.abs(KibbleDB.settings.minimapAngle - math.pi / 2) < 1e-6)
mst.scripts.OnDragStop(mbtn); assert(mst.scripts.OnUpdate == nil, "drag ends cleanly")
checks[10].checked = false; checks[10].scripts.OnClick(checks[10].obj); assert(mst.shown == false, "panel can hide the minimap button")
find(find(menuRoot, "Appearance"), "Show minimap button").set(); assert(mst.shown == true, "menu can show it again")
menuRoot = nil; mst.scripts.OnClick(mbtn, "LeftButton"); assert(menuRoot, "minimap left-click opens the menu")
opened = nil; mst.scripts.OnClick(mbtn, "RightButton"); assert(opened == 99, "minimap right-click opens the options panel")
opened = nil; Kibble_OnCompartmentClick(nil, "RightButton"); assert(opened == 99, "compartment right-click opens the panel")
menuRoot = nil; Kibble_OnCompartmentClick(nil, "LeftButton"); assert(menuRoot, "compartment click opens the menu")
print("panel + minimap + compartment OK")

-- sound-off migration (settings saved by 1.1.0 had alertSound = true as the old default)
local c2 = assert(loadfile(arg[1] or "Kibble.lua"))
KibbleDB = { settings = { alertSound = true, size = 52 } }; FeedMeDB = nil; c2("Kibble")
frames[1].st["script:OnEvent"](nil, "ADDON_LOADED", "Kibble")
assert(KibbleDB.settings.alertSound == false and KibbleDB.settings.size == 52 and KibbleDB.settings.settingsVersion == 2, "1.1.0 'sound on' reset once, other settings kept")
KibbleDB.settings.alertSound = true; c2("Kibble"); frames[1].st["script:OnEvent"](nil, "ADDON_LOADED", "Kibble")
assert(KibbleDB.settings.alertSound == true, "a deliberate opt-in survives later loads")
print("sound migration OK")

print("slash:")
local chat = {}; DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) chat[#chat+1] = m end }
SlashCmdList.KIBBLE("buffs"); assert(chat[#chat]:find("no buffs"), "buffs: empty list message")
petAuras[1] = { name = "Feed Pet Effect", spellId = 1539, duration = 10 }; SlashCmdList.KIBBLE("buffs")
assert(chat[#chat]:find("Feed Pet Effect") and chat[#chat]:find("1539"), "buffs: lists name and spell id")
SlashCmdList.KIBBLE("config"); assert(menuRoot); SlashCmdList.KIBBLE("")
print("ALL OK")
