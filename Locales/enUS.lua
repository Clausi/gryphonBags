local _, ns = ...

-- Base locale. Every key used in the addon must be defined here.
-- Other locales only override the keys they translate; missing keys fall back to enUS.
local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
ns.L = L

L["ADDON_LOADED"] = "Version %s loaded. Type /gryphonbags for help."
L["DEBUG_ON"] = "Debug output enabled."
L["DEBUG_OFF"] = "Debug output disabled."
L["HELP_HEADER"] = "Commands:"
L["HELP_VERSION"] = "/gryphonbags version - show the addon version"
L["HELP_DEBUG"] = "/gryphonbags debug - toggle debug output"
L["HELP_NOTIFY"] = "/gryphonbags notify on||off - automatic messages (login, hints)"
L["HELP_OPTIONS"] = "/gryphonbags options - open the options"
L["HELP_RESERVED"] = "/gryphonbags reserved - show the number of reserved bag slots"
L["HELP_RESERVED_CLEAR"] = "/gryphonbags reserved clear - free all reserved bag slots of this character"
L["HELP_CHARS"] = "/gryphonbags chars - list your known characters and their gold"
L["HELP_CHARS_REMOVE"] = "/gryphonbags chars remove <number||name> - forget a character"
L["RESERVED_COUNT"] = "Reserved bag slots of this character: %d"
L["RESERVED_CLEARED"] = "All reserved bag slots of this character are free again."
L["RESERVED_HINT"] = "Alt-right-click a bag slot to keep its item in place."
L["RESERVED_RESTORE_FAILED"] = "Not all reserved bag slots could be restored after cleaning up."
L["RESERVED_PROGRESS_SORTING"] = "Sorting..."
L["RESERVED_PROGRESS_RESTORING"] = "Reserved slots: %d/%d"
L["NOTIFY_ON"] = "Automatic messages are on for this character."
L["NOTIFY_OFF"] = "Automatic messages are off for this character. Answers to commands are still shown."
L["OPTIONS_IN_COMBAT"] = "The options cannot be opened by command in combat. Use "
    .. "Esc > Options > AddOns or try again after the fight."
L["OPTIONS_NOTIFICATIONS"] = "Automatic messages"
L["OPTIONS_NOTIFICATIONS_TOOLTIP"] = "Messages the addon shows on its own: on login and hints. "
    .. "Answers to commands always appear. For this character."
L["OPTIONS_CHARACTERS_HEADER"] = "Known Characters"
L["OPTIONS_CHARACTER"] = "Character"
L["OPTIONS_CHARACTER_TOOLTIP"] = "Your characters are recorded with their gold on login. Choose one to forget, "
    .. "e.g. a deleted character. The current character is not listed."
L["OPTIONS_CHARACTER_NONE"] = "Choose a character"
L["OPTIONS_CHARACTER_REMOVE"] = "Forget the chosen character"
L["OPTIONS_CHARACTER_REMOVE_BUTTON"] = "Remove"
L["CHARS_HEADER"] = "Known characters:"
L["CHARS_EMPTY"] = "No characters known yet."
L["CHARS_CURRENT"] = "(current)"
L["CHARS_REMOVED"] = "Removed %s."
L["CHARS_NOT_FOUND"] = "Character not found: %s"
L["CHARS_REMOVE_CURRENT"] = "The current character cannot be removed."
L["FACTION_ALLIANCE"] = "Alliance"
L["FACTION_HORDE"] = "Horde"
L["FACTION_NEUTRAL"] = "Neutral"
