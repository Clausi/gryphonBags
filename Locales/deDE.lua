local _, ns = ...

if GetLocale() ~= "deDE" then
    return
end

local L = ns.L

L["ADDON_LOADED"] = "Version %s geladen. Tippe /gryphonbags für Hilfe."
L["DEBUG_ON"] = "Debug-Ausgabe aktiviert."
L["DEBUG_OFF"] = "Debug-Ausgabe deaktiviert."
L["HELP_HEADER"] = "Befehle:"
L["HELP_VERSION"] = "/gryphonbags version - zeigt die Addon-Version"
L["HELP_DEBUG"] = "/gryphonbags debug - schaltet die Debug-Ausgabe um"
L["HELP_NOTIFY"] = "/gryphonbags notify on||off - automatische Meldungen (Login, Hinweise)"
L["HELP_OPTIONS"] = "/gryphonbags options - öffnet die Optionen"
L["NOTIFY_ON"] = "Automatische Meldungen sind für diesen Charakter an."
L["NOTIFY_OFF"] = "Automatische Meldungen sind für diesen Charakter aus. Antworten auf Befehle erscheinen weiter."
L["OPTIONS_IN_COMBAT"] = "Die Optionen lassen sich im Kampf nicht per Befehl öffnen. Nutze "
    .. "Esc > Optionen > AddOns oder versuche es nach dem Kampf erneut."
L["OPTIONS_NOTIFICATIONS"] = "Automatische Meldungen"
L["OPTIONS_NOTIFICATIONS_TOOLTIP"] = "Meldungen, die das Addon von sich aus zeigt: beim Login und Hinweise. "
    .. "Antworten auf Befehle erscheinen immer. Für diesen Charakter."
