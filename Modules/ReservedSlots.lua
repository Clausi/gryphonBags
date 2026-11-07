local _, ns = ...
local L = ns.L
local ReservedSlots = ns:RegisterModule("ReservedSlots")

-- Reserved bag slots keep their content when "Clean Up Bags" runs. C_Container.SortBags() takes no
-- arguments, and it sorts nothing at all while an item is locked (C_Item.LockItem). So Blizzard's
-- sort runs normally, and the addon then puts the content of the reserved slots back:
-- - Alt-right-click a slot: reserves it or frees it again.
-- - The content is noted right before the sort, and restored once the bags are quiet.
-- - A slot that held an item gets that item back, swapped with what the sort put there. If the sort
--   merged the stack, another stack of the same item is taken.
-- - A slot that was empty is emptied again, as long as there is a free slot for the item.
-- - The "Clean Up Bags" entry of the gamepad menu has no button to hook and sorts everything.
-- - A bar over the search box shows the progress. The sort has no known length, so the bar pulses
--   until the restore starts counting the slots. The bar is a child of the search box, so it follows
--   the box between the bag frames and closes with the bags, while the restore goes on.

-- Seconds without a bag update after which the sort counts as finished. There is no event for it.
local SORT_QUIET_DELAY = 1.5
-- Seconds between two steps of the restore. Moved items stay locked until the server confirms.
local STEP_DELAY = 0.2
-- Steps to wait for one slot (e.g. for locked items or an item on the cursor) before giving up.
local MAX_ATTEMPTS = 50

local MARKER_SIZE = 14
local MARKER_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-LOCK"
-- The lock fills 28 of the 32 pixels of the texture, as in Blizzard's own "|T...|t" strings.
local MARKER_TEXCOORD = 28 / 32

local PROGRESS_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local PROGRESS_PULSE_DURATION = 0.6
local PROGRESS_PULSE_MIN_ALPHA = 0.35

-- Marker texture per item button. Kept here to not write fields to Blizzard's buttons.
local markers = {}
local hookedFrames = {}

-- Slots left to restore, items first (see NoteContent). nil while no restore is running.
local pending
-- Number of slots in the note, for the progress bar.
local pendingTotal = 0
-- True while waiting for the sort to finish, false while the restore moves items.
local waitingForSort = false
local attempts = 0
local timer

local progressBar, progressLabel, progressPulse

local function CreateProgressBar()
    progressBar = CreateFrame("StatusBar", nil, BagItemSearchBox)
    progressBar:SetAllPoints()
    progressBar:SetStatusBarTexture(PROGRESS_TEXTURE)
    progressBar:SetStatusBarColor(0.2, 0.6, 1)
    progressBar:Hide()

    -- Opaque, so the text of the search box does not show through.
    local background = progressBar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0)

    progressLabel = progressBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    progressLabel:SetPoint("CENTER")

    progressPulse = progressBar:GetStatusBarTexture():CreateAnimationGroup()
    progressPulse:SetLooping("BOUNCE")
    local fade = progressPulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(PROGRESS_PULSE_MIN_ALPHA)
    fade:SetDuration(PROGRESS_PULSE_DURATION)
end

local function ShowSortProgress()
    progressBar:SetMinMaxValues(0, 1)
    progressBar:SetValue(1)
    progressLabel:SetText(L["RESERVED_PROGRESS_SORTING"])
    progressPulse:Play()
    progressBar:Show()
end

local function ShowRestoreProgress()
    local done = pendingTotal - #pending
    progressPulse:Stop()
    progressBar:SetMinMaxValues(0, pendingTotal)
    progressBar:SetValue(done)
    progressLabel:SetFormattedText(L["RESERVED_PROGRESS_RESTORING"], done, pendingTotal)
end

local function HideProgress()
    progressPulse:Stop()
    progressBar:Hide()
end

local function IsReservable(bagID)
    return bagID >= Enum.BagIndex.Backpack and bagID <= NUM_TOTAL_BAG_FRAMES
end

local function IsReserved(bagID, slot)
    local slots = ns.charDb.reservedSlots[bagID]
    return slots ~= nil and slots[slot] == true
end

local function SetReserved(bagID, slot, reserved)
    local reservedSlots = ns.charDb.reservedSlots
    local slots = reservedSlots[bagID]
    if reserved then
        if not slots then
            slots = {}
            reservedSlots[bagID] = slots
        end
        slots[slot] = true
    elseif slots then
        slots[slot] = nil
        if next(slots) == nil then
            reservedSlots[bagID] = nil
        end
    end
