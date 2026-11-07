local _, ns = ...
local L = ns.L
local GoldTooltip = ns:RegisterModule("GoldTooltip")

-- Tooltip on the gold display of the bags: the gold of the known characters the logged-in one can
-- exchange gold with (same ruleset and faction) and its sum. With Shift held down, all known
-- characters and their sum. The money frame itself does not take the mouse, its coin buttons do
-- (Blizzard's small money frame template). The tooltip sits beside the bag so it does not cover the
-- slots.

local COIN_BUTTONS = { "GoldButton", "SilverButton", "CopperButton" }

-- Coin button under the mouse while the tooltip is shown, for redrawing it when Shift changes.
local hoveredButton

local function ByMoneyDescending(a, b)
    if a.money ~= b.money then
        return a.money > b.money
    end
    return a.fullName < b.fullName
end

local function ShowTooltip(button)
    if not ns.charDb.goldTooltip then
        return
    end

    local moneyFrame = button:GetParent()
    GameTooltip:SetOwner(moneyFrame, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("BOTTOMRIGHT", moneyFrame:GetParent(), "BOTTOMLEFT")
    hoveredButton = button

    local showAll = IsShiftKeyDown()
    GameTooltip:AddLine(showAll and L["GOLD_TOOLTIP_HEADER_ALL"] or L["GOLD_TOOLTIP_HEADER"])

    local Characters = ns.modules.Characters
    local characters = Characters:GetCharacters()
    table.sort(characters, ByMoneyDescending)

    local r, g, b = HIGHLIGHT_FONT_COLOR:GetRGB()
    local total = 0
    local hasHiddenCharacters = false
    for _, character in ipairs(characters) do
        if showAll or character.sharesGold then
            total = total + character.money
            -- Ruleset and faction only tell the characters apart in the full list.
            GameTooltip:AddDoubleLine(Characters:FormatCharacter(character, not showAll),
                GetMoneyString(character.money, true), r, g, b, r, g, b)
        else
            hasHiddenCharacters = true
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(L["GOLD_TOOLTIP_TOTAL"], GetMoneyString(total, true), r, g, b, r, g, b)
    if hasHiddenCharacters then
        GameTooltip:AddLine(L["GOLD_TOOLTIP_SHIFT_HINT"], GRAY_FONT_COLOR:GetRGB())
    end
    GameTooltip:Show()
end

local function HideTooltip(button)
    hoveredButton = nil
    if GameTooltip:IsOwned(button:GetParent()) then
        GameTooltip:Hide()
    end
end

local function OnModifierChanged(_, key)
    if hoveredButton and hoveredButton:IsVisible() and (key == "LSHIFT" or key == "RSHIFT") then
        ShowTooltip(hoveredButton)
    end
end

function GoldTooltip:OnEnable()
    -- The backpack and the combined bags have a money frame each.
    for _, moneyFrame in ipairs({ ContainerFrame1.MoneyFrame, ContainerFrameCombinedBags.MoneyFrame }) do
        for _, key in ipairs(COIN_BUTTONS) do
            moneyFrame[key]:HookScript("OnEnter", ShowTooltip)
            moneyFrame[key]:HookScript("OnLeave", HideTooltip)
        end
    end
    ns:RegisterEvent("MODIFIER_STATE_CHANGED", OnModifierChanged)
end
