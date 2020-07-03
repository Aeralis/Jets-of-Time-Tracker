-- Configuration --------------------------------------
AUTOTRACKER_ENABLE_DEBUG_LOGGING = false
-------------------------------------------------------

print("")
print("Active Auto-Tracker Configuration")
print("---------------------------------------------------------------------")
if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
    print("Enable Debug Logging:        ", "true")
end
print("---------------------------------------------------------------------")
print("")

--
-- Script variables
--
HAS_MASAMUNE = false

--
-- Invoked when the auto-tracker is activated/connected
--
function autotracker_started()
    
end

--
-- Print a debug message if debug logging is enabled
--
function printDebug(message)

  if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
    print(message)
  end

end

--
-- Check if the tracker variant is set to Items Only.
--
function itemsOnlyTracking()

  return string.find(Tracker.ActiveVariantUID, "items")

end

--
-- Check if the tracker is in Lost Worlds mode
--
function lostWorldsMode()

  return string.find(Tracker.ActiveVariantUID, "lost_world")

end

--
-- Check if the game is currently running
--
function inGame()

  -- Check the first 2 character slots.  If both are 0 (Crono's ID) then the game 
  -- hasn't started yet or has been reset.
  return not (AutoTracker:ReadU8(0x7E2980) == 0 and AutoTracker:ReadU8(0x7E2981) == 0) 

 end

--
-- Handle toggling the green "Go" button on the tracker.  "Go Mode" is
-- achieved when the player has acquired the correct items and/or characters
-- to beat the game.  There are three different paths that can be taken:
--   - Through 65 Million BC (Gate Key, Dream Stone, Ruby Knife)
--   - Through Magus' Castle 600AD (Frog, Repaired Masamune, Ruby Knife)
--   - Through Death Peak/Black Omen (Access to 2300AD, C. Trigger, Clone)
--
-- In Lost Worlds mode, there are two paths:
--   - Through Death Peak/Black Omen (C. Trigger and Clone)
--   - Through the Ocean Palace (Ruby Knife and Dreamstone (Black Tyrano defeated))
--
function handleGoMode()

  local gateKey = Tracker:FindObjectForCode("gatekey")
  local dreamStone = Tracker:FindObjectForCode("dreamstone")
  local rubyKnife = Tracker:FindObjectForCode("rubyknife")
  local frog = Tracker:FindObjectForCode("glenn")
  local masamune = Tracker:FindObjectForCode("masamune")
  local pendant = Tracker:FindObjectForCode("pendant")
  local cTrigger = Tracker:FindObjectForCode("ctrigger")
  local clone = Tracker:FindObjectForCode("clone")
  
  local goMode = false
  if lostWorldsMode() then
    goMode = 
	    (dreamStone.Active and rubyKnife.Active) or -- has ruby knife and can get to Black Tyrano
		  (cTrigger.Active and clone.Active) -- Death Peak -> Black Omen
  else
    goMode = 
      (gateKey.Active and dreamStone.Active and rubyKnife.Active) or -- 65 million BC -> 12000 BC -> Ocean Palace
      (frog.Active and masamune.Active and rubyKnife.Active) or -- Magus' Castle -> 12000 BC -> Ocean Palace
      (pendant.Active and cTrigger.Active and clone.Active) -- Death Peak -> Black Omen
  end  
  local goButton = Tracker:FindObjectForCode("gomode")
  goButton.Active = goMode

end

--
-- Update an event from an address and flag.
--
function updateEvent(name, segment, address, flag)

  local trackerItem = Tracker:FindObjectForCode(name)
  
  if trackerItem then
    if trackerItem.Owner.ModifiedByUser then
      -- early return if the item has been modified by the user. 
      return
    end
  
    local value = segment:ReadUInt8(address)
    if (value & flag) ~= 0 then
      trackerItem.AvailableChestCount = 0
    else
      trackerItem.AvailableChestCount = 1
    end
  else
    printDebug("Update Event: Unable to find tracker item: " .. name)  
  end
  
end

--
-- Update a boss from an address and flag
--
function updateBoss(name, segment, address, flag)

  local trackerItem = Tracker:FindObjectForCode(name)
  if trackerItem then
    if trackerItem.Owner.ModifiedByUser then
      -- early return if the item has been modified by the user. 
      return
    end
    
    local value = segment:ReadUInt8(address)
    trackerItem.Active = ((value & flag) ~= 0)
  else
    printDebug("Update Boss: Unable to find tracker item: " .. name)  
  end
  
end

--
-- Handle the Zenan Bridge flags (cook's item and Zombor)
--
-- The flag that goes high when you get the item from the Guardia cook
-- goes back low after you beat Zombor. Check for this case here so that
-- reloaded saves don't incorrectly track the cook's item.
--
function handleZenanBridge(segment)

  local zombor = Tracker:FindObjectForCode("zomborboss")
  -- NOTE: This marks complete when the battle starts, not when Zombor dies
  --       There isn't a specific memory flag for Zombor's death
  updateBoss("zomborboss", segment, 0x7F0101, 0x02)
  
  -- If Zombor was defeated then mark the cook's item as active regardless
  -- of the flag's state.  Only track this if the tracker is not set to 
  -- "Items Only" tracking mode.
  if not itemsOnlyTracking() and not lostWorldsMode() then
    if zombor.Active then
      local cookItem = Tracker:FindObjectForCode("@Zenan Bridge/Cook's Rations")
      if not cookItem.Owner.ModifiedByUser then
        cookItem.AvailableChestCount = 0
      end
    else
      updateEvent("@Zenan Bridge/Cook's Rations", segment, 0x7F00A9, 0x10)
    end
  end
  
end

--
-- The Melchior's Refinements key item doesn't have a simple
-- memory flag. Instead, the bit goes high when you talk to 
-- the king after the trial and Melchior shows up, then goes
-- back low after you talk to Melchior and obtain the key item.
--
-- Assume that if Yakra XIII is dead and the Melchior bit is
-- low then the key item has been acquired.
--
function handleMelchiorRefinements(segment)
  if itemsOnlyTracking() then
    return
  end

  local yakraxiii = Tracker:FindObjectForCode("yakraxiiiboss")
  local melchior = Tracker:FindObjectForCode("@Guardia Castle Present/Melchior's Refinements")
  
  if melchior.Owner.ModifiedByUser or itemsOnlyTracking() then
    -- Break out early if the item has been modified by the user
    return
  end
  
  if yakraxiii.Active then
    local value = segment:ReadUInt8(0x7F006D)
    if (value & 0x10) == 0 then
      melchior.AvailableChestCount = 0
    else
      melchior.AvailableChestCount = 1
    end
  else
    melchior.AvailableChestCount = 1
  end
  
end

--
-- The Masamune is a key item that can show up in either the main inventory
-- or in Frog's weapon slot.  Acquiring the Masamune also removes the Bent Sword
-- and Bent Hilt from the player's inventory.  If the Masamune is found, this 
-- function will set all three items as acquired on the tracker.
--
function handleMasamune(keyItem)

  if keyItem.name == "masamune" then
    local frogWeapon = AutoTracker:ReadU8(0x7E2769, 0)
    HAS_MASAMUNE = (frogWeapon == 0x3D) or (frogWeapon == 0x42) or keyItem.found
  
    masamune = Tracker:FindObjectForCode("masamune")
    if not masamune.Owner.ModifiedByUser then
      masamune.Active = HAS_MASAMUNE
    end
  else
    trackerItem = Tracker:FindObjectForCode(keyItem.name)
    if not trackerItem.Owner.ModifiedByUser then
      trackerItem.Active = keyItem.found or HAS_MASAMUNE
    end
  end

end

--
-- Handle the moonstone/sunstone.
-- This is a progressive item and is handled differently 
-- from the other key items.
--
function handleMoonstone(keyItem) 

  moonstone = Tracker:FindObjectForCode("moonstone")
  currentStage = moonstone.CurrentStage
  
  if keyItem.name == "moonstone" then
    if keyItem.found then
      moonstone.CurrentStage = 1
    elseif currentStage == 1 then
      -- Reset only works if sunstone comes before moonstone in the
      -- key items table.  Do not rearrange the table.
      moonstone.CurrentStage = 0
    end
  elseif keyItem.name == "sunstone" then
    if keyItem.found then
      moonstone.CurrentStage = 2
    elseif currentStage == 2 then
      moonstone.CurrentStage = 0
    end
  end
  
end

--
-- Handle items that can also show up in character's equipment slots.
-- This includes the Hero Medal and Robo's Ribbon. Masamune is handled
-- separately since it is more complicated.
--
function handleEquippableItem(keyItem)

  local equipmentSlot = AutoTracker:ReadU8(keyItem.address, 0)
  local itemOwned = keyItem.found or equipmentSlot == keyItem.value
  
  local trackerItem = Tracker:FindObjectForCode(keyItem.name)  
  if trackerItem and not trackerItem.Owner.ModifiedByUser then
    trackerItem.Active = itemOwned
  end

end

--
-- Handle the Taban's Gift event processing.
-- The Taban's Gift event doesn't have a single memory flag.
-- After taking the Heckran's Cave Whirlpool, 1F0 is set high. 
-- This triggers Taban to give the player an item. After taking
-- the item it goes back low.  
--
function handleTabansGift(segment)

  local item = Tracker:FindObjectForCode("@Lucca's House/Taban's Gift")
  if item.Owner.ModifiedByUser then
    return
  end

  local tookWhirlpool = segment:ReadUInt8(0x7F01A3) & 0x08 ~= 0
  local taban = segment:ReadUInt8(0x7F01F0) & 0x01 ~= 0

  
  if tookWhirlpool and not taban then
    -- Took the whirlpool and Taban's gift has been claimed
    item.AvailableChestCount = 0
  else
    item.AvailableChestCount = 1  
  end
  
end

--
-- Handle items that are lost on turn-in.  Address, flag, and
-- segment are used to determine if the turn-in event has occured.
--
function handleItemTurnin(keyItem)

  usedItem = (AutoTracker:ReadU8(keyItem.address) & keyItem.flag) ~= 0
  itemFound = keyItem.found or usedItem
  
  local trackerItem = Tracker:FindObjectForCode(keyItem.name)
  if trackerItem and not trackerItem.Owner.ModifiedByUser then
    trackerItem.Active = itemFound
  end

end

--
-- table of key item memory values and names as 
-- registered with the tracker via items.json.
-- Some items have an additional callback field.
-- This is a callback function for special processing.
--
-- NOTE: Key items must be defined after the callback
--       functions are defined or they won't trigger properly.
--
-- NOTE: The Masamune has 2 distinct item IDs.  It starts out as 0x3D and then
--       changes to 0x42 after being powered up in the ruins in 1000AD.  
--
KEY_ITEMS = {
  {value={0x3D, 0x42}, name="masamune", callback=handleMasamune},
  {value=0x50, name="bentsword", callback=handleMasamune},
  {value=0x51, name="benthilt", callback=handleMasamune},
  {value=0xB3, name="heromedal", callback=handleEquippableItem, address=0x7E276A},
  {value=0xB8, name="roboribbon", callback=handleEquippableItem, address=0x7E271A},
  {value=0xD6, name="pendant"},
  {value=0xD7, name="gatekey"},
  {value=0xD8, name="prismshard"},
  {value=0xD9, name="ctrigger"},
  {value=0xDA, name="tools", callback=handleItemTurnin, address=0x7F019E, flag=0x40},
  {value=0xDB, name="jerky", callback=handleItemTurnin, address=0x7F01D2, flag=0x04},
  {value=0xDC, name="dreamstone"},
  {value=0xDF, name="sunstone", callback=handleMoonstone},
  {value=0xDE, name="moonstone", callback=handleMoonstone},
  {value=0xE0, name="rubyknife"},
  {value=0xE2, name="clone"},
  {value=0xE3, name="tomapop", callback=handleItemTurnin, address=0x7F01A3, flag=0x80}
}

--
-- Update key items from the inventory memory segment.
-- Some items provide callbacks for special handling.  All other
-- items just get directly toggled on the tracker.  
-- 
-- NOTE: Magic is tracked with events and bosses.  The marker for
--       magic shows up with key items on the tracker, but the 
--       "Met Spekkio" memory flag is with the rest of the event flags.
--
function updateItemsFromInventory(segment)

  -- Nothing to track if we're not actively in the game
  if not inGame() then
    return
  end

  -- Reset all items to "not found"
  for k,v in pairs(KEY_ITEMS) do
    v.found = false
  end

  -- Loop through the inventory, determine which key items the player has found
  -- NOTE: The Masamune has 2 distinct item IDs.  These IDs are stored as a table
  --       so that both can be checked here at the same time.
  for i=0,0xF1 do
    local item = segment:ReadUInt8(0x7E2400 + i)
    -- Loop through the table of key items and see if the current 
    -- inventory slot maches any of them
    for k,v in pairs(KEY_ITEMS) do
      if type(v.value) == "number" then
        if item == v.value then
          v.found = true
        end
      elseif type(v.value) == "table" then
        -- Loop through possible IDs for items with more than one
        for k2, v2 in pairs(v.value) do
          if item == v2 then
            v.found = true
          end
        end
      end
    end -- end key item loop
  end -- end inventory loop
  
  
  -- Loop the key items and toggle them based on whether or not they were found
  for k,v in pairs(KEY_ITEMS) do
    if v.callback then
      v.callback(v)
    else
      local trackerItem = Tracker:FindObjectForCode(v.name)
      if trackerItem and not trackerItem.Owner.ModifiedByUser then
        trackerItem.Active = v.found
      else
        printDebug("Update Items: Unable to find tracker item: " .. name)
      end
    end
  end
  
  -- Check if this puts the player in Go Mode
  handleGoMode()
  
end

--
-- Update events and boss kills
--
function updateEventsAndBosses(segment) 

  -- Nothing to track if we're not actively in the game
  if not inGame() then
    return
  end

  -- Don't autotrack during gate travel:
  -- During a gate transition the memory flags holding the event
  -- and boss data are overwritten.  After the animation, memory 
  -- goes back to normal.
  s1 = segment:ReadUInt16(0x7F0000)
  s2 = segment:ReadUInt16(0x7F0002)
  if s1 == 0x4140 and s2 == 0x4342 then
    return
  end

  -- Handle boss tracking.
  -- This is done in both Map Tracker and Item Tracker variants
  
  -- Prehistory
  updateBoss("nizbelboss", segment, 0x7F0105, 0x20)
  updateBoss("blacktyranoboss", segment, 0x7F00EC, 0x80)

  -- Dark Ages
  updateBoss("gigagaiaboss", segment, 0x7F0100, 0x20)
  updateBoss("golemboss", segment, 0x7F0105, 0x80)
  
  -- Middle Ages
  updateBoss("yakraboss", segment, 0x7F000D, 0x01)
  updateBoss("masamuneboss", segment, 0x7F00F3, 0x20)
  updateBoss("retiniteboss", segment, 0x7F01AD, 0x04)
  updateBoss("rusttyranoboss", segment, 0x7F01D2, 0x40)
  updateBoss("magusboss", segment, 0x7F01FF, 0x04)
  handleZenanBridge(segment)
  
  -- Present
  updateBoss("heckranboss", segment, 0x7F01A3, 0x08)
  updateBoss("dragontankboss", segment, 0x7F0198, 0x08)
  updateBoss("yakraxiiiboss", segment, 0x7F0050, 0x40)
  
  -- Future
  updateBoss("guardianboss", segment, 0x7F00EC, 0x01)
  updateBoss("rseriesboss", segment, 0x7F0103, 0x40)
  -- Bit 1 goes high when the fight starts, bit 2 goes high when 
  -- the item is collected after the fight
  updateBoss("sonofsunboss", segment, 0x7F013A, 0x02)
  updateBoss("motherbrainboss", segment, 0x7F013B, 0x10)
  -- This flag checks for completion of Death Peak rather than defeating Zeal.
  -- The boss marker is listed under Death Peak and is required to mark it
  -- as completed on the tracker.
  updateBoss("zealboss", segment, 0x7F0067, 0x01)
  
  
  -- Only track events in the "Map Tracker" variant
  if not itemsOnlyTracking() then
    -- Prehistory
    updateEvent("@Reptite Lair/Defeat Nizbel", segment, 0x7F0105, 0x20)
    updateEvent("@Dactyl Nest/Friend to the Dactyls", segment, 0x7F0160, 0x10)
    
    -- Dark Ages
    updateEvent("@Mt Woe/Defeat Giga Gaia", segment, 0x7F0100, 0x20) -- same as boss flag
   
	-- Don't check these events in Lost Worlds mode, they don't exist.
    if not lostWorldsMode() then	
      -- Moonstone is the only prehistory event that is not part of the Lost Worlds mode.
      updateEvent("@Sun Keep/Charge the Moonstone", segment, 0x7F013A, 0x40)
    
      -- Middle Ages
      updateEvent("@Manoria Cathedral/Saved by Frog", segment, 0x7F0100, 0x01)
      updateEvent("@Guardia Castle Past/Rescue Marle", segment, 0x7F00A1, 0x04)
      updateEvent("@Denadoro Mts/Defeat Masamune", segment, 0x7F0102, 0x02)
      updateEvent("@Fiona's Villa/Replant the Forest", segment, 0x7F007C, 0x80)
      updateEvent("@Cursed Woods/Burrow Left Chest", segment, 0x7F0106, 0x04)
      updateEvent("@Cursed Woods/Return the Masamune", segment, 0x7F00FF, 0x20)
      -- NOTE: Rainbow Shell flag is set after warping out of the cave
      --       after interacting with the Rainbow Shell
      updateEvent("@Giant's Claw/Rainbow Shell", segment, 0x7F00A9, 0x80)
    
      -- Present
      updateEvent("@Snail Stop/Buy for 9900G", segment, 0x7F01D0, 0x10)
      updateEvent("@Choras Inn/Borrow Carpenter's Tools", segment, 0x7F019E, 0x80)
      updateEvent("@Melchior's Hut/Reforge the Masamune", segment, 0x7F0103, 0x02)
      -- The trial is a guess. Two flags go high here and I just picked one arbitrarily
      updateEvent("@Guardia Castle Present/King Guardia's Trial", segment, 0x7F00A2, 0x80)
      handleMelchiorRefinements(segment)
      handleTabansGift(segment)
    end
    
    -- Future
    updateEvent("@Proto Dome/Fix Robo", segment, 0x7F00F3, 0x02)
    updateEvent("@Arris Dome/Activate the Computer", segment, 0x7F00A4, 0x01)
    updateEvent("@Sun Palace/Moon Stone", segment, 0x7F013A, 0x02) -- same as Son of Sun
    updateEvent("@Geno Dome/Defeat Mother Brain", segment, 0x7F013B, 0x10) -- Same as Mother Brain 
  end -- end event tracking
  
  -- End of Time
  -- Track magic here. This is determined by whether or not any character 
  -- except Magus is capable of using magic. This allows magic detection to 
  -- work in Lost Worlds mode, where characters don't need to meet Spekkio.
  local magic = Tracker:FindObjectForCode("magic")
  local spekkioByte = segment:ReadUInt8(0x7F01E0)
  if not magic.Owner.ModifiedByUser then
    magic.Active = (spekkioByte & 0x3F) ~= 0
  end
  
end

--
-- Toggle a character based on whether or not he/she was found in the party.
--
function toggleCharacter(name, found)

  character = Tracker:FindObjectForCode(name)
  if character then
    if not character.Owner.ModifiedByUser then
      character.Active = found
    end
  else
    printDebug("Unable to find character: " .. name)
  end

end

--
-- Check to see if the player is in the trial sequence.
-- During Crono's trial sequence in 1000AD in Guardia Castle the
-- two characters in slots 2 and 3 are removed from the party entirely.  
-- This function is used to pause character tracking during the trial to prevent
-- the two characters from being unchecked from the tracker.
--
-- Restart tracking after the characters have rejoined the party.
-- NOTE: The byte used to determine if the characters have rejoined seems to count
--       up as the story section progresses.
--   0x01 - Skipped in the randomizer, maybe when the trial is going on?
--   0x02 - Character has been led away to jail
--   0x03 - Party joins back up after the escape
--   0x04 - Party takes the portal to the future
--       
function inTrialSequence()

  local trialStarted = (AutoTracker:ReadU8(0x7F0056) & 0x01) ~= 0
  local charsRejoined =(AutoTracker:ReadU8(0x7F0104) & 0x07) > 2 
  
  return trialStarted and not charsRejoined

end

--
-- Read the PC and PC Reserve slots to determine which
-- characters have been acquired.
--
function updateParty(segment)

  -- Don't track if we're not actively in game
  -- Don't track the party if the player is in the Trial sequence
  if not inGame() or inTrialSequence() then
    return
  end

  -- Character IDs:
  -- NOTE: items.jason uses characters' real names, not defaults.
  -- 0 Crono
  -- 1 Nadia (Marle)
  -- 2 Lucca
  -- 3 R66-Y (Robo)
  -- 4 Glenn (Frog)
  -- 5 Ayla
  -- 6 Janus (Magus)

  charsFound = 0
  -- Loop through the character slots and mark off which ones are found
  -- 0x80 is the "empty" value for a slot
  for i=0, 8 do
    charId = segment:ReadUInt8(0x7E2980 + i)
    if charId ~= 0x80 then
      charsFound = charsFound | (1 << charId)
    end
  end

  -- Toggle tracker icons based on what characters were found
  toggleCharacter("Crono", (charsFound & 0x01 ~= 0))
  toggleCharacter("Nadia", (charsFound & 0x02 ~= 0))
  toggleCharacter("Lucca", (charsFound & 0x04 ~= 0))
  toggleCharacter("R66-Y", (charsFound & 0x08 ~= 0))
  toggleCharacter("Glenn", (charsFound & 0x10 ~= 0))
  toggleCharacter("Ayla",  (charsFound & 0x20 ~= 0))
  toggleCharacter("Janus", (charsFound & 0x40 ~= 0))
  
  -- Check if this puts the player in Go Mode
  handleGoMode()
  
end

--
-- Set up memory watches on memory used for autotracking.
--
printDebug("Adding memory watches")
ScriptHost:AddMemoryWatch("Party", 0x7E2980, 9, updateParty)
ScriptHost:AddMemoryWatch("Events", 0x7F0000, 512, updateEventsAndBosses)
ScriptHost:AddMemoryWatch("Inventory", 0x7E2400, 0xF2, updateItemsFromInventory)

