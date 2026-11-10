-- Kibble: vendor restock.
--
-- At a vendor that sells food your pet eats, a button under the merchant window buys up to your
-- target count (right-click Kibble > Food > Vendor restock) of the food Kibble would pick.
-- Nothing is bought until you click it.
--
-- Buying follows how BuyMerchantItem works: the quantity is a number of items in whole-bundle
-- multiples, at most GetMerchantItemMaxStack per purchase, and the next purchase is only sent
-- once the bags show the previous one.

local ADDON, ns = ...
local K = ns.core
if not K then return end -- not a hunter: Kibble.lua never exported anything

local floor, min, max = math.floor, math.min, math.max
local NUM_BAGS = NUM_BAG_SLOTS or 4

local button      -- created on first use, parented to the merchant window
local job         -- the purchase run in progress
local UpdateButton

local function CoinText(copper)
	if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
		return C_CurrencyInfo.GetCoinTextureString(copper)
	end
	return GetCoinTextureString and GetCoinTextureString(copper) or tostring(copper)
end

-- { [itemID] = merchantIndex } for foods the pet eats that cost plain gold and aren't ignored
local function VendorFoods()
	local found = {}
	local ignored = K.Settings().ignored
	for i = 1, GetMerchantNumItems() do
		local itemID = GetMerchantItemID(i)
		if itemID and not ignored[itemID] and K.PetCanEat(itemID) then
			local info = C_MerchantFrame.GetItemInfo(i)
			if info and not info.hasExtendedCost and not info.currencyID then
				found[itemID] = i
			end
		end
	end
	return found
end

-- How many more of this item the bags can take: free slots in general bags plus room in
-- partial stacks.
local function BagRoom(itemID, stackSize)
	local room = 0
	for bag = 0, NUM_BAGS do
		local free, family = C_Container.GetContainerNumFreeSlots(bag)
		if free and (family == nil or family == 0) then room = room + free * stackSize end
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID == itemID then
				room = room + max(stackSize - (info.stackCount or 1), 0)
			end
		end
	end
	return room
end

-- What clicking the button would do right now, or nil when the vendor has nothing to offer.
-- Returns { itemID, index, step, chunk, have, qty, cost, reason }; reason is set when qty is 0.
local function Plan()
	if not K.PetIsOut() then return nil end
	if MerchantFrame and (MerchantFrame.selectedTab or 1) ~= 1 then return nil end -- not the buyback tab

	local foods = VendorFoods()
	-- pick among the foods you can pay for; if you can't afford any, rank them all so the button
	-- can still say why
	local money = GetMoney()
	local affordable = {}
	for id, index in pairs(foods) do
		local info = C_MerchantFrame.GetItemInfo(index)
		if info and (info.price or 0) <= money then affordable[id] = index end
	end
	if next(affordable) then foods = affordable end
	local counts = {}
	for itemID in pairs(foods) do counts[itemID] = C_Item.GetItemCount(itemID) end
	local itemID = K.ChooseFood(counts)
	if not itemID then return nil end

	local index = foods[itemID]
	local info = C_MerchantFrame.GetItemInfo(index)
	local step = max(info.stackCount or 1, 1)
	local maxStack = GetMerchantItemMaxStack(index) or step
	local itemStack = C_Item.GetItemMaxStackSizeByID(itemID) or maxStack
	local have = counts[itemID]
	local plan = {
		itemID = itemID, index = index, step = step, have = have, qty = 0, cost = 0,
		chunk = max(floor(maxStack / step) * step, step),
	}

	local want = K.Settings().restockTarget - have
	if want <= 0 then plan.reason = "stocked"; return plan end
	local wantBundles = math.ceil(want / step)
	local fit = floor(min(BagRoom(itemID, itemStack), 999999) / step)
	local afford = (info.price or 0) > 0 and floor(GetMoney() / info.price) or math.huge
	local stock = (info.numAvailable and info.numAvailable >= 0) and info.numAvailable or math.huge
	local bundles = min(wantBundles, fit, afford, stock)
	if bundles <= 0 then
		plan.reason = (fit <= 0 and "bags") or (afford <= 0 and "gold") or "stock"
		return plan
	end
	plan.qty = bundles * step
	plan.cost = bundles * (info.price or 0)
	return plan
end

---------------------------------------------------------------------------
-- Buying
---------------------------------------------------------------------------

local ev = CreateFrame("Frame")

local function SyncEvents()
	if job then
		pcall(ev.RegisterEvent, ev, "UI_ERROR_MESSAGE") -- full bags, not enough gold, ...
	else
		pcall(ev.UnregisterEvent, ev, "UI_ERROR_MESSAGE")
	end
end

local function StopJob()
	local j = job
	job = nil
	SyncEvents()
	if j then
		local got = C_Item.GetItemCount(j.itemID) - j.base
		if got >= j.target then
			K.Print(("bought %d x %s."):format(got, K.ItemName(j.itemID)))
		else
			K.Print(("restock stopped after %d of %d."):format(max(got, 0), j.target))
		end
	end
	UpdateButton()
end

