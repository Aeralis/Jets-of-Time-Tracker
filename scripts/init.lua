Tracker:AddItems("items/items.json")
Tracker:AddMaps("maps/maps.json")
ScriptHost:LoadScript("scripts/logic.lua")

local variantUid = Tracker.ActiveVariantUID or ""

if string.find(variantUid, "items_only", 1, true) then
  Tracker:AddLayouts("items_only/layouts/tracker.json")
  Tracker:AddLayouts("layouts/broadcast.json")
elseif string.find(variantUid, "chronosanity", 1, true) then
  Tracker:AddLocations("chronosanity/locations/locations.json")
  Tracker:AddLayouts("chronosanity/layouts/tracker.json")
  Tracker:AddLayouts("chronosanity/layouts/broadcast.json")
elseif string.find(variantUid, "lost_world_items", 1, true) then
  Tracker:AddLayouts("lost_world_items/layouts/tracker.json")
  Tracker:AddLayouts("lost_world_items/layouts/broadcast.json")
elseif string.find(variantUid, "lost_worlds", 1, true) then
  Tracker:AddLocations("lost_worlds/locations/locations.json")
  Tracker:AddLayouts("lost_worlds/layouts/tracker.json")
  Tracker:AddLayouts("lost_worlds/layouts/broadcast.json")
elseif string.find(variantUid, "vanilla_rando", 1, true) then
  Tracker:AddLocations("vanilla_rando/locations/locations.json")
  Tracker:AddLayouts("vanilla_rando/layouts/tracker.json")
  Tracker:AddLayouts("vanilla_rando/layouts/broadcast.json")
else
  Tracker:AddLocations("locations/locations.json")
  Tracker:AddLayouts("layouts/tracker.json")
  Tracker:AddLayouts("layouts/broadcast.json")
end

if AUTOTRACKER_ENABLE_DEBUG_LOGGING == nil then
  AUTOTRACKER_ENABLE_DEBUG_LOGGING = false
end

local ok, err = pcall(function()
  ScriptHost:LoadScript("scripts/autotracking.lua")
end)
if not ok then
  print("Auto-tracker disabled: failed to load scripts/autotracking.lua")
  if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
    print("Reason: " .. tostring(err))
    print("Hint: ensure the host supports Lua autotracking, the provider/connector is active, and memory watch APIs are available.")
  end
end