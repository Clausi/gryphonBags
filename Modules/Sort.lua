local _, ns = ...
local L = ns.L
local Sort = ns:RegisterModule("Sort")

-- Own sort method for "Clean Up Bags", turned on in the options (ns.charDb.ownSort). Unlike
-- C_Container.SortBags() it only moves the items of slots that are not reserved, so the reserved
-- slots need no restore afterwards. It follows Blizzard's bag settings:
-- - Bags with "Ignore this bag" for the cleanup are left alone (C_Container.GetBackpackAutosortDisabled,
--   Enum.BagSlotFlags.DisableAutoSort).
-- - Bags with an assigned item type (equipment, consumables, ...) get the items of that type first.
-- - Profession bags and the reagent bag only get the items they can hold, and get them first. On
--   Forever a profession bag can also sit in the reagent bag slot; it then counts as a profession bag.
-- A button over Blizzard's sort button takes the clicks while the option is on, so Blizzard's
-- button and its script stay untouched. The "Clean Up Bags" entry of the gamepad menu has no button
-- to cover and still uses Blizzard's sort.
-- The sort runs in steps, one move each: moved items stay locked until the server confirms.
-- 1. Partial stacks of the same item are merged.
-- 2. The target layout is planned once: each target slot gets an item (link and stack size).
-- 3. The target slots are filled in order, each by swapping the wanted item into it. Once all items
--    are in their target slots, the other slots are empty.

-- Seconds between two steps.
local STEP_DELAY = 0.2
-- Steps to wait for one move (e.g. for locked items or an item on the cursor) before giving up.
local MAX_ATTEMPTS = 50

local BUTTON_HIGHLIGHT = "Interface\\Buttons\\ButtonHilight-Square"

-- Item classes in sort order. Classes that are not listed (or do not exist) come after them.
local CLASS_ORDER = {
    "Consumable", "Weapon", "Armor", "Gem", "ItemEnhancement", "Recipe", "Tradegoods", "Reagent",
    "Profession", "Container", "Quiver", "Projectile", "Questitem", "Key", "Glyph", "Battlepet",
    "Miscellaneous",
}
local classRank = {}
for rank, name in ipairs(CLASS_ORDER) do
    local classID = Enum.ItemClass[name]
    if classID then
        classRank[classID] = rank
    end
end
local UNLISTED_RANK = #CLASS_ORDER + 1

local function IsClass(item, ...)
    for i = 1, select("#", ...) do
        local classID = Enum.ItemClass[select(i, ...)]
        if classID and item.classID == classID then
            return true
        end
    end
    return false
end

