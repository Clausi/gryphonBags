-- luacheck configuration for GryphonBags (WoW Forever, Lua 5.1)
std = "lua51"
max_line_length = 120
exclude_files = { ".tools/" }

-- Methods defined with ":" do not have to use the implicit self.
self = false

-- Globals the addon defines.
globals = {
    "GryphonBagsDB",
    "GryphonBagsCharDB",
    "SLASH_GRYPHONBAGS1",
    "SlashCmdList",
}

-- WoW API and Blizzard UI globals the addon reads. Add new ones here when used.
read_globals = {
    -- WoW Lua extensions
    "bit",
    "strtrim",
    "hooksecurefunc",
    "wipe",

    -- API
    "C_ClassColor",
    "C_AddOns",
    "C_Container",
    "C_Item",
    "C_Timer",
    "ClearCursor",
    "Constants",
    "CreateFrame",
    "CursorHasItem",
    "Enum",
    "GetAddOnMemoryUsage",
    "GetLocale",
    "GetMoney",
    "GetNormalizedRealmName",
    "GetRealmName",
    "InCombatLockdown",
    "issecretvalue",
    "IsAltKeyDown",
    "IsShiftKeyDown",
    "ItemLocation",
    "RegionalUniqueNamesEnabled",
    "Settings",
    "UnitClass",
    "UnitFactionGroup",
    "UnitName",
    "UpdateAddOnMemoryUsage",

    -- UI helpers
    "CreateSettingsButtonInitializer",
    "CreateSettingsListSectionHeaderInitializer",
    "GameTooltip_AddNormalLine",
    "GetMoneyString",

    -- Frames
    "BagItemAutoSortButton",
    "BagItemSearchBox",
    "ContainerFrame1",
    "ContainerFrameCombinedBags",
    "ContainerFrameContainer",
    "DEFAULT_CHAT_FRAME",
    "GameTooltip",
    "SendMailFrame",
    "SettingsPanel",

    -- Constants and global strings
    "GRAY_FONT_COLOR",
    "HIGHLIGHT_FONT_COLOR",
    "NUM_TOTAL_BAG_FRAMES",
}
