Tracker:AddItems("items/items.json")
Tracker:AddMaps("maps/maps.json")
ScriptHost:LoadScript("scripts/logic.lua")

if string.find(Tracker.ActiveVariantUID, "items_only") then
  Tracker:AddLayouts("items_only/layouts/tracker.json")
  Tracker:AddLayouts("layouts/broadcast.json")
elseif string.find(Tracker.ActiveVariantUID, "lost_world_items") then
  Tracker:AddLayouts("lost_world_items/layouts/tracker.json")
  Tracker:AddLayouts("lost_world_items/layouts/broadcast.json")
elseif lostWorldsMode() then
  Tracker:AddLocations("lost_worlds/locations/locations.json")
  Tracker:AddLayouts("lost_worlds/layouts/tracker.json")
  Tracker:AddLayouts("lost_worlds/layouts/broadcast.json")
elseif vanillaRandoMode() then
  Tracker:AddLocations("vanilla_rando/locations/locations.json")
  Tracker:AddLayouts("vanilla_rando/layouts/tracker.json")
  Tracker:AddLayouts("vanilla_rando/layouts/broadcast.json")
else
  Tracker:AddLocations("locations/locations.json")
  Tracker:AddLayouts("layouts/tracker.json")
  Tracker:AddLayouts("layouts/broadcast.json")
end

if _VERSION == "Lua 5.3" then
    ScriptHost:LoadScript("scripts/autotracking.lua")
else
    print("Auto-tracker is unsupported by your tracker version")
end
