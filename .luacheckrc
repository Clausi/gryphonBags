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
    "C_AddOns",
    "C_Container",
    "C_Item",
    "C_Timer",
    "ClearCursor",
    "CreateFrame",
    "CursorHasItem",
    "Enum",
    "GetAddOnMemoryUsage",
    "GetLocale",
    "InCombatLockdown",
    "IsAltKeyDown",
    "ItemLocation",
    "Settings",
    "UpdateAddOnMemoryUsage",

    -- UI helpers
    "GameTooltip_AddNormalLine",

    -- Frames
    "BagItemAutoSortButton",
    "BagItemSearchBox",
    "ContainerFrameCombinedBags",
    "ContainerFrameContainer",
    "DEFAULT_CHAT_FRAME",
    "GameTooltip",
    "SendMailFrame",

    -- Constants and global strings
    "NUM_TOTAL_BAG_FRAMES",
}
