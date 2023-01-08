function canAccessSealed() 
  local pendant = Tracker:FindObjectForCode("pendant").Active
  local earlyPendant = Tracker:ProviderCountForCode("earlypendant") > 0
  local blackTyrano = Tracker:FindObjectForCode("blacktyranoboss").Active
  local dragonTank = Tracker:FindObjectForCode("dragontankboss").Active
  local magus = Tracker:FindObjectForCode("magusboss").Active
  local locMode = string.find(Tracker.ActiveVariantUID, "legacy_of_cyrus")
  local lwMode = string.find(Tracker.ActiveVariantUID, "lost_worlds")
  
  return ((dragonTank or (locMode and pendant)) and earlyPendant) or (pendant and (magus or blackTyrano or lwMode))
end

function canFly()
  local epochfail = Tracker:ProviderCountForCode("epochfail") > 0
  local fixedepoch = Tracker:FindObjectForCode("fixedepoch").Active

  return (not epochfail) or fixedepoch
end