end

local function UpdateMarker(button)
    markers[button]:SetShown(IsReserved(button:GetBagID(), button:GetID()))
end

local function OnItemButtonClick(button, mouseButton)
    -- At the mailbox, Alt-click is what GryphonMail uses to attach items.
    if mouseButton ~= "RightButton" or not IsAltKeyDown() or CursorHasItem()
        or (SendMailFrame and SendMailFrame:IsVisible()) then
        return
    end
    local bagID, slot = button:GetBagID(), button:GetID()
    if IsReservable(bagID) then
        SetReserved(bagID, slot, not IsReserved(bagID, slot))
        UpdateMarker(button)
    end
end

local function AddMarker(button)
    local marker = button:CreateTexture(nil, "OVERLAY", nil, 6)
    marker:SetSize(MARKER_SIZE, MARKER_SIZE)
    marker:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
    marker:SetTexture(MARKER_TEXTURE)
    marker:SetTexCoord(0, MARKER_TEXCOORD, 0, MARKER_TEXCOORD)
    markers[button] = marker
    button:HookScript("OnClick", OnItemButtonClick)
end

-- Item buttons come from a pool that grows with the bags, so they are set up when first seen.
local function UpdateFrameMarkers(frame)
    for _, button in frame:EnumerateValidItems() do
        if not markers[button] then
            AddMarker(button)
        end
        UpdateMarker(button)
    end
end

local function HookFrame(frame)
    if not hookedFrames[frame] then
        hookedFrames[frame] = true
        hooksecurefunc(frame, "UpdateItems", UpdateFrameMarkers)
    end
end

local function GetItemGUID(bagID, slot)
    return C_Item.GetItemGUID(ItemLocation:CreateFromBagAndSlot(bagID, slot))
end

-- The content of all reserved slots. Slots with an item come first: restoring them can move items
-- into a slot that was empty, which is then cleared afterwards.
local function NoteContent()
    local content = {}
    for bagID, slots in pairs(ns.charDb.reservedSlots) do
        for slot in pairs(slots) do
            local info = C_Container.GetContainerItemInfo(bagID, slot)
            content[#content + 1] = {
                bagID = bagID,
                slot = slot,
                itemID = info and info.itemID,
                itemGUID = info and GetItemGUID(bagID, slot),
                stackCount = info and info.stackCount,
            }
        end
    end
    table.sort(content, function(a, b)
        return a.itemID ~= nil and b.itemID == nil
    end)
    return content
end

-- Where the noted item is now. Without its GUID (the sort merged the stack), the best other stack
-- of the same item outside the reserved slots: one of the noted size, otherwise the first.
local function FindItem(target)
    local foundBag, foundSlot
    for bagID = Enum.BagIndex.Backpack, NUM_TOTAL_BAG_FRAMES do
        for slot = 1, C_Container.GetContainerNumSlots(bagID) do
            local info = C_Container.GetContainerItemInfo(bagID, slot)
            if info and info.itemID == target.itemID then
                if GetItemGUID(bagID, slot) == target.itemGUID then
                    return bagID, slot
                end
                if not IsReserved(bagID, slot) and (not foundBag or info.stackCount == target.stackCount) then
                    foundBag, foundSlot = bagID, slot
                end
            end
        end
    end
    return foundBag, foundSlot
end

-- A free slot outside the reserved ones in a bag that can hold the item.
local function FindFreeSlot(itemID)
    local itemFamily = C_Item.GetItemFamily(itemID) or 0
    for bagID = Enum.BagIndex.Backpack, NUM_TOTAL_BAG_FRAMES do
        local numFree, bagFamily = C_Container.GetContainerNumFreeSlots(bagID)
        if numFree > 0 and (not bagFamily or bagFamily == 0 or bit.band(itemFamily, bagFamily) ~= 0) then
            for _, slot in ipairs(C_Container.GetContainerFreeSlots(bagID)) do
                if not IsReserved(bagID, slot) then
                    return bagID, slot
                end
            end
        end
    end
end

local function IsSlotLocked(bagID, slot)
    local info = C_Container.GetContainerItemInfo(bagID, slot)
    return info ~= nil and info.isLocked
end

-- Moves an item, or swaps it with the item in the target slot.
local function MoveItem(fromBag, fromSlot, toBag, toSlot)
    C_Container.PickupContainerItem(fromBag, fromSlot)
    C_Container.PickupContainerItem(toBag, toSlot)
    -- The target did not take the item, so it goes back instead of staying on the cursor.
    if CursorHasItem() then
        ClearCursor()
    end
