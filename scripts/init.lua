Tracker:AddItems("items/items.json")
if (string.find(Tracker.ActiveVariantUID, "upcoming")) then
	Tracker:AddMaps("maps/maps.json")
	Tracker:AddLocations("upcoming/locations/locations.json")
	Tracker:AddLayouts("layouts/tracker.json")
else	
if not (string.find(Tracker.ActiveVariantUID, "items_only")) then
	Tracker:AddMaps("maps/maps.json")
	Tracker:AddLocations("locations/locations.json")
	Tracker:AddLayouts("layouts/tracker.json")
else
	Tracker:AddLayouts("items_only/layouts/tracker.json")
end
end
Tracker:AddLayouts("layouts/broadcast.json")