-- The item types a bag can be assigned to in Blizzard's bag menu, with the items they stand for.
local FILTER_MATCHES = {
    ClassEquipment = function(item)
        return IsClass(item, "Weapon", "Armor")
    end,
    ClassConsumables = function(item)
        return IsClass(item, "Consumable")
    end,
    ClassProfessionGoods = function(item)
        return IsClass(item, "Tradegoods", "Recipe", "Gem", "ItemEnhancement", "Profession")
    end,
    ClassJunk = function(item)
        return item.quality == Enum.ItemQuality.Poor
    end,
    ClassQuestItems = function(item)
        return IsClass(item, "Questitem")
    end,
    ClassReagents = function(item)
        return item.isReagent or IsClass(item, "Reagent")
    end,
}
local filters = {}
for name, matches in pairs(FILTER_MATCHES) do
    local flag = Enum.BagSlotFlags[name]
    if flag then
        filters[#filters + 1] = { flag = flag, matches = matches }
    end
end

local button

-- "merge", "place" or nil while no sort is running.
local phase
-- The planned layout: { bagID, slot, key } in the order the slots are filled.
local targets
local targetIndex = 0
-- The sorted bags by bag ID, from the plan.
local bagsByID
-- Slots that already hold their item ("bagID:slot" = true).
local finished
-- Merges that were tried ("from>to#counts" = true), so stacks that do not merge are not tried again.
local triedMerges
-- Moves done for the current target slot ("from>to" = true), to notice moves the server refused.
local triedMoves
-- True if a slot could not be filled.
local incomplete = false
local attempts = 0
local timer

local function SlotKey(bagID, slot)
    return bagID .. ":" .. slot
end

local function IsSortDisabled(bagID)
    if bagID == Enum.BagIndex.Backpack then
        return C_Container.GetBackpackAutosortDisabled()
    end
    return C_Container.GetBagSlotFlag(bagID, Enum.BagSlotFlags.DisableAutoSort)
end

-- What a bag can hold (bit mask, 0 for a normal bag), and whether it is a profession bag (e.g. the
-- Herb Pouch). The family of the container may be missing, so the bag item itself is asked as well.
local function GetBagFamily(bagID)
    local _, family = C_Container.GetContainerNumFreeSlots(bagID)
    if bagID == Enum.BagIndex.Backpack then
        return 0, false
    end
    family = family or 0
    local inventoryID = C_Container.ContainerIDToInventoryID(bagID)
    if family == 0 then
        local bagItemID = GetInventoryItemID("player", inventoryID)
        family = bagItemID and C_Item.GetItemFamily(bagItemID) or 0
    end
    return family, family ~= 0 or IsInventoryItemProfessionBag("player", inventoryID) == true
end

-- The bags the sort may use, in bag order, each with its slots that are not reserved.
local function GetBags()
    local ReservedSlots = ns.modules.ReservedSlots
    local bags = {}
    for bagID = Enum.BagIndex.Backpack, NUM_TOTAL_BAG_FRAMES do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        if numSlots > 0 and not IsSortDisabled(bagID) then
            -- On Forever the reagent bag slot also takes profession bags (e.g. the Herb Pouch), which
            -- only hold their own family.
            local family, isProfessionBag = GetBagFamily(bagID)
            local isReagentBag = bagID > NUM_BAG_FRAMES and not isProfessionBag
            local bag = {
                id = bagID,
                isReagentBag = isReagentBag,
                isProfessionBag = isProfessionBag,
                family = family,
                filters = {},
                slots = {},
                nextSlot = 1,
            }
            ns:Debug("Sort: bag %d, family %d, profession bag %s, reagent bag %s", bagID, family,
                tostring(isProfessionBag), tostring(isReagentBag))
            -- Blizzard's bag menu only offers the item types for normal bags.
            if bagID ~= Enum.BagIndex.Backpack and not isReagentBag and not isProfessionBag then
                for _, filter in ipairs(filters) do
                    if C_Container.GetBagSlotFlag(bagID, filter.flag) then
                        bag.filters[#bag.filters + 1] = filter
                    end
                end
            end
            for slot = 1, numSlots do
                if not ReservedSlots:IsReserved(bagID, slot) then
                    bag.slots[#bag.slots + 1] = slot
                end
            end
            bags[#bags + 1] = bag
        end
    end
    return bags
end

local function IsSpecialBag(bag)
    return bag.isReagentBag or bag.isProfessionBag
end

-- An item that lies in a special bag fits there, whatever the item family says.
local function CanHold(bag, item)
    if not IsSpecialBag(bag) or item.bagID == bag.id then
        return true
    end
    if bag.isReagentBag then
        return item.isReagent
    end
    return bit.band(item.family, bag.family) ~= 0
end

local function MatchesFilter(bag, item)
    for _, filter in ipairs(bag.filters) do
        if filter.matches(item) then
            return true
        end
    end
    return false
end

-- Items with the same key are interchangeable for the sort.
local function ItemKey(info)
    return info.hyperlink .. "#" .. info.stackCount
end

local function ReadItem(bagID, slot)
    local info = C_Container.GetContainerItemInfo(bagID, slot)
    if not info then
        return nil
    end
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(info.itemID)
    -- Nil while the item is not cached; it is then not taken for the reagent bag.
    local isReagent = select(17, C_Item.GetItemInfo(info.itemID))
    return {
        bagID = bagID,
        itemID = info.itemID,
        link = info.hyperlink,
        count = info.stackCount,
        quality = info.quality or 0,
        name = info.itemName or "",
        classID = classID,
        subClassID = subClassID or 0,
        isReagent = isReagent == true,
        family = ns.GetItemBagFamily(info.itemID),
        key = ItemKey(info),
    }
end

-- Junk last, then by item class, subclass, quality (best first), name and stack size (largest first).
local function SortOrder(a, b)
    local junkA, junkB = a.quality == Enum.ItemQuality.Poor, b.quality == Enum.ItemQuality.Poor
    if junkA ~= junkB then
        return junkB
    end
    local rankA, rankB = classRank[a.classID] or UNLISTED_RANK, classRank[b.classID] or UNLISTED_RANK
    if rankA ~= rankB then
        return rankA < rankB
    end
    if a.subClassID ~= b.subClassID then
        return a.subClassID < b.subClassID
    end
    if a.quality ~= b.quality then
        return a.quality > b.quality
    end
    if a.name ~= b.name then
        return a.name < b.name
    end
    if a.itemID ~= b.itemID then
        return a.itemID < b.itemID
    end
    if a.link ~= b.link then
        return a.link < b.link
    end
    return a.count > b.count
end

-- The target layout, or nil if not every item has a place.
local function Plan(bags)
    local items = {}
    for _, bag in ipairs(bags) do
        for _, slot in ipairs(bag.slots) do
            local item = ReadItem(bag.id, slot)
            if item then
                items[#items + 1] = item
            end
        end
    end
    table.sort(items, SortOrder)

    local placed = {}
    local layout = {}
    local placedCount = 0
    local function Fill(bag, accepts)
        for _, item in ipairs(items) do
            if bag.nextSlot > #bag.slots then
                return
            end
            if not placed[item] and CanHold(bag, item) and (not accepts or accepts(bag, item)) then
                placed[item] = true
                placedCount = placedCount + 1
                layout[#layout + 1] = { bagID = bag.id, slot = bag.slots[bag.nextSlot], key = item.key }
                bag.nextSlot = bag.nextSlot + 1
            end
        end
    end

    -- Profession bags and the reagent bag first, then bags with an item type, then the other bags,
    -- and what is left goes into the free slots of the bags with an item type.
    for _, bag in ipairs(bags) do
        if IsSpecialBag(bag) then
            Fill(bag)
        end
    end
    for _, bag in ipairs(bags) do
        if #bag.filters > 0 then
            Fill(bag, MatchesFilter)
        end
    end
    for _, bag in ipairs(bags) do
        if not IsSpecialBag(bag) and #bag.filters == 0 then
            Fill(bag)
        end
    end
    for _, bag in ipairs(bags) do
        if #bag.filters > 0 then
            Fill(bag)
        end
    end

    if placedCount < #items then
        return nil
    end
    return layout
end

-- Calls fn(bag, slot) for every slot of the sorted bags until it returns true.
local function FindSlot(fn)
    for _, bag in pairs(bagsByID) do
        for _, slot in ipairs(bag.slots) do
            if fn(bag, slot) then
                return bag, slot
            end
        end
    end
end

-- Two partial stacks of the same item that were not tried in this state yet: the later one is moved
-- onto the earlier one. Returns the merge key for triedMerges first.
local function FindMerge()
    local partial = {}
    for bagID = Enum.BagIndex.Backpack, NUM_TOTAL_BAG_FRAMES do
        local bag = bagsByID[bagID]
        if bag then
            for _, slot in ipairs(bag.slots) do
                local info = C_Container.GetContainerItemInfo(bagID, slot)
                local maxStack = info and C_Item.GetItemMaxStackSizeByID(info.itemID)
                if maxStack and maxStack > 1 and info.stackCount < maxStack then
                    local first = partial[info.hyperlink]
                    if first then
                        local merge = SlotKey(bagID, slot) .. ">" .. SlotKey(first.bagID, first.slot)
                            .. "#" .. info.stackCount .. "/" .. first.count
                        if not triedMerges[merge] then
                            return merge, bagID, slot, first.bagID, first.slot
                        end
                    else
                        partial[info.hyperlink] = { bagID = bagID, slot = slot, count = info.stackCount }
                    end
                end
            end
        end
    end
end

local function CurrentKey(bagID, slot)
    local info = C_Container.GetContainerItemInfo(bagID, slot)
    return info and ItemKey(info)
end

-- The move that brings the wanted item into the target slot, or nothing if it is not there anymore
-- (e.g. used during the sort).
local function GetPlaceMove(target)
    local function IsOpen(bag, slot)
        return not finished[SlotKey(bag.id, slot)] and not (bag.id == target.bagID and slot == target.slot)
    end
    local sourceBag, sourceSlot = FindSlot(function(bag, slot)
        return IsOpen(bag, slot) and CurrentKey(bag.id, slot) == target.key
    end)
    if not sourceBag then
        return nil
    end
    -- A swap puts the item of the target slot into the source slot. If that bag cannot hold it, the
    -- item first goes to a free slot that can. Without one the slot stays as it is: the game would
    -- refuse the swap ("Only herbs can be placed in that").
    local current = ReadItem(target.bagID, target.slot)
    if current and not CanHold(sourceBag, current) then
        local freeBag, freeSlot = FindSlot(function(bag, slot)
            return IsOpen(bag, slot) and CanHold(bag, current) and not C_Container.HasContainerItem(bag.id, slot)
        end)
        if freeBag then
            return target.bagID, target.slot, freeBag.id, freeSlot
        end
        incomplete = true
        ns:Debug("Sort: no room for %s outside bag %d", current.link, sourceBag.id)
        return nil
    end
    return sourceBag.id, sourceSlot, target.bagID, target.slot
end

local function IsSlotLocked(bagID, slot)
    local info = C_Container.GetContainerItemInfo(bagID, slot)
    return info ~= nil and info.isLocked
end

-- Moves an item onto a slot: swaps it with another item, or merges it into a stack of the same item.
local function MoveItem(fromBag, fromSlot, toBag, toSlot)
    C_Container.PickupContainerItem(fromBag, fromSlot)
    C_Container.PickupContainerItem(toBag, toSlot)
    -- What the target did not take goes back instead of staying on the cursor.
    if CursorHasItem() then
        ClearCursor()
    end
end

local function Stop()
    if timer then
        timer:Cancel()
        timer = nil
    end
    phase = nil
    targets = nil
    bagsByID = nil
    finished = nil
    triedMerges = nil
    triedMoves = nil
    incomplete = false
    attempts = 0
    ns.Progress:Hide()
end

local Step

local function ScheduleStep()
    if timer then
        timer:Cancel()
    end
    timer = C_Timer.NewTimer(STEP_DELAY, Step)
end

-- Moves the item unless one of the slots is still locked from the last move, and waits for the next
-- step either way. Returns true if the item was moved.
local function TryMove(fromBag, fromSlot, toBag, toSlot)
    ScheduleStep()
    if IsSlotLocked(fromBag, fromSlot) or IsSlotLocked(toBag, toSlot) then
        return false
    end
    MoveItem(fromBag, fromSlot, toBag, toSlot)
    return true
end

local function StartPlacing()
    -- Read again: the bag settings or reserved slots may have changed while stacking.
    local bags = GetBags()
    targets = Plan(bags)
    bagsByID = {}
    for _, bag in ipairs(bags) do
        bagsByID[bag.id] = bag
    end
    if not targets then
        Stop()
        ns:Notify(L["SORT_FAILED"])
        return false
    end
    phase = "place"
    targetIndex = 1
    finished = {}
    triedMoves = {}
    incomplete = false
    return true
end

function Step()
    timer = nil
    attempts = attempts + 1
    if attempts > MAX_ATTEMPTS then
        Stop()
        ns:Notify(L["SORT_FAILED"])
        return
    end

    -- Never touches an item the player is holding.
    if CursorHasItem() then
        ScheduleStep()
        return
    end

    if phase == "merge" then
        local merge, fromBag, fromSlot, toBag, toSlot = FindMerge()
        if merge then
            -- Each merge is done once per stack sizes, so stacks that do not merge are not tried again.
            if TryMove(fromBag, fromSlot, toBag, toSlot) then
                triedMerges[merge] = true
                attempts = 0
            end
            return
        end
        -- The last merge may still be in progress; the plan needs the final stacks.
        if FindSlot(function(bag, slot)
            return IsSlotLocked(bag.id, slot)
        end) then
            ScheduleStep()
            return
        end
        if not StartPlacing() then
            return
        end
        attempts = 0
    end

    while targets[targetIndex] do
        local target = targets[targetIndex]
        ns.Progress:Set(L["SORT_PROGRESS"]:format(targetIndex - 1, #targets), targetIndex - 1, #targets)
        if CurrentKey(target.bagID, target.slot) ~= target.key then
            local fromBag, fromSlot, toBag, toSlot = GetPlaceMove(target)
            if fromBag then
                local move = SlotKey(fromBag, fromSlot) .. ">" .. SlotKey(toBag, toSlot)
                local locked = IsSlotLocked(fromBag, fromSlot) or IsSlotLocked(toBag, toSlot)
                -- The same move again, with nothing locked anymore: the server refused it (e.g. the bag
                -- cannot hold the item). The slot is left as it is instead of trying again.
                if not (triedMoves[move] and not locked) then
                    if TryMove(fromBag, fromSlot, toBag, toSlot) then
                        triedMoves[move] = true
                    end
                    return
                end
                incomplete = true
                ns:Debug("Sort: move %s refused (%s)", move,
                    C_Container.GetContainerItemLink(fromBag, fromSlot) or "?")
            end
        end
        finished[SlotKey(target.bagID, target.slot)] = true
        targetIndex = targetIndex + 1
        triedMoves = {}
        attempts = 0
    end
    local wasIncomplete = incomplete
    Stop()
    if wasIncomplete then
        ns:Notify(L["SORT_FAILED"])
    end
end

function Sort:Start()
    -- A second click keeps the running sort.
    if phase then
        return
    end
    bagsByID = {}
    for _, bag in ipairs(GetBags()) do
        bagsByID[bag.id] = bag
    end
    phase = "merge"
    triedMerges = {}
    attempts = 0
    ns.Progress:Pulse(L["SORT_PROGRESS_STACKING"])
    ScheduleStep()
end

-- Shows the own sort button while the option is on. Turning the option off stops a running sort.
function Sort:Update()
    button:SetShown(ns.charDb.ownSort)
    if not ns.charDb.ownSort and phase then
        Stop()
    end
end

local function OnButtonEnter(self)
    GameTooltip:SetOwner(self)
    GameTooltip_SetTitle(GameTooltip, BAG_CLEANUP_BAGS, HIGHLIGHT_FONT_COLOR)
    GameTooltip_AddNormalLine(GameTooltip, BAG_CLEANUP_BAGS_DESCRIPTION)
    GameTooltip_AddNormalLine(GameTooltip, L["SORT_HINT"])
    GameTooltip_AddNormalLine(GameTooltip, L["RESERVED_HINT"])
    GameTooltip:Show()
end

-- Same look as Blizzard's button (BagItemAutoSortButton in ContainerFrame.xml), as its child, so it
-- follows the button between the bag frames and hides with it.
local function CreateButton()
    button = CreateFrame("Button", nil, BagItemAutoSortButton)
    button:SetAllPoints()
    button:SetNormalAtlas("bags-button-autosort-up")
    button:SetPushedAtlas("bags-button-autosort-down")
    button:SetHighlightTexture(BUTTON_HIGHLIGHT, "ADD")
    local highlight = button:GetHighlightTexture()
    highlight:ClearAllPoints()
    highlight:SetSize(24, 23)
    highlight:SetPoint("CENTER")
    button:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
        Sort:Start()
    end)
    button:SetScript("OnEnter", OnButtonEnter)
    button:SetScript("OnLeave", GameTooltip_Hide)
end

function Sort:OnEnable()
    CreateButton()
    self:Update()
end