end

-- The move that restores the target, or nothing if the slot is fine or cannot be restored.
local function GetMove(target)
    local currentID = C_Container.GetContainerItemID(target.bagID, target.slot)
    if target.itemID then
        if currentID ~= target.itemID then
            local bagID, slot = FindItem(target)
            if bagID then
                return bagID, slot, target.bagID, target.slot
            end
        end
    elseif currentID then
        local bagID, slot = FindFreeSlot(currentID)
        if bagID then
            return target.bagID, target.slot, bagID, slot
        end
    end
end

local function StopRestore()
    if timer then
        timer:Cancel()
        timer = nil
    end
    pending = nil
    waitingForSort = false
    attempts = 0
    HideProgress()
end

local RestoreStep

local function ScheduleStep(delay)
    if timer then
        timer:Cancel()
    end
    timer = C_Timer.NewTimer(delay, RestoreStep)
end

-- One move per step: moved items are locked until the server confirms, and the slot is checked again
-- in the next step. A slot is done when no move is left for it.
function RestoreStep()
    timer = nil
    waitingForSort = false
    ShowRestoreProgress()

    attempts = attempts + 1
    if attempts > MAX_ATTEMPTS then
        StopRestore()
        ns:Notify(L["RESERVED_RESTORE_FAILED"])
        return
    end

    -- Never touches an item the player is holding.
    if CursorHasItem() then
        ScheduleStep(STEP_DELAY)
        return
    end

    while pending[1] do
        local fromBag, fromSlot, toBag, toSlot = GetMove(pending[1])
        if fromBag then
            if not IsSlotLocked(fromBag, fromSlot) and not IsSlotLocked(toBag, toSlot) then
                MoveItem(fromBag, fromSlot, toBag, toSlot)
            end
            ScheduleStep(STEP_DELAY)
            return
        end
        table.remove(pending, 1)
        attempts = 0
    end
    StopRestore()
end

local function OnCleanUp()
    -- A second click during a restore keeps the first note, the slots may be mixed up by now.
    if not pending then
        local content = NoteContent()
        if #content == 0 then
            return
        end
        pending = content
        pendingTotal = #content
    end
    waitingForSort = true
    attempts = 0
    ShowSortProgress()
    ScheduleStep(SORT_QUIET_DELAY)
end

function ReservedSlots:GetCount()
    local count = 0
    for _, slots in pairs(ns.charDb.reservedSlots) do
        for _ in pairs(slots) do
            count = count + 1
        end
    end
    return count
end

function ReservedSlots:Clear()
    StopRestore()
    wipe(ns.charDb.reservedSlots)
    for button in pairs(markers) do
        UpdateMarker(button)
    end
end

function ReservedSlots:OnEnable()
    CreateProgressBar()

    -- Not with ContainerFrameUtil_EnumerateContainerFrames: its first call fills tables Blizzard's bag
    -- code reads later, which would then be tainted. The bank opens the bags and then buys the free
    -- first tab, and that protected call failed with ADDON_ACTION_FORBIDDEN.
    for _, frame in ipairs(ContainerFrameContainer.ContainerFrames) do
        HookFrame(frame)
    end
    HookFrame(ContainerFrameCombinedBags)

    BagItemAutoSortButton:HookScript("PreClick", OnCleanUp)
    BagItemAutoSortButton:HookScript("OnEnter", function()
        GameTooltip_AddNormalLine(GameTooltip, L["RESERVED_HINT"])
        GameTooltip:Show()
    end)

    -- The sort moves items step by step, so the wait starts over with each update.
    ns:RegisterEvent("BAG_UPDATE_DELAYED", function()
        if waitingForSort then
            ScheduleStep(SORT_QUIET_DELAY)
        end
    end)
end

-- "/gryphonbags reserved" shows the number of reserved slots, "clear" frees them all.
ns:RegisterCommand("reserved", function(args)
    local value = args:lower()
    if value == "clear" then
        ReservedSlots:Clear()
        ns:Print(L["RESERVED_CLEARED"])
    elseif value == "" then
        ns:Print(L["RESERVED_COUNT"], ReservedSlots:GetCount())
    else
        ns:Print(L["HELP_RESERVED_CLEAR"])
    end
end, { L["HELP_RESERVED"], L["HELP_RESERVED_CLEAR"] })
