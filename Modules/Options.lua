local _, ns = ...
local L = ns.L
local Options = ns:RegisterModule("Options")

-- Options page in Blizzard's settings (Esc > Options > AddOns > GryphonBags), built with own
-- controls (Core/OptionsPanel.lua explains why). The settings stay in ns.db and ns.charDb; the
-- controls read and write them there, so a change takes effect right away.

local category, panel

local function AddGeneral()
    panel:AddCheckbox(L["OPTIONS_NOTIFICATIONS"], L["OPTIONS_NOTIFICATIONS_TOOLTIP"],
        function()
            return ns.charDb.notifications
        end,
        function(value)
            ns.charDb.notifications = value
        end)

    panel:AddCheckbox(L["OPTIONS_OWN_SORT"], L["OPTIONS_OWN_SORT_TOOLTIP"],
        function()
            return ns.charDb.ownSort
        end,
        function(value)
            ns.charDb.ownSort = value
            ns.modules.Sort:Update()
        end)
end

local function AddGoldTooltip()
    local SORT_ORDERS = ns.modules.GoldTooltip.SORT_ORDERS
    panel:AddCheckbox(L["OPTIONS_GOLD_TOOLTIP"], L["OPTIONS_GOLD_TOOLTIP_TOOLTIP"],
        function()
            return ns.charDb.goldTooltip
        end,
        function(value)
            ns.charDb.goldTooltip = value
        end)

    local choices = {}
    for _, order in ipairs(SORT_ORDERS) do
        choices[#choices + 1] = { value = order.key, text = L[order.label] }
    end
    panel:AddChoice(L["OPTIONS_GOLD_TOOLTIP_SORT"], L["OPTIONS_GOLD_TOOLTIP_SORT_TOOLTIP"], choices,
        function()
            -- Unknown saved values (e.g. from a later version) sort by the first order, see GoldTooltip.
            for _, order in ipairs(SORT_ORDERS) do
                if order.key == ns.charDb.goldTooltipSort then
                    return order.key
                end
            end
            return SORT_ORDERS[1].key
        end,
        function(value)
            ns.charDb.goldTooltipSort = value
        end)
end

-- Known characters, like "/gryphonbags chars remove": a dropdown picks one, the button removes it.
-- The selection is not saved; "" is no selection.
local function AddCharacterRemoval()
    local Characters = ns.modules.Characters
    panel:AddHeader(L["OPTIONS_CHARACTERS_HEADER"])

    local selected = ""
    -- Called on every refresh, so it lists the characters stored at that moment.
    local function GetChoices()
        local choices = { { value = "", text = L["OPTIONS_CHARACTER_NONE"] } }
        for _, character in ipairs(Characters:GetCharacters()) do
            if not character.isCurrent then
                choices[#choices + 1] = { value = character.fullName, text = Characters:FormatCharacter(character) }
            end
        end
        return choices
    end
    panel:AddDropdown(L["OPTIONS_CHARACTER"], L["OPTIONS_CHARACTER_TOOLTIP"], GetChoices,
        function()
            -- A character removed by command in the meantime is no selection.
            return ns.db.characters[selected] and selected or ""
        end,
        function(value)
            selected = value
        end)

    panel:AddButton(L["OPTIONS_CHARACTER_REMOVE"], L["OPTIONS_CHARACTER_REMOVE_BUTTON"],
        L["OPTIONS_CHARACTER_TOOLTIP"], function()
            if selected ~= "" then
                Characters:Remove(selected)
            end
            selected = ""
            panel:Refresh()
        end)
end

function Options:OnInitialize()
    panel = ns.OptionsPanel.Create(ns.name)
    AddGeneral()
    AddGoldTooltip()
    AddCharacterRemoval()
    category = panel:Register()
end

-- "/gryphonbags options" opens the options page. Opening it from addon code is blocked in combat
-- (ADDON_ACTION_BLOCKED for OpenSettingsPanel); Esc > Options still works there.
ns:RegisterCommand("options", function()
    if InCombatLockdown() then
        ns:Print(L["OPTIONS_IN_COMBAT"])
        return
    end
    Settings.OpenToCategory(category:GetID())
end, { L["HELP_OPTIONS"] })
