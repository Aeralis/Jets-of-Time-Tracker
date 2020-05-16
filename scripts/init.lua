Tracker:AddItems("items/items.json")

if not (string.find(Tracker.ActiveVariantUID, "items_only")) then
	Tracker:AddMaps("maps/maps.json")
	Tracker:AddLocations("locations/locations.json")
	Tracker:AddLayouts("layouts/tracker.json")
else
	Tracker:AddLayouts("items_only/layouts/tracker.json")
end

Tracker:AddLayouts("layouts/broadcast.json")

if _VERSION == "Lua 5.3" then
    ScriptHost:LoadScript("scripts/autotracking.lua")
else    
    print("Auto-tracker is unsupported by your tracker version")
end