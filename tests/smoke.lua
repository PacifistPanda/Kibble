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
    if k == "SetText" then return function(_, v) store.text = v end end
    if k == "GetText" then return function() return store.text or "" end end
    if k == "GetStringHeight" then return function() return 20 end end
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
    if k == "IsEnabled" then return function() return st.enabled end end
    if k == "SetScript" then return function(_, e, f) st.scripts[e] = f end end
    if k == "SetPoint" then return function(_, pt, rel, rp, x, y) st.point = { pt, rel, rp, x, y }; st.points = st.points or {}; st.points[#st.points + 1] = st.point end end
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
  local f, st = proxy(); frames[#frames + 1] = { p = f, st = st }; handlers.events = frames[1].st
  if name == "KibbleDialog" then dialogIndex = #frames end
  return f
end
UIParent = proxy(); DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) print("CHAT", m) end }
UnitClass = function() return "Hunter", "HUNTER" end
playerName = "Hunter"; UnitName = function() return playerName end; GetRealmName = function() return "Realm" end; UISpecialFrames = {}
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
MerchantFrameTab1, MerchantFrameTab2 = { name = "tab1" }, { name = "tab2" }
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
-- EllesmereUI skin registration + facade stub
skinFn, skinName, skinCalls, Sstub = nil, nil, {}, {}
EllesmereUI = { RegisterSkin = function(name, fn) skinName = name; skinFn = fn end }
for _, k in ipairs{ "Button", "StateButtonLabel", "Checkbox", "Tab", "SetTabSelection" } do Sstub[k] = function(w, a) skinCalls[#skinCalls + 1] = { k, w, a } end end
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
for _, f in ipairs{ "Restock.lua", "Profiles.lua", "Panel.lua" } do assert(loadfile(dir .. "/" .. f))("Kibble", ns) end
FeedMeDB = { pos = { "TOP", "TOP", 7, 9 } }; KibbleDB = nil   -- pre-rename saved data
local ev = frames[1].st["script:OnEvent"]
ev(nil, "ADDON_LOADED", "Kibble")
assert(KibbleDB.pos[3] == 7 and FeedMeDB == nil, "FeedMe -> Kibble migration keeps position, clears old var")
assert(KibbleDB.profiles.Default.size == 40 and KibbleDB.profiles.Default.foodMode == "save", "defaults merged")
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
find(ign, "Food11").set(); assert(macro():find("item:12"), "ignored food skipped"); assert(KibbleDB.profiles.Default.ignored[11] == true)
find(ign, "Food11").set(); assert(KibbleDB.profiles.Default.ignored[11] == nil, "unignore clears key")
find(ign, "Food11").set(); find(ign, "Food12").set(); find(ign, "Food10").set()
assert(not macro():find("Feed Pet") and not macro():find("/use"), "all ignored -> no feed branch, no /use"); assert(macro():find("Revive Pet"), "pet care still there"); print("all ignored -> no feed branch OK")
for _, id in ipairs{10,11,12} do KibbleDB.profiles.Default.ignored[id] = nil end; ev(nil, "BAG_UPDATE_DELAYED")

-- size / opacity / visibility presets
local look = find(menuRoot, "Appearance")
find(look, "Large").set(); assert(KibbleDB.profiles.Default.size == 52 and bstore.size == 52, "size applied")
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
KibbleDB.profiles.Default.alertSound = false; KibbleDB.profiles.Default.alertChat = false
for k in pairs(items) do items[k] = nil end
ev(nil, "UNIT_PET", "player"); ev(nil, "BAG_UPDATE_DELAYED")   -- hadFood nil -> no "out of food" alert expected

-- ===== 1.2 features =====
assert(KibbleDB.profiles.Default.alertSound == false and KibbleDB.profiles.Default.lowFood == 0, "sound + low-food default OFF")
local alerts = find(menuRoot, "Alerts")
local function reset_food(items_) for k in pairs(items) do items[k] = nil end for k, v in pairs(items_) do items[k] = v end end
KibbleDB.profiles.Default.alertScreen = true; KibbleDB.profiles.Default.alertChat = false; KibbleDB.profiles.Default.throttle = 15

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
KibbleDB.profiles.Default.alertSound = true; KibbleDB.profiles.Default.lowFood = 10; items[1] = { 10, 50 }; ev(nil, "BAG_UPDATE_DELAYED")
local n = #played; items[1] = { 10, 4 }; clock = clock + 100; ev(nil, "BAG_UPDATE_DELAYED")
assert(#played == n + 1 and played[#played] == 2, "alert plays the chosen sound once sound is enabled")
KibbleDB.profiles.Default.alertSound = false; KibbleDB.profiles.Default.lowFood = 0
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
assert(bstore.alpha == KibbleDB.profiles.Default.opacity, "not faded while offering to call the pet: "..tostring(bstore.alpha))
petExists = true; ev(nil, "UNIT_PET", "player")
assert(bstore.alpha < KibbleDB.profiles.Default.opacity, "faded again once the pet is back and happy")
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
reset_food{ [1] = { 11, 3 } }; money = 100000; bought = {}; pending = {}; KibbleDB.profiles.Default.restockTarget = 40
rev(nil, "MERCHANT_SHOW")
assert(rst.shown and rst.enabled and rst.text == "Buy 40 pet food", "restock button offered: "..tostring(rst.text))
local function hasPoint(pt, rel, rp) for _, q in ipairs(rst.points or {}) do if q[1] == pt and q[2] == rel and q[3] == rp then return true end end return false end
assert(hasPoint("LEFT", MerchantFrameTab2, "RIGHT"), "button follows the last Merchant/Buyback tab, so no skin can cover it")
assert(hasPoint("RIGHT", MerchantFrame, "RIGHT"), "and is pinned to the window's right edge, so it never overhangs")
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
assert(rst.text == "Buy 20 pet food", "limited by gold (4 bundles): "..tostring(rst.text))
money = 100000
reset_food{ [1] = { 11, 3 }, [2] = { 10, 3 }, [3] = { 12, 3 }, [4] = { 999, 3 } }; rev(nil, "MERCHANT_UPDATE")
assert(rst.text == "Bags are full" and not rst.enabled, "bags full: "..tostring(rst.text))
reset_food{ [1] = { 11, 3 } }
local food3 = find(menuRoot, "Food")
find(food3, "20").set(); assert(rst.text == "Buy 20 pet food", "target from the menu applies at once: "..tostring(rst.text))
KibbleDB.profiles.Default.restockTarget = 40
petExists = false; rev(nil, "UNIT_PET"); assert(not rst.shown, "hidden without a pet")
petExists = true; rev(nil, "UNIT_PET"); assert(rst.shown)
MerchantFrame.selectedTab = 2; rev(nil, "MERCHANT_UPDATE"); assert(not rst.shown, "hidden on the buyback tab"); MerchantFrame.selectedTab = 1
KibbleDB.profiles.Default.ignored[20] = true; rev(nil, "MERCHANT_UPDATE"); assert(not rst.shown, "ignored foods are not offered"); KibbleDB.profiles.Default.ignored[20] = nil
merchant = { { id = 21, price = 5, stack = 1, maxStack = 20, ext = true } }; rev(nil, "MERCHANT_UPDATE"); assert(not rst.shown, "extended-cost items are not offered")
merchant = { { id = 20, price = 25, stack = 5, maxStack = 20 } }; rev(nil, "MERCHANT_UPDATE"); assert(rst.shown)
bought = {}; rst.scripts.OnClick(); rev(nil, "MERCHANT_CLOSED"); assert(chatlog[#chatlog]:find("restock stopped"), "closing the vendor stops the run")
deliver(); rev(nil, "BAG_UPDATE_DELAYED"); assert(#bought == 1, "no further purchases after the vendor closed")
print("restock limits OK")

-- restock button follows the pet's real state (regression: summoning the pet after the vendor opened)
merchant = { { id = 20, price = 25, stack = 5, maxStack = 20 } }
reset_food{ [1] = { 11, 3 } }; money = 100000; petExists = false
ev(nil, "UNIT_PET", "player"); rev(nil, "MERCHANT_SHOW"); assert(not rst.shown, "no button while the pet is missing")
petExists = true; ev(nil, "UNIT_PET", "player")
assert(rst.shown and rst.text == "Buy 40 pet food", "button appears once the pet is back, without a vendor event: "..tostring(rst.text))
-- picks among affordable foods instead of failing on the best one
lvl[22] = 5; lvl[23] = 30
merchant = { { id = 23, price = 500, stack = 1, maxStack = 20 }, { id = 22, price = 5, stack = 1, maxStack = 20 } }
money = 100; KibbleDB.profiles.Default.foodMode = "save"; rev(nil, "MERCHANT_UPDATE")
assert(rst.text == "Buy 20 pet food", "buys the affordable food when the best is too dear: "..tostring(rst.text))
money = 1; rev(nil, "MERCHANT_UPDATE"); assert(rst.shown and not rst.enabled and rst.text == "Can't afford pet food", "says why when nothing is affordable: "..tostring(rst.text))
money = 100000; merchant = { { id = 20, price = 25, stack = 5, maxStack = 20 } }; rev(nil, "MERCHANT_UPDATE")
print("restock follows pet + affordability OK")

-- /kibble vendor diagnostic
merchant = { { id = 999, price = 10, stack = 1, maxStack = 20 }, { id = 20, price = 25, stack = 5, maxStack = 20 } }
chatlog = {}; reset_food{ [1] = { 11, 3 } }; SlashCmdList.KIBBLE("vendor")
local diag = table.concat(chatlog, "\n")
assert(diag:find("pet out: true") and diag:find("Food20") and not diag:find("Food999"), "diagnostic lists only the edible vendor food: "..diag)
assert(diag:find("plan: buy 40"), "diagnostic reports the plan: "..diag)
petExists = false; chatlog = {}; SlashCmdList.KIBBLE("vendor")
assert(table.concat(chatlog, "\n"):find("plan: none"), "diagnostic explains a hidden button when no pet is out")
petExists = true
print("vendor diagnostic OK")

-- ===== options panel, minimap button, compartment =====
assert(type(Kibble_OnCompartmentClick) == "function" and type(Kibble_OnCompartmentEnter) == "function", "compartment globals")
frames[3].st["script:OnEvent"](frames[3].p, "PLAYER_LOGIN")
assert(panelRegistered == "Kibble" and #checks == 10, "panel registered with 10 options")
local panelFrame = frames[4].st
KibbleDB.profiles.Default.alertScreen = false; panelFrame["script:OnShow"](); assert(checks[1].checked == false and checks[2].checked == KibbleDB.profiles.Default.alertChat, "panel shows current settings")
KibbleDB.profiles.Default.alertScreen = true
checks[9].checked = false; checks[9].scripts.OnClick(checks[9].obj)
assert(KibbleDB.profiles.Default.petCare == false and macro():find("^/cast Feed Pet") and not macro():find("Revive"), "panel checkbox applies (care off -> plain feed macro): "..macro())
checks[9].checked = true; checks[9].scripts.OnClick(checks[9].obj); assert(KibbleDB.profiles.Default.petCare == true)
assert(mst.shown, "minimap button shown by default")
local ang = KibbleDB.minimapAngle or 3.93 -- unset until the button is dragged
assert(math.abs(mst.point[4] - math.cos(ang) * 75) < 1e-6 and math.abs(mst.point[5] - math.sin(ang) * 75) < 1e-6, "minimap placement")
mst.scripts.OnDragStart(mbtn); assert(mst.scripts.OnUpdate, "dragging tracks the cursor")
mst.scripts.OnUpdate(); assert(math.abs(KibbleDB.minimapAngle) < 1e-6 and math.abs(mst.point[4] - 75) < 1e-6, "angle follows the cursor")
cursor = { 500, 575 }; mst.scripts.OnUpdate(); assert(math.abs(KibbleDB.minimapAngle - math.pi / 2) < 1e-6)
mst.scripts.OnDragStop(mbtn); assert(mst.scripts.OnUpdate == nil, "drag ends cleanly")
checks[10].checked = false; checks[10].scripts.OnClick(checks[10].obj); assert(mst.shown == false, "panel can hide the minimap button")
find(find(menuRoot, "Appearance"), "Show minimap button").set(); assert(mst.shown == true, "menu can show it again")
menuRoot = nil; mst.scripts.OnClick(mbtn, "LeftButton"); assert(menuRoot, "minimap left-click opens the menu")
opened = nil; mst.scripts.OnClick(mbtn, "RightButton"); assert(opened == 99, "minimap right-click opens the options panel")
opened = nil; Kibble_OnCompartmentClick(nil, "RightButton"); assert(opened == 99, "compartment right-click opens the panel")
menuRoot = nil; Kibble_OnCompartmentClick(nil, "LeftButton"); assert(menuRoot, "compartment click opens the menu")
print("panel + minimap + compartment OK")


-- ===== EllesmereUI skin =====
assert(skinName == "Kibble" and type(skinFn) == "function", "registered with EllesmereUI under the addon name")
assert(#skinCalls == 0, "nothing is skinned before EllesmereUI hands over its facade")
skinFn(Sstub)
local function skinCount(kind) local n = 0 for _, c in ipairs(skinCalls) do if c[1] == kind then n = n + 1 end end return n end
assert(skinCount("Tab") == 1 and skinCount("Button") == 1 and skinCount("Checkbox") == 10 and skinCount("StateButtonLabel") == 0,
  ("queued widgets skinned once each (Tab %d, Button %d, Checkbox %d)"):format(skinCount("Tab"), skinCount("Button"), skinCount("Checkbox")))
local sawTab = false for _, c in ipairs(skinCalls) do if c[2] == rbtn and c[1] == "Tab" then sawTab = true end end
assert(sawTab, "the vendor restock button gets the window's tab look")
local function lastSel() for i = #skinCalls, 1, -1 do local c = skinCalls[i]; if c[1] == "SetTabSelection" and c[2] == rbtn then return c[3] end end end
assert(lastSel() ~= nil, "its active/inactive look is set")
local tabsBefore = skinCount("Tab")
money = 1; rev(nil, "MERCHANT_UPDATE")
assert(lastSel() == false and skinCount("Tab") == tabsBefore + 1, "disabled -> inactive tab look, label re-mirrored")
money = 100000; rev(nil, "MERCHANT_UPDATE"); assert(lastSel() == true, "clickable -> active tab look")
assert(ns.SkinActive() == true, "tab look reported active")
-- older EllesmereUI without S.Tab: falls back to a plain button + state label
local old = { Button = Sstub.Button, StateButtonLabel = Sstub.StateButtonLabel }; local savedSkin = ns.skin; ns.skin = old
local b0, l0, t0 = skinCount("Button"), skinCount("StateButtonLabel"), skinCount("Tab")
ns.Skin("TabButton", {}); assert(skinCount("Button") == b0 + 1 and skinCount("StateButtonLabel") == l0 + 1 and skinCount("Tab") == t0, "fallback without S.Tab")
assert(ns.SkinActive() == false); ns.Skin("TabState", {}, true)   -- no SetTabSelection: ignored
ns.skin = savedSkin
local nCalls = #skinCalls; ns.Skin("Button", {}); assert(#skinCalls == nCalls + 1, "widgets made later are skinned at once")
ns.Skin("DoesNotExist", {})                                   -- a primitive an older EllesmereUI lacks is ignored
Sstub.Button = function() error("boom") end; ns.Skin("Button", {})  -- and a failing skin never throws
local savedEUI = EllesmereUI; EllesmereUI = nil
local ns2 = { core = ns.core }; assert(loadfile(dir .. "/Panel.lua"))("Kibble", ns2); ns2.Skin("Button", {})
EllesmereUI = savedEUI
-- with the tab look active, a freshly made button takes the tab row's height (top+bottom anchored to the tab)
local n0 = #frames
local ns3 = { core = ns.core, Skin = function() end, SkinActive = function() return true end }
assert(loadfile(dir .. "/Restock.lua"))("Kibble", ns3)
local rev3 = frames[n0 + 1].st["script:OnEvent"]; rst.points = {}; rev3(nil, "MERCHANT_SHOW")
assert(hasPoint("TOPLEFT", MerchantFrameTab2, "TOPRIGHT") and hasPoint("BOTTOMLEFT", MerchantFrameTab2, "BOTTOMRIGHT") and hasPoint("RIGHT", MerchantFrame, "RIGHT"), "tab-look button: tab row height, filling to the window edge")
print("EllesmereUI skin OK")


-- ===== 1.4 profiles =====
local K, PR = ns.core, ns.Profiles
local function has(node, label) for _, k in ipairs(node.kids) do if k.label == label then return k end end end
for key in pairs(K.Defaults) do assert(PR.Covers(key), "export/import validates the setting: "..key) end

-- base64 + checksum against independently computed values
assert(PR.Encode("Man"):match("^KIBBLE1:TWFu:(%d+)$") == "56230247", "base64 + Adler-32 reference vector")
assert(PR.Encode("Ma"):match("^KIBBLE1:TWE=:") and PR.Encode("M"):match("^KIBBLE1:TQ==:"), "base64 padding")

-- storage and per-character assignment
local db = K.Account()
assert(K.ActiveProfile() == "Default" and db.profileKeys["Hunter-Realm"] == "Default" and db.minimapAngle ~= false, "this character starts on Default")

-- create / copy / names
local cfg = K.Settings(); cfg.size = 52; cfg.ignored[11] = true
assert(PR.Create("Raider") == "Raider" and db.profiles.Raider.size == 40 and next(db.profiles.Raider.ignored) == nil, "a new profile starts from the defaults")
assert(PR.Create("Default copy", "Default") and db.profiles["Default copy"].size == 52 and db.profiles["Default copy"].ignored[11], "a copy keeps settings and the ignore list")
db.profiles["Default copy"].ignored[11] = nil; assert(cfg.ignored[11], "the copy is independent of the original")
for _, bad in ipairs{ "", "   ", ("x"):rep(33), "bad|name", "raider", "RAIDER", "tab\there" } do
  local n, e = PR.Create(bad); assert(n == nil and e, "rejects the name '"..bad.."'")
end
assert(PR.Find("rAiDeR") == "Raider" and PR.Create("  Padded  ") == "Padded", "names are trimmed and matched ignoring case")

-- switching applies at once and is remembered for this character
assert(K.UseProfile("Raider") and K.Settings() == db.profiles.Raider and K.ActiveProfile() == "Raider" and bstore.size == 40, "switching applies the profile (button size "..tostring(bstore.size)..")")
assert(db.profileKeys["Hunter-Realm"] == "Raider" and K.UseProfile("nope") == false and K.ActiveProfile() == "Raider")

-- rename / delete / reset
assert(PR.Rename("Default", "x") == nil, "Default can't be renamed")
assert(PR.Rename("Raider", "Raid Night") == "Raid Night" and db.profiles.Raider == nil and K.ActiveProfile() == "Raid Night"
  and K.Settings() == db.profiles["Raid Night"] and db.profileKeys["Hunter-Realm"] == "Raid Night", "renaming the active profile keeps it active")
db.profileKeys["Other-Realm"] = "Raid Night"; PR.Rename("Raid Night", "Raiding"); assert(db.profileKeys["Other-Realm"] == "Raiding", "other characters follow a rename")
assert(PR.Delete("Raiding") == nil and PR.Delete("Default") == nil, "can't delete the active profile or Default")
K.UseProfile("Default")
assert(PR.Delete("Raiding") and db.profiles.Raiding == nil and db.profileKeys["Other-Realm"] == "Default", "deleting sends its characters back to Default")
cfg = K.Settings(); cfg.size = 64; cfg.ignored[12] = true; cfg.alertSound = true
assert(PR.Reset("Default") and K.Settings() == cfg and cfg.size == 40 and next(cfg.ignored) == nil and cfg.alertSound == false, "reset restores the defaults in place")

-- a different character loads its own profile
db.profiles.Alt = PR.NewProfile(); db.profiles.Alt.size = 64; db.profileKeys["Alt-Realm"] = "Alt"
local mainSlash = SlashCmdList.KIBBLE   -- extra copies of the addon below would replace the handler
playerName = "Alt"; local nsAlt = {}; local nFrames = #frames
assert(loadfile(path))("Kibble", nsAlt); frames[nFrames + 1].st["script:OnEvent"](nil, "ADDON_LOADED", "Kibble")
assert(nsAlt.core.ActiveProfile() == "Alt" and nsAlt.core.Settings().size == 64, "another character gets its own profile")
playerName = "Brand New"; nsAlt = {}; nFrames = #frames
assert(loadfile(path))("Kibble", nsAlt); frames[nFrames + 1].st["script:OnEvent"](nil, "ADDON_LOADED", "Kibble")
assert(nsAlt.core.ActiveProfile() == "Default" and db.profileKeys["Brand New-Realm"] == "Default", "a new character starts on Default")
playerName = "Hunter"; SlashCmdList.KIBBLE = mainSlash; K.UseProfile("Default")

-- export / import round trip with every setting changed
local alts = { throttle = 15, lowFood = 20, size = 64, opacity = 0.5, restockTarget = 120, foodMode = "best", visibility = "hidden", soundChoice = "TELL_MESSAGE" }
local all = PR.NewProfile()
for key, v in pairs(K.Defaults) do
  if type(v) == "boolean" then all[key] = not v elseif alts[key] ~= nil then all[key] = alts[key] else error("test needs a value for "..key) end
end
all.ignored = { [30] = true, [4] = true, [999] = true }
local str, cut = PR.Export(all)
assert(str:match("^KIBBLE1:[A-Za-z0-9+/=]+:%d+$") and not cut, "export string shape")
local back, skipped = PR.Import(str)
assert(back and skipped == 0, "import of an export is clean")
for key in pairs(K.Defaults) do assert(back[key] == all[key], "round trip: "..key) end
assert(back.ignored[4] and back.ignored[30] and back.ignored[999] and back.settingsVersion == 2, "ignore list and version survive")
assert(PR.Import(str:gsub(("."):rep(40), "%0\n  ")), "line-wrapped / indented strings still import")

-- hostile or damaged strings
local function refused(text, frag) local p, e = PR.Import(text); assert(p == nil and e and e:find(frag, 1, true), "refuses ("..frag..") :: "..tostring(e)) end
refused("", "nothing"); refused("hello world", "not a Kibble export")
refused(str:gsub(":%d+$", ":1"), "checksum")
refused(str:gsub("^(KIBBLE1:.)", function(c) return "KIBBLE1:" .. (c:sub(-1) == "A" and "B" or "A") end), "checksum")
refused("KIBBLE2:" .. str:match("^KIBBLE1:(.*)$"), "newer Kibble")
refused(PR.Encode("size=999\nfoodMode=evil"), "no settings")
refused(PR.Encode("just some words"), "no settings")
local messy, nSkipped = PR.Import(PR.Encode("size=52\nbogus=1\nfoodMode=evil\nalertSound=maybe\nsoundChoice=lower\nignored=5,abc,-3,99999999999,7"))
assert(messy and messy.size == 52 and messy.foodMode == "save" and messy.alertSound == false and messy.soundChoice == "RAID_WARNING", "invalid values fall back to defaults")
assert(messy.ignored[5] and messy.ignored[7] and not messy.ignored[-3] and nSkipped == 7, "bad ignore entries are skipped and counted: "..tostring(nSkipped))
assert(not PR.Import(PR.Encode("size=52")).ignored[1], "no ignore list is fine")
local many = PR.NewProfile(); for i = 1, 70 do many.ignored[i] = true end
local manyStr, manyCut = PR.Export(many); local manyBack = PR.Import(manyStr)
local manyN = 0; for _ in pairs(manyBack.ignored) do manyN = manyN + 1 end
assert(manyCut and manyN == 60, "the ignore list is capped in exports (" .. manyN .. ")")
-- a hand-made string with a huge ignore list is capped on import too
local ids = {}; for i = 1, 500 do ids[i] = tostring(i) end
local huge, hugeSkipped = PR.Import(PR.Encode("ignored=" .. table.concat(ids, ",")))
local hugeN = 0; for _ in pairs(huge.ignored) do hugeN = hugeN + 1 end
assert(hugeN == 60 and hugeSkipped == 440, "import caps the ignore list at 60 (" .. hugeN .. ", skipped " .. hugeSkipped .. ")")
local lua = PR.Encode("size=52\nignored=1\n') os.exit(1) --")  -- nothing in an import is ever executed
assert(PR.Import(lua), "junk lines are skipped, never run")

-- importing creates a new profile, switches to it and keeps an explicit opt-in to sound
local before = K.ActiveProfile()
local nm, info, prev = PR.ImportAndUse(str)
assert(nm == "Imported" and info == 0 and prev == before and K.ActiveProfile() == "Imported" and K.Settings().alertSound == true, "import creates + switches (alertSound kept)")
assert(PR.ImportAndUse(str) == "Imported 2" and PR.ImportAndUse(str, "Mine") == "Mine", "unique names for imports")
local nProfiles = #PR.Names(); local fail, why = PR.ImportAndUse("garbage")
assert(fail == nil and why and #PR.Names() == nProfiles, "a failed import creates nothing")
K.UseProfile("Default")

-- dialogs
ns.ShowExport(); local dlg = frames[dialogIndex].p
assert(dlg.spec.readOnly and dlg.spec.input == "multi", "export dialog is a read-only text box")
local fromDialog = PR.Import(dlg.spec.value); for key in pairs(K.Defaults) do assert(fromDialog[key] == K.Settings()[key], "dialog exports the active profile: "..key) end
chatlog = {}; ns.ShowImport(); frames[dialogIndex].p.spec.onOK("garbage"); assert(chatlog[#chatlog]:find("import failed"), "import dialog reports a bad string")
frames[dialogIndex + 2].st.text = str; frames[dialogIndex + 3].st["script:OnClick"]()    -- type into the box, press Import
assert(K.ActiveProfile():find("^Imported") and chatlog[#chatlog]:find("imported as profile"), "pressing Import uses the typed text: "..tostring(chatlog[#chatlog]))
K.UseProfile("Default")

-- the menu
menuRoot = nil; K.OpenMenu(); local pm = has(menuRoot, "Profiles")
assert(pm, "Profiles submenu exists")
local radios = {} for _, k in ipairs(pm.kids) do if k.kind == "radio" then radios[#radios + 1] = k.label end end
assert(table.concat(radios, ",") == table.concat(PR.Names(), ","), "one radio per profile")
has(pm, "Mine").set(); assert(K.ActiveProfile() == "Mine", "picking a profile switches to it")
menuRoot = nil; K.OpenMenu(); pm = has(menuRoot, "Profiles")   -- picking closes the menu; the next open is rebuilt
assert(has(pm, "Rename this profile..."), "rename is offered for a normal profile")
has(pm, "New profile...").fn(); assert(frames[dialogIndex].p.spec.input == "line", "new profile asks for a name")
frames[dialogIndex].p.spec.onOK("Fresh"); assert(K.ActiveProfile() == "Fresh" and K.Settings().size == 40, "a new profile is created and used")
has(pm, "Copy this profile...").fn(); assert(frames[dialogIndex].p.spec.value == "Fresh copy")
frames[dialogIndex].p.spec.onOK("Fresh2"); assert(K.ActiveProfile() == "Fresh2")
has(pm, "Rename this profile...").fn(); frames[dialogIndex].p.spec.onOK("Renamed"); assert(K.ActiveProfile() == "Renamed")
has(pm, "Reset this profile").fn(); local confirmSpec = frames[dialogIndex].p.spec
assert(confirmSpec.input == nil and confirmSpec.cancelText == (NO or "No"), "reset asks first"); K.Settings().size = 64; confirmSpec.onOK(); assert(K.Settings().size == 40, "confirming resets")
menuRoot = nil; K.OpenMenu(); pm = has(menuRoot, "Profiles")
local del = has(pm, "Delete a profile"); assert(del and not has(del, "Renamed") and not has(del, "Default") and has(del, "Mine"), "delete lists other profiles, never the active one or Default")
has(del, "Mine").fn(); frames[dialogIndex].p.spec.onOK(); assert(not PR.Find("Mine"), "confirming deletes")
K.UseProfile("Default"); menuRoot = nil; K.OpenMenu(); assert(not has(has(menuRoot, "Profiles"), "Rename this profile..."), "Default can't be renamed from the menu")

-- slash commands
chatlog = {}; SlashCmdList.KIBBLE("profile"); assert(chatlog[#chatlog]:find("profiles: ") and chatlog[#chatlog]:find('uses "Default"'), "/kibble profile lists them")
SlashCmdList.KIBBLE("profile renamed"); assert(K.ActiveProfile() == "Renamed" and chatlog[#chatlog]:find("now using"), "/kibble profile <name> switches (any case)")
SlashCmdList.KIBBLE("profile nope"); assert(K.ActiveProfile() == "Renamed" and chatlog[#chatlog]:find("no profile called"))
SlashCmdList.KIBBLE("export"); assert(frames[dialogIndex].p.spec.title == "Export profile"); SlashCmdList.KIBBLE("import"); assert(frames[dialogIndex].p.spec.title == "Import profile")
K.UseProfile("Default")
print("profiles OK")

-- sound-off migration (settings saved by 1.1.0 had alertSound = true as the old default)
local c2 = assert(loadfile(arg[1] or "Kibble.lua"))
KibbleDB = { settings = { alertSound = true, size = 52, minimapAngle = 1.5 } }; FeedMeDB = nil; c2("Kibble")
frames[1].st["script:OnEvent"](nil, "ADDON_LOADED", "Kibble")
assert(KibbleDB.settings == nil and KibbleDB.minimapAngle == 1.5 and KibbleDB.profiles.Default.minimapAngle == nil, "legacy flat settings become the Default profile; the minimap angle moves to the account")
assert(KibbleDB.profiles.Default.alertSound == false and KibbleDB.profiles.Default.size == 52 and KibbleDB.profiles.Default.settingsVersion == 2, "1.1.0 'sound on' reset once, other settings kept")
KibbleDB.profiles.Default.alertSound = true; c2("Kibble"); frames[1].st["script:OnEvent"](nil, "ADDON_LOADED", "Kibble")
assert(KibbleDB.profiles.Default.alertSound == true, "a deliberate opt-in survives later loads")
print("sound migration OK")

print("slash:")
local chat = {}; DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) chat[#chat+1] = m end }
SlashCmdList.KIBBLE("buffs"); assert(chat[#chat]:find("no buffs"), "buffs: empty list message")
petAuras[1] = { name = "Feed Pet Effect", spellId = 1539, duration = 10 }; SlashCmdList.KIBBLE("buffs")
assert(chat[#chat]:find("Feed Pet Effect") and chat[#chat]:find("1539"), "buffs: lists name and spell id")
SlashCmdList.KIBBLE("config"); assert(menuRoot); SlashCmdList.KIBBLE("")
print("ALL OK")
