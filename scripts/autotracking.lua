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

function autotracker_started()
    -- Invoked when the auto-tracker is activated/connected
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

  return string.find(Tracker.ActiveVariantUID, "items_only")

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
  if not itemsOnlyTracking() then
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
    end
  end
  
end

--
-- The Masamune is a key item that can show up in either the main inventory
-- or in Frog's weapon slot.  Acquiring the Masamune also removes the Bent Sword
-- and Bent Hilt from the player's inventory.  If the Masamune is found, this 
-- function is called to set all three items as acquired on the tracker.
--
function handleMasamune()

  masamune = Tracker:FindObjectForCode("masamune")
  bentHilt = Tracker:FindObjectForCode("benthilt")
  bentSword = Tracker:FindObjectForCode("bentsword")

  if not masamune.Owner.ModifiedByUser then
    masamune.Active = true;
  end
  
  if not bentHilt.Owner.ModifiedByUser then
    bentHilt.Active = true;
  end
  
  if not bentSword.Owner.ModifiedByUser then
    bentSword.Active = true;
  end
  
end

--
-- Handle the moonstone/sunstone.
-- This is a progressive item and is handled differently 
-- from the other key items.
--
function handleMoonstone(name) 

  moonstone = Tracker:FindObjectForCode("moonstone")
  if name == "moonstone" then
    moonstone.CurrentStage = math.max(1, moonstone.CurrentStage)
  elseif name == "sunstone" then
    moonstone.CurrentStage = 2
  end
  
end

--
-- Handle the Taban's Gift event processing.
-- The Taban's Gift event doesn't have a single memory flag.
-- After taking the Heckran's Cave Whirlpool, 1F0 is set high. 
-- This triggers Taban to give the player an item. after taking
-- the item it goes back low.  
--
function handleTabansGift(segment)

  heckran = segment:ReadUInt8(0x7F01A3) & 0x08 ~= 0
  taban = segment:ReadUInt8(0x7F01F0) & 0x01 ~= 0
  
  if heckran and not taban then
    -- Heckran is dead and Taban's gift has been claimed
    item = Tracker:FindObjectForCode("@Lucca's House/Taban's Gift")
    if not item.Owner.ModifiedByUser then
      item.AvailableChestCount = 0
    end
  end
  
end

--
-- Handle items that are lost on turn-in.  Address, flag, and
-- segment are used to determine if the turn-in event has occured.
--
function handleItemTurnin(name, segment, address, flag)

  usedItem = segment:ReadUInt8(address)
  if (usedItem & flag) ~= 0 then
    local trackerItem = Tracker:FindObjectForCode(name)
    if trackerItem then
      trackerItem.Active = true
    end
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
KEY_ITEMS = {
  {value=0x3D, name="masamune", callback=handleMasamune},
  {value=0x50, name="bentsword"},
  {value=0x51, name="benthilt"},
  {value=0xB3, name="heromedal"},
  {value=0xB8, name="roboribbon"},
  {value=0xD6, name="pendant"},
  {value=0xD7, name="gatekey"},
  {value=0xD8, name="prismshard"},
  {value=0xD9, name="ctrigger"},
  {value=0xDA, name="tools"},
  {value=0xDB, name="jerky"},
  {value=0xDC, name="dreamstone"},
  {value=0xDE, name="moonstone", callback=handleMoonstone},
  {value=0xDF, name="sunstone", callback=handleMoonstone},
  {value=0xE0, name="rubyknife"},
  {value=0xE2, name="clone"},
  {value=0xE3, name="tomapop"}
}

--
-- Update key items from the inventory memory segment.
-- Some items provide callbacks for special handling.  All other
-- items just get set to Active on the tracker.
-- 
-- NOTE: Magic is tracked with events and bosses.  The marker for
--       magic shows up with key items on the tracker, but the 
--       "Met Spekkio" memory flag is with the rest of the event flags.
--
function updateItemsFromInventory(segment)

  -- Loop through the inventory, update key items
  for i=0,0xF1 do
    local item = segment:ReadUInt8(0x7E2400 + i)
    -- Loop through the table of key items
    for k,v in pairs(KEY_ITEMS) do
      if item == v.value then
        local trackerItem = Tracker:FindObjectForCode(v.name)
        if trackerItem then
          if v.callback then
            v.callback(v.name)
          else
            trackerItem.Active = true
          end
        else
          printDebug("Can't find key item: ", v.name)
        end -- end if trackerItem
      end -- end if item == v.value
    end -- end key item loop
  end -- end inventory loop
  
end