-- Sends the next purchase once the bags show the last one; stops at the target, when the count
-- drops (something else used the food), or when the vendor no longer sells it.
local function StepJob()
	local j = job
	if not j then return end
	local count = C_Item.GetItemCount(j.itemID)
	if count < j.last then StopJob(); return end
	j.last = count
	local got = count - j.base
	if got < j.issued then return end -- the previous purchase has not arrived yet
	local n = floor(min(j.chunk, j.target - got) / j.step) * j.step
	if n <= 0 or GetMerchantItemID(j.index) ~= j.itemID then StopJob(); return end
	j.issued = got + n
	BuyMerchantItem(j.index, n)
end

local function StartJob(plan)
	local base = C_Item.GetItemCount(plan.itemID)
	job = {
		index = plan.index, itemID = plan.itemID, target = plan.qty, step = plan.step,
		chunk = plan.chunk, base = base, last = base, issued = 0,
	}
	SyncEvents()
	StepJob()
	UpdateButton()
end

---------------------------------------------------------------------------
-- The button
---------------------------------------------------------------------------

local REASONS = {
	stocked = "Pet food stocked (%d)",
	bags = "Bags are full",
	gold = "Can't afford pet food",
	stock = "Vendor is out of stock",
}

local function CreateButton()
	local b = CreateFrame("Button", "KibbleRestockButton", MerchantFrame, "UIPanelButtonTemplate")
	-- Under the window's bottom-right corner: the Merchant / Buyback tabs sit under the bottom-left,
	-- so a left-anchored button would be hidden behind them. 200 wide keeps clear of the tabs.
	b:SetSize(200, 24)
	b:SetPoint("TOPRIGHT", MerchantFrame, "BOTTOMRIGHT", -10, 2)
	b:SetScript("OnClick", function()
		if job then return end
		local plan = Plan()
		if plan and plan.qty > 0 then StartJob(plan) end
	end)
	b:SetScript("OnEnter", function(self)
		local plan = Plan()
		if not plan then return end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetItemByID(plan.itemID)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(("You have %d. Target: %d (Kibble > Food)."):format(plan.have, K.Settings().restockTarget), 0.7, 0.7, 0.7)
		if plan.qty > 0 then
			GameTooltip:AddLine("Cost: " .. CoinText(plan.cost), 1, 1, 1)
		end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", GameTooltip_Hide)
	ns.Skin("Button", b)
	ns.Skin("StateButtonLabel", b) -- white when enabled, grey when disabled
	return b
end

function UpdateButton()
	if not (MerchantFrame and MerchantFrame:IsShown()) then
		if button then button:Hide() end
		return
	end
	local plan = Plan()
	if not plan then
		if button then button:Hide() end
		return
	end
	button = button or CreateButton()
	button:Show()
	if job then
		button:SetText("Restocking...")
		button:Disable()
	elseif plan.qty > 0 then
		button:SetText(("Restock pet food (buy %d)"):format(plan.qty))
		button:Enable()
	else
		button:SetText((REASONS[plan.reason] or "Nothing to buy"):format(plan.have))
		button:Disable()
	end
end

ns.UpdateRestock = UpdateButton

-- /kibble vendor: explains why the restock button is (not) showing for the open vendor.
function ns.VendorDiag()
	local P = K.Print
	P(("merchant window shown: %s, tab: %s | pet out: %s"):format(
		tostring(MerchantFrame and MerchantFrame:IsShown()), tostring(MerchantFrame and MerchantFrame.selectedTab),
		tostring(K.PetIsOut())))
	local n = GetMerchantNumItems() or 0
	local unloaded, edible = 0, 0
	for i = 1, n do
		local id = GetMerchantItemID(i)
		if id then
			if not (C_Item.GetItemInfo(id)) then unloaded = unloaded + 1 end
			local live = C_PetInfo and C_PetInfo.CanPetEatItem and C_PetInfo.CanPetEatItem(id)
			local cached = K.PeekCanEat(id)
			if live or cached then
				edible = edible + 1
				local info = C_MerchantFrame.GetItemInfo(i)
				P(("  #%d %s | pet can eat now: %s, cached answer: %s | token cost: %s, ignored: %s"):format(
					i, K.ItemName(id), tostring(live), tostring(cached),
					tostring(info and info.hasExtendedCost and true or false), tostring(K.Settings().ignored[id] == true)))
			end
		end
	end
	P(("%d items for sale, %d edible by your pet, %d with item data not loaded yet"):format(n, edible, unloaded))
	local plan = Plan()
	if plan then
		P(("plan: buy %d (have %d, reason when 0: %s)"):format(plan.qty, plan.have, tostring(plan.reason)))
	else
		P("plan: none, so the button is hidden")
	end
	P(("button created: %s, shown: %s"):format(tostring(button ~= nil), tostring(button and button:IsShown() or false)))
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

ev:SetScript("OnEvent", function(_, event)
	if event == "MERCHANT_CLOSED" then
		if job then StopJob() end
		if button then button:Hide() end
	elseif event == "UI_ERROR_MESSAGE" then
		if job then StopJob() end
	elseif event == "BAG_UPDATE_DELAYED" then
		StepJob()
		UpdateButton()
	else -- MERCHANT_SHOW / MERCHANT_UPDATE / UNIT_PET
		UpdateButton()
	end
end)

for _, e in ipairs({ "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED", "BAG_UPDATE_DELAYED" }) do
	pcall(ev.RegisterEvent, ev, e)
end
pcall(ev.RegisterUnitEvent, ev, "UNIT_PET", "player")
