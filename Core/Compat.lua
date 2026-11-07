local _, ns = ...

-- Only what Core/Names.lua needs, taken over from GryphonMail. The addon supports Forever alone, so
-- this is the one check it has; further client differences go here if Retail follows.
local Compat = {}
ns.Compat = Compat

-- Forever names are "First Surname", unique per region, without a realm part. Other clients use
-- "Name-Realm". RegionalUniqueNamesEnabled() is the check Blizzard's own NameUtil uses.
function Compat.HasRealmNames()
    return not (RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled())
end