--
-- Update events and boss kills
--
function updateEventsAndBosses(segment) 

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
  updateBoss("rusttyranoboss", segment, 0x7F01D2, 0x30)
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
    updateEvent("@Sun Keep/Charge the Moonstone", segment, 0x7F013A, 0x40)
    updateEvent("@Reptite Lair/Defeat Nizbel", segment, 0x7F0105, 0x20)
    updateEvent("@Dactyl Nest/Friend to the Dactyls", segment, 0x7F0160, 0x10)
    
    -- Dark Ages
    updateEvent("@Mt Woe/Defeat Giga Gaia", segment, 0x7F0100, 0x20) -- same as boss flag
    
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
    
    -- Future
    updateEvent("@Proto Dome/Fix Robo", segment, 0x7F00F3, 0x02)
    updateEvent("@Arris Dome/Activate the Computer", segment, 0x7F00A4, 0x01)
    updateEvent("@Sun Palace/Moon Stone", segment, 0x7F013A, 0x02) -- same as Son of Sun
    updateEvent("@Geno Dome/Defeat Mother Brain", segment, 0x7F013B, 0x10) -- Same as Mother Brain 
  end -- end event tracking
  
  -- End of Time
  -- Track magic here. This is determined by whether or not the player
  -- has spoken with Spekkio for the first time.
  spekkioByte = segment:ReadUInt8(0x7F00E1)
  if (spekkioByte & 0x02) ~= 0 then
    local magic = Tracker:FindObjectForCode("magic")
    if magic then
      magic.Active = true
    end
  end
  
  -- miscellaneous event checks for items that are consumed on turn in
  handleItemTurnin("tomapop", segment, 0x7F01A3, 0x80)
  handleItemTurnin("jerky", segment, 0x7F01D2, 0x04)
  handleItemTurnin("tools", segment, 0x7F019E, 0x40)
  
end

--
-- Toggle a character on when he/she joins the party
--
function toggleCharacter(name)

  character = Tracker:FindObjectForCode(name)
  
  if character then
    if not character.Owner.ModifiedByUser then
      character.Active = true
    end
  else
    printDebug("Unable to find character: " .. name)
  end

end

--
-- Read the PC and PC Reserve slots to determine which
-- characters have been acquired.
--
function updateParty(segment)

  -- Character IDs:
  -- 0 Crono
  -- 1 Nadia (Marle)
  -- 2 Lucca
  -- 3 R66-Y (Robo)
  -- 4 Glenn (Frog)
  -- 5 Ayla
  -- 6 Janus (Magus)

  -- On the main title screen all PC slots are 0 (Crono's ID)
  -- If slot 1 and slot2 are 0, the game hasn't started yet, so don't track PCs
  if segment:ReadUInt8(0x7E2980) == 0 and segment:ReadUInt8(0x7E2981) == 0 then
    return
  end
  
  -- Loop through the character slots
  -- NOTE: items.jason uses characters' real names, not defaults.
  for i=0, 8 do
    charId = segment:ReadUInt8(0x7E2980 + i)
    if charId == 0 then
      toggleCharacter("Crono")
    elseif charId == 1 then
      toggleCharacter("Nadia")
    elseif charId == 2 then
      toggleCharacter("Lucca")
    elseif charId == 3 then
      toggleCharacter("R66-Y")
    elseif charId == 4 then
      toggleCharacter("Glenn")
    elseif charId == 5 then
      toggleCharacter("Ayla")
    elseif charId == 6 then
      toggleCharacter("Janus")
    end
  end
  
end

--
-- Check Frog's inventory for the Masamune key item.
--
function updateMasamune(segment)

  if segment:ReadUInt8(0x7E2769) == 0x3D then
    handleMasamune()
  end
  
end

--
-- Check Robo's inventory for Robo's Ribbon key item.
--
function updateRoboRibbon(segment)

  if segment:ReadUInt8(0x7E271A) == 0xB8 then
    local trackerItem = Tracker:FindObjectForCode("roboribbon")
    if not trackerItem.Owner.ModifiedByUser then
      trackerItem.Active = true
    end
  end
  
end


printDebug("Adding memory watches")
ScriptHost:AddMemoryWatch("Inventory", 0x7E2400, 0xF2, updateItemsFromInventory)
ScriptHost:AddMemoryWatch("Party", 0x7E2980, 9, updateParty)
ScriptHost:AddMemoryWatch("Events", 0x7F0000, 512, updateEventsAndBosses)
ScriptHost:AddMemoryWatch("Masamune", 0x7E2769, 1, updateMasamune)
ScriptHost:AddMemoryWatch("RoboRibbon", 0x7E271A, 1, updateRoboRibbon)

