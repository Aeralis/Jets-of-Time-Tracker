function canAccessSealed() 
  local pendantObj = Tracker:FindObjectForCode("pendant")
  local blackTyranoObj = Tracker:FindObjectForCode("blacktyranoboss")
  local dragonTankObj = Tracker:FindObjectForCode("dragontankboss")
  local magusObj = Tracker:FindObjectForCode("magusboss")

  local pendant = pendantObj and pendantObj.Active or false
  local earlyPendant = Tracker:ProviderCountForCode("earlypendant") > 0
  local blackTyrano = blackTyranoObj and blackTyranoObj.Active or false
  local dragonTank = dragonTankObj and dragonTankObj.Active or false
  local magus = magusObj and magusObj.Active or false
  local uid = Tracker.ActiveVariantUID or ""
  local locMode = string.find(uid, "legacy_of_cyrus", 1, true) ~= nil
  local lwMode = string.find(uid, "lost_worlds", 1, true) ~= nil
  
  return ((dragonTank or (locMode and pendant)) and earlyPendant) or (pendant and (magus or blackTyrano or lwMode))
end

function canFly()
  local epochfail = Tracker:ProviderCountForCode("epochfail") > 0
  local fixedepochObj = Tracker:FindObjectForCode("fixedepoch")
  local fixedepoch = fixedepochObj and fixedepochObj.Active or false

  return (not epochfail) or fixedepoch
end