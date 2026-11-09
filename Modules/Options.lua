local _, ns = ...
local L = ns.L
local Options = ns:RegisterModule("Options")

-- Options page in Blizzard's settings (Esc > Options > AddOns > GryphonBags) as a vertical list.
-- The settings stay in ns.db and ns.charDb; proxy settings read and write them there.

local category

-- Proxy setting variables must be unique among all settings of the game and addons.
local function RegisterProxySetting(variable, varType, name, defaultValue, getValue, setValue)
    return Settings.RegisterProxySetting(category, "GRYPHONBAGS_" .. variable, varType, name, defaultValue,
        getValue, setValue)
end

-- Known characters, like "/gryphonbags chars remove": a dropdown picks one, the button removes it.
-- The selection is not saved; "" is no selection.
local function RegisterCharacterRemoval()
    local Characters = ns.modules.Characters
    local layout = SettingsPanel:GetLayout(category)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["OPTIONS_CHARACTERS_HEADER"]))

    local selected = ""
    local selection = RegisterProxySetting("REMOVE_CHARACTER", Settings.VarType.String, L["OPTIONS_CHARACTER"], "",
        function()
            return selected
        end,
        function(value)
            selected = value
        end)

    -- Called each time the dropdown opens, so it lists the characters stored at that moment.
    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("", L["OPTIONS_CHARACTER_NONE"])
        for _, character in ipairs(Characters:GetCharacters()) do
            if not character.isCurrent then
                container:Add(character.fullName, Characters:FormatCharacter(character))
            end
        end
        return container:GetData()
    end
    Settings.CreateDropdown(category, selection, GetOptions, L["OPTIONS_CHARACTER_TOOLTIP"])

    -- No search tags (addSearchTags = false): tags added from addon code taint the initializer, the
    -- settings search reads them for every initializer and carries the taint on to the search results.
    -- On Forever, showing a Discord row there then calls the protected C_Discord.IsUserOAuthed.
    layout:AddInitializer(CreateSettingsButtonInitializer(L["OPTIONS_CHARACTER_REMOVE"],
        L["OPTIONS_CHARACTER_REMOVE_BUTTON"], function()
        if selected == "" then
            return
        end
        Characters:Remove(selected)
        -- Also clears a selection that was removed by command in the meantime.
        selection:SetValue("")
    end, nil, false))
end

local function RegisterSettings()
    local notifications = RegisterProxySetting("NOTIFICATIONS", Settings.VarType.Boolean,
        L["OPTIONS_NOTIFICATIONS"], ns.charDefaults.notifications,
        function()
            return ns.charDb.notifications
        end,
        function(value)
            ns.charDb.notifications = value
        end)
    Settings.CreateCheckbox(category, notifications, L["OPTIONS_NOTIFICATIONS_TOOLTIP"])

    local goldTooltip = RegisterProxySetting("GOLD_TOOLTIP", Settings.VarType.Boolean,
        L["OPTIONS_GOLD_TOOLTIP"], ns.charDefaults.goldTooltip,
        function()
            return ns.charDb.goldTooltip
        end,
        function(value)
            ns.charDb.goldTooltip = value
        end)
    Settings.CreateCheckbox(category, goldTooltip, L["OPTIONS_GOLD_TOOLTIP_TOOLTIP"])

    local goldTooltipSort = RegisterProxySetting("GOLD_TOOLTIP_SORT", Settings.VarType.String,
        L["OPTIONS_GOLD_TOOLTIP_SORT"], ns.charDefaults.goldTooltipSort,
        function()
            return ns.charDb.goldTooltipSort
        end,
        function(value)
            ns.charDb.goldTooltipSort = value
        end)
    local function GetSortOptions()
        local container = Settings.CreateControlTextContainer()
        for _, order in ipairs(ns.modules.GoldTooltip.SORT_ORDERS) do
            container:Add(order.key, L[order.label])
        end
        return container:GetData()
    end
    Settings.CreateDropdown(category, goldTooltipSort, GetSortOptions, L["OPTIONS_GOLD_TOOLTIP_SORT_TOOLTIP"])

    RegisterCharacterRemoval()
end

function Options:OnInitialize()
    category = Settings.RegisterVerticalLayoutCategory(ns.name)
    RegisterSettings()
    Settings.RegisterAddOnCategory(category)
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
