local _, ns = ...
local L = ns.L
local Names = ns.Names

-- Remembers the account's own characters and their gold. There is no API listing them, so every
-- character is recorded on login in the account-wide saved variables, keyed by full name
-- (Names.Normalize: "Tor Donnerstein"). Taken over from GryphonMail's Modules/Characters.lua.
local Characters = ns:RegisterModule("Characters")

-- Full name of the logged-in character, read once on login.
local playerName

-- Localized faction names for UnitFactionGroup() values.
local FACTION_LABELS = {
    Alliance = L["FACTION_ALLIANCE"],
    Horde = L["FACTION_HORDE"],
    Neutral = L["FACTION_NEUTRAL"],
}

-- Ruleset of a Forever realm name, nil without a realm. Forever has one mega server per ruleset,
-- made up of many realms, and characters of one ruleset can land on different ones:
-- "CAMWOW US1 Realm 10 RP" and "CAMWOW US2 Realm 11 RP" are the same mega server. No API returns
-- the ruleset, so it is read from the name: the text after "Realm <number>" ("PvE", "PVP", "RP",
-- "RPPVP"), or the last word for names without that part ("Classic Beta PvE").
local function GetRulesetName(realm)
    if not realm then
        return nil
    end
    return realm:match("Realm %d+%s+(.-)%s*$") or realm:match("(%S+)%s*$") or realm
end

-- Comparable form of GetRulesetName(): case and spaces are not consistent between realm names.
local function GetRulesetKey(realm)
    local name = GetRulesetName(realm)
    return name and (name:lower():gsub("%s+", ""))
end

-- Returns the stored full names, sorted. The order defines the numbers shown by "/gryphonbags chars".
local function GetSortedNames()
    local names = {}
    for fullName in pairs(ns.db.characters) do
        names[#names + 1] = fullName
    end
    table.sort(names)
    return names
end

local function ColorizeName(fullName)
    local info = ns.db.characters[fullName]
    local color = info and info.class and C_ClassColor.GetClassColor(info.class)
    local displayName = Names.ToDisplay(fullName)
    return color and color:WrapTextInColorCode(displayName) or displayName
end

-- Resolves a number from the list, a full name or a unique first name, case-insensitive.
local function FindCharacter(input)
    local names = GetSortedNames()
    local number = tonumber(input)
    if number then
        return names[number]
    end

    local wanted = input:lower()
    local wantedFullName = (Names.Normalize(input) or input):lower()
    local firstNameMatch
    local firstNameMatches = 0
    for _, fullName in ipairs(names) do
        if fullName:lower() == wantedFullName then
            return fullName
        end
        if Names.GetFirstName(fullName):lower() == wanted then
            firstNameMatch = fullName
            firstNameMatches = firstNameMatches + 1
        end
    end
    return firstNameMatches == 1 and firstNameMatch or nil
end

local function ListCharacters()
    -- Same order as GetSortedNames(), so the numbers match "chars remove".
    local characters = Characters:GetCharacters()
    if #characters == 0 then
        ns:Print(L["CHARS_EMPTY"])
        return
    end

    ns:Print(L["CHARS_HEADER"])
    for i, character in ipairs(characters) do
        ns:Print(("%d. %s: %s"):format(i, Characters:FormatCharacter(character),
            GetMoneyString(character.money, true)))
    end
end

local function RemoveCharacter(input)
    if input == "" then
        ns:Print(L["HELP_CHARS_REMOVE"])
        return
    end

    local fullName = FindCharacter(input)
    if not fullName then
        ns:Print(L["CHARS_NOT_FOUND"], input)
        return
    end
    Characters:Remove(fullName)
end

-- Reads the logged-in character and records it in the saved variables.
local function RecordPlayer()
    playerName = Names.GetPlayerName()
    if not playerName then
        return
    end

    local _, classFile = UnitClass("player")
    ns.db.characters[playerName] = {
        class = classFile,
        faction = UnitFactionGroup("player"),
        -- One of the realms of the ruleset, see GetRulesetName().
        realm = GetRealmName(),
        money = GetMoney(),
    }
end

local function RecordMoney()
    local info = playerName and ns.db.characters[playerName]
    if info then
        info.money = GetMoney()
    end
end

function Characters:OnInitialize()
    ns:RegisterCommand("chars", function(args)
        local action, rest = args:match("^(%S*)%s*(.-)$")
        if action:lower() == "remove" then
            RemoveCharacter(rest)
        else
            ListCharacters()
        end
    end, { L["HELP_CHARS"], L["HELP_CHARS_REMOVE"] })

    -- A Pandaren picks a faction during the session.
    ns:RegisterEvent("NEUTRAL_FACTION_SELECT_RESULT", RecordPlayer)
    ns:RegisterEvent("PLAYER_MONEY", RecordMoney)
end

function Characters:OnEnable()
    RecordPlayer()
end

-- Returns a new list of the known characters, sorted by name:
--   { fullName = "Tor Donnerstein", class = "WARRIOR", faction = "Alliance", ruleset = "RP",
--     money = 12345, isCurrent = bool, sharesGold = bool }
-- money is in copper, as of the character's last session.
-- sharesGold: gold can go between this character and the logged-in one (also true for that one).
-- Trade and mail only work within the same faction and ruleset, whichever of its realms the
-- characters are on.
function Characters:GetCharacters()
    local player = playerName and ns.db.characters[playerName]
    local playerRuleset = player and GetRulesetKey(player.realm)
    local characters = {}
    for _, fullName in ipairs(GetSortedNames()) do
        local info = ns.db.characters[fullName]
        characters[#characters + 1] = {
            fullName = fullName,
            class = info.class,
            faction = info.faction,
            ruleset = GetRulesetName(info.realm),
            money = info.money,
            isCurrent = fullName == playerName,
            sharesGold = player ~= nil and info.faction == player.faction
                and GetRulesetKey(info.realm) == playerRuleset,
        }
    end
    return characters
end

-- Class-colored name, "(ruleset, faction)" in gray and "(current)", for an entry of GetCharacters().
-- hideDetails leaves out ruleset and faction, for lists where all characters share them.
function Characters:FormatCharacter(character, hideDetails)
    local line = ColorizeName(character.fullName)
    local details = {}
    if not hideDetails then
        details[#details + 1] = character.ruleset
        details[#details + 1] = FACTION_LABELS[character.faction] or character.faction
    end
    if #details > 0 then
        line = line .. " " .. GRAY_FONT_COLOR:WrapTextInColorCode("(" .. table.concat(details, ", ") .. ")")
    end
    if character.isCurrent then
        line = line .. " " .. L["CHARS_CURRENT"]
    end
    return line
end

-- Forgets a stored character (fullName as in GetCharacters()) and prints the result. The logged-in
-- character cannot be removed. Returns true if it was removed.
function Characters:Remove(fullName)
    if fullName == playerName then
        ns:Print(L["CHARS_REMOVE_CURRENT"])
        return false
    end
    if not ns.db.characters[fullName] then
        return false
    end

    local coloredName = ColorizeName(fullName)
    ns.db.characters[fullName] = nil
    ns:Print(L["CHARS_REMOVED"], coloredName)
    return true
end
