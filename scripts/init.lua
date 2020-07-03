Tracker:AddItems("items/items.json")
Tracker:AddMaps("maps/maps.json")

if (string.find(Tracker.ActiveVariantUID, "standard")) then
	Tracker:AddLocations("locations/locations.json")
	Tracker:AddLayouts("layouts/tracker.json")
	Tracker:AddLayouts("layouts/broadcast.json")
else
end
if (string.find(Tracker.ActiveVariantUID, "items_only")) then
	Tracker:AddLayouts("items_only/layouts/tracker.json")
	Tracker:AddLayouts("layouts/broadcast.json")
else
end
if (string.find(Tracker.ActiveVariantUID, "lost_worlds")) then
	Tracker:AddLocations("lost_worlds/locations/locations.json")
	Tracker:AddLayouts("lost_worlds/layouts/tracker.json")
	Tracker:AddLayouts("lost_worlds/layouts/broadcast.json")
else
end
if (string.find(Tracker.ActiveVariantUID, "lost_world_items")) then
	Tracker:AddLayouts("lost_world_items/layouts/tracker.json")
	Tracker:AddLayouts("lost_world_items/layouts/broadcast.json")
else
end

if _VERSION == "Lua 5.3" then
    ScriptHost:LoadScript("scripts/autotracking.lua")
else    
    print("Auto-tracker is unsupported by your tracker version")
end