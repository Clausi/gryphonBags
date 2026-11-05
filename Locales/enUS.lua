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
L["NOTIFY_ON"] = "Automatic messages are on for this character."
L["NOTIFY_OFF"] = "Automatic messages are off for this character. Answers to commands are still shown."
L["OPTIONS_IN_COMBAT"] = "The options cannot be opened by command in combat. Use "
    .. "Esc > Options > AddOns or try again after the fight."
L["OPTIONS_NOTIFICATIONS"] = "Automatic messages"
L["OPTIONS_NOTIFICATIONS_TOOLTIP"] = "Messages the addon shows on its own: on login and hints. "
    .. "Answers to commands always appear. For this character."
