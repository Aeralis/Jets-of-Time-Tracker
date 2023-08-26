-- Check if the tracker is in Chronosanity mode
function chronosanityMode()
  return Tracker:ProviderCountForCode("chronosanity") > 0
end

-- Check if the tracker is in Legacy of Cyrus mode
function legacyOfCyrusMode()
  return string.find(Tracker.ActiveVariantUID, "legacy_of_cyrus") ~= nil
end

function notLegacyOfCyrusMode()
  return not legacyOfCyrusMode()
end

-- Check if the tracker is in Lost Worlds mode
function lostWorldsMode()
  return string.find(Tracker.ActiveVariantUID, "lost_world") ~= nil
end

-- Check if the tracker is in Vanilla Rando mode
function vanillaRandoMode()
  return string.find(Tracker.ActiveVariantUID, "vanilla") ~= nil
end

function canAccessSealed()
  local pendant = Tracker:FindObjectForCode("pendant").Active
  local earlyPendant = Tracker:ProviderCountForCode("earlypendant") > 0
  local blackTyrano = Tracker:FindObjectForCode("blacktyranoboss").Active
  local dragonTank = Tracker:FindObjectForCode("dragontankboss").Active
  local magus = Tracker:FindObjectForCode("magusboss").Active
  local locMode = legacyOfCyrusMode()
  local lwMode = lostWorldsMode()

  return ((dragonTank or (locMode and pendant)) and earlyPendant) or (pendant and (magus or blackTyrano or lwMode))
end

function canAccessMagusCastle()
  local frog = Tracker:FindObjectForCode("frog").Active
  local masamune = Tracker:FindObjectForCode("masamune").Active

  if legacyOfCyrusMode() then
    local magus = Tracker:FindObjectForCode("magus").Active
    return frog and magus and masamune
  end

  return frog and masamune
end

function canAccessNorthernRuins()
  if not canFly() then
    return false
  end

  local grandleon = Tracker:FindObjectForCode("grandleon").Active

  if legacyOfCyrusMode() then
    local frog = Tracker:FindObjectForCode("frog").Active
    local magus = Tracker:FindObjectForCode("magus").Active
    return frog and magus and grandleon
  end

  return grandleon
end

function canAccessOzzieFort()
  if not canFly() then
    return false
  end

  if legacyOfCyrusMode() then
    local frog = Tracker:FindObjectForCode("frog").Active
    local magus = Tracker:FindObjectForCode("magus").Active
    local magusboss = Tracker:FindObjectForCode("magusboss").Active
    return frog and magus and magusboss
  end

  local pendant = Tracker:FindObjectForCode("pendant").Active
  local gatekey = Tracker:FindObjectForCode("gatekey").Active

  return pendant or gatekey
end


function couldAccessOceanPalace()
  return not legacyOfCyrusMode()
end



function couldAccessTyranoCastle()
  return not legacyOfCyrusMode()
end

function couldAccessSunKeep()
  return not legacyOfCyrusMode()
end

function canFly()
  local epochfail = Tracker:ProviderCountForCode("epochfail") > 0
  local fixedepoch = Tracker:FindObjectForCode("fixedepoch").Active

  return (not epochfail) or fixedepoch
end

