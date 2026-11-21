local _, ns = ...

-- Client checks for Core/Names.lua and the ruleset of the logged-in character. The addon supports
-- Forever alone; further client differences go here if Retail follows.
local Compat = {}
ns.Compat = Compat

-- Forever names are "First Surname", unique per region, without a realm part. Other clients use
-- "Name-Realm". RegionalUniqueNamesEnabled() is the check Blizzard's own NameUtil uses.
function Compat.HasRealmNames()
    return not (RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled())
end

-- Ruleset of the logged-in character from its game rules: "PvE", "PvP", "RP", "RPPvP" or "HC"
-- (hardcore); nil without the ruleset game rules. Since Forever build 71037 it is the only way to
-- tell the ruleset: GetRealmName() returns "" and GetRealmID() 0.
function Compat.GetRuleset()
    local rules = Enum.GameRule
    if not (C_GameRules and C_GameRules.IsGameRuleActive and rules and rules.PvPRuleset
            and rules.RPRuleset) then
        return nil
    end
    local isPvP = C_GameRules.IsGameRuleActive(rules.PvPRuleset)
    local isRP = C_GameRules.IsGameRuleActive(rules.RPRuleset)
    if isPvP and isRP then
        return "RPPvP"
    elseif isPvP then
        return "PvP"
    elseif isRP then
        return "RP"
    elseif rules.HardcoreRuleset and C_GameRules.IsGameRuleActive(rules.HardcoreRuleset) then
        return "HC"
    end
    return "PvE"
end
