function getTrackerClient()
  if PopVersion then
    return {PopTracker=true}
  end
  return {EmoTracker=true}
end

TrackerClient = getTrackerClient()

if TrackerClient.PopTracker then
  print("Detected PopTracker: " .. PopVersion)
else
  print("Assuming EmoTracker")
end

ScriptHost:LoadScript("scripts/logic.lua")

--
-- Adds components used by tracker for items, bosses, flags, etc.
--
function addComponents()
  -- NOTE: Tracker will prefix components automatically with variant name
  -- and prefer those, but if they don't exist, will fall back to
  -- using paths relative to pack root directory

  print("Adding Components...")

  -- NOTE: Load order matters because Tracker cannot handle
  -- forward references consistently, so must load things first before can reference
  Tracker:AddLayouts("layouts/components/items_grid.json")
  Tracker:AddLayouts("layouts/components/bosses_grid.json")
  Tracker:AddLayouts("layouts/components/flags_grid.json")
  Tracker:AddLayouts("layouts/components/extra_flags_grid.json")
  Tracker:AddLayouts("layouts/components/options_grid.json")
  Tracker:AddLayouts("layouts/components/settings_popup.json")
  Tracker:AddLayouts("layouts/components/bottom_dock.json")

end

--
-- Adds main tracker and broadcast layouts based on mode and variant.
--
function addTrackerLayouts()

  print("Adding Layouts...")

  Tracker:AddLayouts("layouts/capture.json")

  if itemsOnlyTracking() then
    Tracker:AddLayouts("items_only/layouts/tracker.json")
  else
    Tracker:AddLayouts("layouts/tracker.json")
  end

  Tracker:AddLayouts("layouts/broadcast.json")

end

-- Configure tracker
print("Configurating tracker...")
Tracker:AddItems("items/items.json")
Tracker:AddMaps("maps/maps.json")
Tracker:AddLocations("locations/locations.json")
addComponents()
addTrackerLayouts()

if _VERSION == "Lua 5.3" then
  print("Setting up autotracking...")
  ScriptHost:LoadScript("scripts/autotracking.lua")
else
  print("Auto-tracker is unsupported by your tracker version")
end
