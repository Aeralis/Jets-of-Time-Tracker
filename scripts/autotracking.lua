ScriptHost:LoadScript("scripts/logic.lua")

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
CHECK_COUNTERS = {chests = 0, sealed_chests = 0, base_checks = 0}

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
--   - Through Magus' Castle 600AD (Frog, Repaired Masamune)
--   - Through Death Peak/Black Omen (Access to 2300AD, C. Trigger, Clone)
--
--  NOTE: The Ruby Knife is no longer required when accessing Ocean Palace
--        via Magus' Castle as of version 3.0 of the randomizer.
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
  local magus = Tracker:FindObjectForCode("janus")
  local hilt = Tracker:FindObjectForCode("benthilt")
  local blade = Tracker:FindObjectForCode("bentsword")
  local masa2 = Tracker:FindObjectForCode("grandleon")
  local pendant = Tracker:FindObjectForCode("pendant")
  local cTrigger = Tracker:FindObjectForCode("ctrigger")
  local clone = Tracker:FindObjectForCode("clone")

  local goMode
  if lostWorldsMode() then
    goMode =
      (dreamStone.Active and rubyKnife.Active) or -- has ruby knife and can get to Black Tyrano
      (cTrigger.Active and clone.Active) -- Death Peak -> Black Omen
  elseif legacyOfCyrusMode() then
    goMode = frog.Active and magus.Active and hilt.Active and blade.Active and masa2.Active
  else
    goMode =
      (gateKey.Active and dreamStone.Active and rubyKnife.Active) or -- 65 million BC -> 12000 BC -> Ocean Palace
      (frog.Active and hilt.Active and blade.Active) or -- Magus' Castle -> 12000 BC -> Ocean Palace
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
  local completed = 0

  if trackerItem then
    if trackerItem.Owner.ModifiedByUser then
      -- early return if the item has been modified by the user.
      return 0
    end

    local value = segment:ReadUInt8(address)
    if (value & flag) ~= 0 then
      trackerItem.AvailableChestCount = 0
      completed = 1
    else
      trackerItem.AvailableChestCount = 1
    end
  else
    printDebug("Update Event: Unable to find tracker item: " .. name)
  end

  return completed

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
  local completed = 0

  -- If Zombor was defeated then mark the cook's item as active regardless
  -- of the flag's state.  Only track this if the tracker is not set to
  -- "Items Only" tracking mode.
  if not itemsOnlyTracking() and not lostWorldsMode() then
    if zombor.Active then
      local cookItem = Tracker:FindObjectForCode("@Zenan Bridge/Cook's Rations")
      if not cookItem.Owner.ModifiedByUser then
        cookItem.AvailableChestCount = 0
        completed = 1
      end
    else
      completed = updateEvent("@Zenan Bridge/Cook's Rations", segment, 0x7F00A9, 0x10)
    end
  end

  return completed

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
  if itemsOnlyTracking() or legacyOfCyrusMode() then
    return 0
  end

  local yakraxiii = Tracker:FindObjectForCode("yakraxiiiboss")
  local melchior = Tracker:FindObjectForCode("@Guardia Castle Present/Melchior's Refinements")
  local completed = 0

  if melchior.Owner.ModifiedByUser or itemsOnlyTracking() then
    -- Break out early if the item has been modified by the user
    return
  end

  if yakraxiii.Active then
    local value = segment:ReadUInt8(0x7F006D)
    if (value & 0x10) == 0 then
      melchior.AvailableChestCount = 0
      completed = 1
    else
      melchior.AvailableChestCount = 1
    end
  else
    melchior.AvailableChestCount = 1
  end

  return completed

end

--
-- Handle the moonstone/sunstone.
-- This is a progressive item and is handled differently
-- from the other key items.
--
function handleMoonstone(keyItem)

  moonstone = Tracker:FindObjectForCode("moonstone")
  currentStage = moonstone.CurrentStage

  -- Special handling for when the moonstone has been left in sun keep
  -- but hasn't been picked up yet.
  local moonstoneState = AutoTracker:ReadU8(0x7F013A, 0)
  if ((moonstoneState & 0x04) ~= 0 and
      (moonstoneState & 0x40) == 0) then
    -- Moonstone was dropped off but not picked up
    -- Set moonstone active on the tracker so it doens't get cleared
    moonstone.CurrentStage = 1
    return
  end

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
-- Handle items that are lost on turn-in.  Address, flag attributes
-- are used to determine if the turn-in event has occured.
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
-- Values can be specified as a scalar number or as a table with multiple
-- item IDs.  This was used to track both forms of the Masamune before
-- the Grand Leon change that split them into separate key items.
--
-- NOTE: Key items must be defined after the callback
--       functions are defined or they won't trigger properly.
--
-- NOTE: The Ruby Knife is removed from the inventory when you reach the Mammon Machine
--       at the end of Ocean Palace.  There wasn't a convenient memory flag for that
--       event, so instead we're checking to see if the sealed door in Zeal Palace has
--       been opened to meet the turn-in condition.
--
-- TODO: The sealed door to Ocean Palace was changed.  When going through Magus' Castle
--       the Ruby Knife isn't required anymore.  Check to see how we handle that case now.
--       I'm guessing the item turnin logic will cause it to be flagged as collected even
--       if it wasn't once the door is opened.
--
--
KEY_ITEMS = {
  {value=0x50, name="bentsword", callback=handleItemTurnin, address=0x7F0103, flag=0x02},
  {value=0x51, name="benthilt", callback=handleItemTurnin, address=0x7F0103, flag=0x02},
  {value=0xB3, name="heromedal", equipable=true, offset=0x2A},
  {value=0xB8, name="roboribbon", equipable=true, offset=0x2A},
  {value=0xD6, name="pendant"},
  {value=0xD7, name="gatekey"},
  {value=0xD8, name="prismshard"},
  {value=0xD9, name="ctrigger"},
  {value=0x42, name="grandleon", equipable=true, offset=0x29},
  {value=0xDA, name="tools", callback=handleItemTurnin, address=0x7F019E, flag=0x40},
  {value=0xDB, name="jerky", callback=handleItemTurnin, address=0x7F01D2, flag=0x04},
  {value=0xDC, name="dreamstone"},
  {value=0xDF, name="sunstone", callback=handleMoonstone},
  {value=0xDE, name="moonstone", callback=handleMoonstone},
  {value=0xE0, name="rubyknife", callback=handleItemTurnin, address=0x7F00F4, flag=0x80},
  {value=0xE2, name="clone"},
  {value=0xE3, name="tomapop", callback=handleItemTurnin, address=0x7F01A3, flag=0x80},
  {value=0xE9, name="jetsoftime", callback=handleItemTurnin, address=0x7F00BA, flag=0x80}
}

--
-- Update key items based on if found in inventory or equipped.
function updateKeyItems()

  -- Loop the key items and toggle them based on whether or not they were found
  for _,v in pairs(KEY_ITEMS) do
    if v.callback then
      v.callback(v)
    else
      local trackerItem = Tracker:FindObjectForCode(v.name)
      if trackerItem and not trackerItem.Owner.ModifiedByUser then
        trackerItem.Active = v.found or v.equipped
      else
        printDebug("Update Items: Unable to find tracker item: " .. name)
      end
    end
  end

  -- Check if this puts the player in Go Mode
  handleGoMode()

end

--
-- Update key items from the equipment memory segment.
-- Handles items that can also show up in character's equipment slots.
-- This includes the Hero Medal, Robo's Ribbon, and Grand Leon.
-- Masamune is handled separately based on reforging with Melchior.

function updateItemsFromEquipment(segment)

  -- Nothing to track if we're not actively in the game
  if not inGame() then
    return
  end

  -- Reset all items to "not equipped"
  for _,v in pairs(KEY_ITEMS) do
    v.equipped = false
  end

  -- Loop through character equipment for equipable items
  for _,v in pairs(KEY_ITEMS) do
    if v.equipable then
      -- to support Duplicate characters, need to check each character
      for pc=0,6 do
        local address = 0x7E2600 + 0x50*pc + v.offset
        local equipmentSlot = segment:ReadUInt8(address)
        if equipmentSlot == v.value then
          v.equipped = true
          break
        end
      end
    end
  end

  updateKeyItems()

end

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
  for _,v in pairs(KEY_ITEMS) do
    v.found = false
  end

  -- Loop through the inventory, determine which key items the player has found
  for i=0,0xF1 do
    local item = segment:ReadUInt8(0x7E2400 + i)
    -- Loop through the table of key items and see if the current
    -- inventory slot maches any of them
    for _,v in pairs(KEY_ITEMS) do
      if type(v.value) == "number" then
        if item == v.value then
          v.found = true
        end
      elseif type(v.value) == "table" then
        -- Loop through possible IDs for items with more than one
        -- Not used since the Masamume/Grand Leon change, but leaving this in
        -- in case it's needed in the future.
        for _, v2 in pairs(v.value) do
          if item == v2 then
            v.found = true
          end
        end
      end
    end -- end key item loop
  end -- end inventory loop

  updateKeyItems()

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
  local keyItemChecksDone = 0

  -- Prehistory
  updateBoss("nizbelboss", segment, 0x7F0105, 0x20)
  updateBoss("blacktyranoboss", segment, 0x7F00EC, 0x80)

  -- Dark Ages
  updateBoss("gigagaiaboss", segment, 0x7F0100, 0x20)
  updateBoss("golemboss", segment, 0x7F0105, 0x80)

  -- Middle Ages
  updateBoss("yakraboss", segment, 0x7F000D, 0x01)
  updateBoss("masamuneboss", segment, 0x7F00F3, 0x20)
  updateBoss("retiniteboss", segment, 0x7F01A3, 0x01)
  updateBoss("rusttyranoboss", segment, 0x7F01D2, 0x40)
  updateBoss("magusboss", segment, 0x7F01FF, 0x04)
  keyItemChecksDone = keyItemChecksDone + handleZenanBridge(segment)

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
  -- This memory flag gets set based on what characters are in the party
  -- when you reach the summit. Check to see if any of the bottom 3 bits are set
  updateBoss("zealboss", segment, 0x7F0067, 0x07)

  -- Only track events in the "Map Tracker" variant
  if not itemsOnlyTracking() then
    -- Prehistory
    keyItemChecksDone = keyItemChecksDone + updateEvent("@Reptite Lair/Defeat Nizbel", segment, 0x7F0105, 0x20)
    updateEvent("@Dactyl Nest/Friend to the Dactyls", segment, 0x7F0160, 0x10)

    -- Dark Ages
    keyItemChecksDone = keyItemChecksDone + updateEvent("@Mt Woe/Defeat Giga Gaia", segment, 0x7F0100, 0x20) -- same as boss flag

    -- Don't check these events in Lost Worlds mode, they don't exist.
    if not lostWorldsMode() then
      -- Moonstone is the only prehistory event that is not part of the Lost Worlds mode.
      updateEvent("@Sun Keep/Charge the Moonstone", segment, 0x7F013A, 0x40)

      -- Middle Ages
      updateEvent("@Manoria Cathedral/Saved by Frog", segment, 0x7F0100, 0x01)
      updateEvent("@Guardia Castle Past/Rescue Marle", segment, 0x7F00A1, 0x04)
      keyItemChecksDone = keyItemChecksDone + updateEvent("@Denadoro Mts/Defeat Masamune", segment, 0x7F0102, 0x02)
      keyItemChecksDone = keyItemChecksDone + updateEvent("@Fiona's Villa/Replant the Forest", segment, 0x7F007C, 0x80)
      keyItemChecksDone = keyItemChecksDone + updateEvent("@Cursed Woods/Burrow Left Chest", segment, 0x7F0106, 0x04)
      updateEvent("@Cursed Woods/Return the Masamune", segment, 0x7F00FF, 0x20)
      -- NOTE: Rainbow Shell flag is set after warping out of the cave
      --       after interacting with the Rainbow Shell
      keyItemChecksDone = keyItemChecksDone + updateEvent("@Giant's Claw/Rainbow Shell", segment, 0x7F00A9, 0x80)

      -- Present
      keyItemChecksDone = keyItemChecksDone + updateEvent("@Snail Stop/Buy for 9900G", segment, 0x7F01D0, 0x10)
      keyItemChecksDone = keyItemChecksDone + updateEvent("@Choras Inn/Borrow Carpenter's Tools", segment, 0x7F019E, 0x80)
      keyItemChecksDone = keyItemChecksDone + updateEvent("@Lucca's House/Taban's Gift", segment, 0x7F007A, 0x01)
      updateEvent("@Melchior's Hut/Reforge the Masamune", segment, 0x7F0103, 0x02)
      -- The trial is a guess. Two flags go high here and I just picked one arbitrarily
      keyItemChecksDone = keyItemChecksDone + updateEvent("@Guardia Castle Present/King Guardia's Trial", segment, 0x7F00A2, 0x80)
      keyItemChecksDone = keyItemChecksDone + handleMelchiorRefinements(segment)

      -- Checks specific to vanilla randomizer mode
      if vanillaRandoMode() then
        keyItemChecksDone = keyItemChecksDone + updateEvent("@Norstein Bekkler's Tent of Horrors/Clone Game", segment, 0x7F007C, 0x01)
        keyItemChecksDone = keyItemChecksDone + updateEvent("@Northern Ruins Past/Cyrus Grave", segment, 0x7F01A3, 0x40)
      end

      -- Checks specific to Legacy of Cyrus mode
      if legacyOfCyrusMode() then
        updateBoss("ozzie", segment, 0x7F01A1, 0x80)
        updateBoss("cyrusgrave", segment, 0x7F01A3, 0x40)
      end
    end

    -- Future
    updateEvent("@Proto Dome/Fix Robo", segment, 0x7F00F3, 0x02)
    keyItemChecksDone = keyItemChecksDone + updateEvent("@Arris Dome/Activate the Computer", segment, 0x7F00A4, 0x01)
    keyItemChecksDone = keyItemChecksDone + updateEvent("@Sun Palace/Moon Stone", segment, 0x7F013A, 0x02) -- same as Son of Sun
    keyItemChecksDone = keyItemChecksDone + updateEvent("@Geno Dome/Defeat Mother Brain", segment, 0x7F013B, 0x10) -- Same as Mother Brain
  end -- end event tracking

  CHECK_COUNTERS.base_checks = keyItemChecksDone

  -- End of Time
  -- Track magic here. This is the flag that is set after Spekkio challenges you
  -- to a practice fight after learning magic.
  local magic = Tracker:FindObjectForCode("magic")
  local spekkioByte = segment:ReadUInt8(0x7F00E1)
  magic.Active = (spekkioByte & 0x02) ~= 0

  -- Masamune
  -- The Masamune tracker item is activated when the player reforges the Masamune
  -- after collecting the hilt and blade.  The original version of the tracker
  -- tracked this via the inventory, but it can be tracked easier using the event
  -- flag set high after Melchior reforges the sword.  Because it's part of event
  -- memory, check for the tracker item here.
  melchior = Tracker:FindObjectForCode("melchior")
  melchior.Active = (segment:ReadUInt8(0x7F0103) & 0x02) ~= 0

  -- Validation Cat
  -- This is a bit of a meme check.  Validation Cat refers to Crono's cat.
  -- Petting Crono's cat in Crono's house "validates" the run.
  local cat = Tracker:FindObjectForCode("validationcat")
  local catByte = segment:ReadUInt8(0x7F01A6)
  cat.Active = (catByte & 0x08) ~= 0

  -- Handle sealed chest tracking. The chest counter is on all pack variants now
  -- so count sealed/event chests in all modes.
  handleSealedChests(segment)

  -- Check if the Epoch is capable of flight.
  -- This is used in the Epoch Fail mode of Vanilla Rando
  updateEvent("@Snail Stop/Attach Epoch Wings", segment, 0x7F00BA, 0x80)

end

--
-- Toggle a character based on whether or not they were found in the party.
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
-- NOTE: This function is not currently being used.  There is a race
--       condition where the characters are removed before the trial
--       flag is set. If the tracker updates before the trial bit is
--       set, the characters will still show up as removed.  I am
--       leaving this function here until I find a reliable way to fix it.
--       Functionally, this means that the characters in slot 2 and 3 will
--       vanish from the tracker until they rejoin after the prison escape.
--
--
-- Check to see if the player is in the trial sequence.
-- During Crono's trial sequence in 1000AD in Guardia Castle the
-- two characters in slots 2 and 3 are removed from the party entirely.
-- This function is used to pause character tracking during the trial to prevent
-- the two characters from being unchecked from the tracker.
--
-- Restart tracking after the characters have rejoined the party.
--
-- NOTE: The byte used to determine if the characters have rejoined seems to count
--       up as the story section progresses.
--   0x01 - Skipped in the randomizer, maybe when the trial is going on?
--   0x02 - Character has been led away to jail
--   0x03 - Party joins back up after the escape
--   0x04 - Party takes the portal to the future
--
function inTrialSequence()

  local trialByte = AutoTracker:ReadU8(0x7F0104) & 0x07
  local trialStarted = trialByte == 2
  local charsRejoined = trialByte > 2

  return trialStarted and not charsRejoined

end

--
-- Read the PC and PC Reserve slots to determine which
-- characters have been acquired.
--
function updateParty(segment)

  -- Don't track if we're not actively in game
  if not inGame() then
    return
  end

  -- Character IDs:
  -- NOTE: items.json uses characters' real names, not defaults.
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
-- Update the total collection count from normal event checks,
-- chest checks, and sealed treasure checks.
-- This updates the check counter on the tracker.
--
function updateCollectionCount()

  local counter = Tracker:FindObjectForCode("checkcounter")
  counter.AcquiredCount = CHECK_COUNTERS.chests + CHECK_COUNTERS.sealed_chests + CHECK_COUNTERS.base_checks

end

--
-- Handle a single sealed chest location.
--
function handleSealedChestLocation(segment, locationName, flags)

  local location = Tracker:FindObjectForCode(locationName)
  if location == nil then
    return 0
  end

  local treasuresCollected = 0
  for _, flag in pairs(flags) do
    local value = segment:ReadUInt8(flag[1])
    if (value & flag[2]) ~= 0 then
      treasuresCollected = treasuresCollected + 1
    end
  end

  location.AvailableChestCount = location.ChestCount - treasuresCollected
  return treasuresCollected

end

--
-- Handle autotracking for the sealed chests that are part
-- of Chronosanity mode.
--
function handleSealedChests(segment)

  ------------
  -- 600 AD --
  ------------
  local total = handleSealedChestLocation(segment, "@Porre Elder's House/Sealed Chests", {{0x7F01D3, 0x10}, {0x7F01D3, 0x20}})
  total = total + handleSealedChestLocation(segment, "@Truce Inn Past/Sealed Chest", {{0x7F014A, 0x80}})
  total = total + handleSealedChestLocation(segment, "@Guardia Forest Past/Sealed Chest", {{0x7F01D2, 0x80}})
  total = total + handleSealedChestLocation(segment, "@Guardia Castle Past/Sealed Chest", {{0x7F00D9, 0x02}})
  total = total + handleSealedChestLocation(segment, "@Magic Cave/Sealed Chest", {{0x7F0079, 0x01}})

  -------------
  -- 1000 AD --
  -------------
  total = total + handleSealedChestLocation(segment, "@Porre Mayor's House/Sealed Chests", {{0x7F01D1, 0x40}, {0x7F01D1, 0x80}})
  total = total + handleSealedChestLocation(segment, "@Truce Inn Present/Sealed Chest", {{0x7F014A, 0x20}})
  total = total + handleSealedChestLocation(segment, "@Guardia Forest Present/Sealed Chest", {{0x7F01D1, 0x20}})
  total = total + handleSealedChestLocation(segment, "@Guardia Castle Present/Sealed Chest", {{0x7F00D9, 0x04}})
  total = total + handleSealedChestLocation(segment, "@Heckran Cave/Sealed Chest", {{0x7F01A0, 0x04}})
  total = total + handleSealedChestLocation(segment, "@Forest Ruins/Blue Pyramid", {{0x7F01A0, 0x01}})

  -- The "regular" Northern Ruins chests are not normal treasure chests.
  -- They are handled internally via events just like sealed chests.
  -- 600 AD
  total = total + handleSealedChestLocation(segment, "@Northern Ruins Past/Chests", {{0x7F01AC, 0x02}, {0x7F01AC, 0x08}})
  total = total + handleSealedChestLocation(segment, "@Northern Ruins Past/Sealed Chests", {{0x7F01A6, 0x01}, {0x7F01A6, 0x02}, {0x7F01A6, 0x04}})
  -- 1000 AD
  total = total + handleSealedChestLocation(segment, "@Northern Ruins Present/Basement", {{0x7F01AC, 0x01}})
  total = total + handleSealedChestLocation(segment, "@Northern Ruins Present/Upstairs", {{0x7F01AC, 0x04}})
  total = total + handleSealedChestLocation(segment, "@Northern Ruins Present/Sealed Chests", {{0x7F01A9, 0x20}, {0x7F01A9, 0x40}, {0x7F01A9, 0x80}})

  CHECK_COUNTERS.sealed_chests = total
  updateCollectionCount()

end

--
-- Handle updating the chest counters for a given area.
--
function handleChests(segment, locationName, treasureMap)

  -- Base address of the block of treasure bits
  -- Treasure pointers are stored as offsets from this address
  local baseAddress = 0x7F0001
  local totalTreasures = 0

  -- Loop through each sub-location for this location
  for locationCode,treasures in pairs(treasureMap) do
    local location = Tracker:FindObjectForCode(locationName .. locationCode)
    if location == nil then
      -- It is possible in some modes for not all defined treasures to exist.
      -- ie: LoC mode doesn't have Ozzie's Fort treasures.
      -- If the location doesn't exist, just return 0
      return 0
    end

    -- Loop through and count the treasures in each subsection
    --    treasure[1] - Offset from the base treasure address
    --    treasure[2] - Bitmask flag for this treasure
    local collectedTreasures = 0
    for _, treasure in pairs(treasures) do
      local address = baseAddress + treasure[1]
      local treasureByte = segment:ReadUInt8(address)
      if (treasureByte & treasure[2]) ~= 0 then
        collectedTreasures = collectedTreasures + 1
      end
    end -- end treasure loop

    location.AvailableChestCount = location.ChestCount - collectedTreasures
    totalTreasures = totalTreasures + collectedTreasures

  end -- End location loop

  return totalTreasures

end

--
-- Update the chests that have been collected
-- by the player.  Only chests considered for
-- key item placement in Chronosanity mode are
-- tracked here.
--
function updateChests(segment)

  -- Don't autotrack during gate travel:
  -- During a gate transition the memory flags holding the chest
  -- data  are overwritten.  After the animation, memory
  -- goes back to normal.
  s1 = segment:ReadUInt16(0x7F0000)
  s2 = segment:ReadUInt16(0x7F0002)
  if s1 == 0x4140 and s2 == 0x4342 then
    return
  end

  --
  -- Treasures for each loction are stored as an offset
  -- from the base treasure address and a bit flag
  -- for the specific chest.
  --
  -- Named entries are subsections within the location.
  --
  local chestsOpened = 0
  --------------------------
  --    65,000,000 BC     --
  --------------------------
  -- Mystic Mountains
  local chests = {
    ["Chests"] = {
      {0x13, 0x20}
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Mystic Mountain/", chests)

  -- Forest Maze
  chests = {
    ["Chests"] = {
      {0x13, 0x40},
      {0x13, 0x80},
      {0x14, 0x01},
      {0x14, 0x02},
      {0x14, 0x04},
      {0x14, 0x08},
      {0x14, 0x10},
      {0x14, 0x20},
      {0x14, 0x40}
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Forest Maze/", chests)

  -- Dactyl Nest
  chests = {
    ["Chests"] = {
      {0x15, 0x80},
      {0x16, 0x01},
      {0x16, 0x02}
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Dactyl Nest/", chests)

  -- Reptite Lair
  chests = {
    ["Chests"] = {
      {0x15, 0x20},
      {0x15, 0x40}
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Reptite Lair/", chests)

  --------------------------
  --      12000 BC        --
  --------------------------
  -- Mount Woe
  -- Screen 1 - Middle Eastern Face (0x18A)
  -- Screen 2 - Western Face (0x188)
  -- Screen 3 - Lower Eastern Face (0x189)
  -- Screen 4 - Upper Eastern Face (0x18B)
  chests = {
    ["Screen 1"] = {
      {0x1B, 0x08}
    },
    ["Screen 2"] = {
      {0x1A, 0x02}, -- Screen 2, Bottom Right Chest
      {0x1A, 0x04}, -- Screen 2, Top Right Island, Top Chest
      {0x1A, 0x08}, -- Screen 2, Top Right Island, Bottom Chest
      {0x1A, 0x10}, -- Screen 2, Top Left Chest
      {0x1A, 0x20}  -- Screen 2, Mid Left Chest
    },
    ["Screen 3"] = {
      {0x1A, 0x40}, -- Screen 3, Right Island, Bottom chest
      {0x1A, 0x80}, -- Screen 3, Right Island, Top chest
      {0x1B, 0x01}, -- Screen 3, Bottom Left Chest
      {0x1B, 0x02}, -- Screen 3, Top Left Island, Right Chest
      {0x1B, 0x04}  -- Screen 3, Top Left Island, Left Chest
    },
    ["Screen 4"] = {
      {0x1B, 0x10}, -- Screen 4, Right Chest
      {0x1B, 0x20}  -- Screen 4, Left Chest
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Mt Woe/", chests)

  --------------------------
  --       600 AD         --
  --------------------------
  -- Fiona's Villa
  chests = {
    ["Chests"] = {
      {0x07, 0x40},
      {0x07, 0x80}
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Fiona's Villa/", chests)

  -- Truce Canyon
  chests = {
    ["Chests"] = {
      {0x03, 0x08},
      {0x03, 0x10}
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Truce Canyon/", chests)

  -- Guardia Castle Past
  chests = {
    ["King's Tower"] = {
      {0x1E, 0x04},
      {0x03, 0x20}
    },
    ["Queen's Tower"] = {
      {0x1D, 0x08}
    },
    ["Queen's Room"] = {
      {0x03, 0x40}
    },
    ["Kitchen"] = {
      {0x03, 0x80}
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Guardia Castle Past/", chests)

  -- Manoria Cathedral
  chests = {
    ["Front Half"] = {
      {0x04, 0x02},
      {0x04, 0x04},
      {0x04, 0x08}
    },
    ["Bromide Room"] = {
      {0x0C, 0x08},
      {0x0C, 0x10},
      {0x0C, 0x20}
    },
    ["Disguised Royalty"] = {
      {0x0C, 0x02},
      {0x0C, 0x04}
    },
    ["Shrine"] = {
      {0x0C, 0x40},
      {0x0C, 0x80}
    },
    ["Back Half"] = {
      {0x04, 0x10},
      {0x04, 0x20},
      {0x04, 0x40},
      {0x04, 0x80}
    },
    ["Final Chest"] = {
      {0x0C, 0x01}
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Manoria Cathedral/", chests)

  -- Cursed Woods
  chests = {
    ["Burrow Right Chest"] = {
      {0x05, 0x04}
    },
    ["Forest Chests"] = {
      {0x05, 0x01},
      {0x05, 0x02}
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Cursed Woods/", chests)

  -- Denadoro Mountains
  chests = {
    ["Entrance"] = {
      {0x06, 0x40}, -- Entrance Cliff
      {0x06, 0x80}, -- Entrance
      {0x05, 0x20}, -- Back room from entrance
      {0x05, 0x08}, -- Screen 2 top chest
      {0x05, 0x10}  -- Screen 2 left chest
    },
    ["Right Side Climb"] = {
      {0x06, 0x01}, -- climb, right side (rock thrower)
      {0x07, 0x01}, -- Outlaw race chest
      {0x07, 0x02}, -- Outlaw race chest
      {0x07, 0x04}, -- Outlaw race chest
      {0x07, 0x08}, -- Outlaw race chest
      {0x07, 0x10}  -- Right side, before gauntlet
    },
    ["Waterfall Top"] = {
      {0x06, 0x08}, -- Waterfall top - bottom right chest
      {0x06, 0x10}, -- Waterfall top - top chest
      {0x06, 0x20}  -- Waterfall top - Left Chest
    },
    ["Waterfall Bottom"] = {
      {0x06, 0x02}, -- Waterfall bottom - left chest
      {0x06, 0x04}  -- Waterfall bottom - right chest
    },
    ["Left Side"] = {
      {0x05, 0x40}, -- Final screen bottom chest
      {0x05, 0x80}, -- Final screen top chest
      {0x07, 0x20}  -- Left side by save point
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Denadoro Mts/", chests)

  -- Giant's Claw
  chests = {
  -- Throne room chests are shared between here and Tyrano Lair.
  -- They are not currently being used in Chronosanity.
  --  ["Throne Room"] = {
  --    {0x16, 0x04},
  --    {0x16, 0x08}
  --  },
    ["Entrance"] = {
      {0x0B, 0x04}, -- Left chest after throne room
      {0x03, 0x04}  -- Chest north of the pit you jump down
    },
    ["Caverns"] = {
      {0x0B, 0x80}, -- Caverns room 1
      -- {0x0B, 0x40}, -- Blue Rock - Rock chests not included in Chronosanity
      {0x0B, 0x20}, -- Caverns room 2, left side
      {0x0B, 0x10}, -- Caverns room 2, right side
      {0x0B, 0x08}  -- Left door of pit room
    },
    ["Kino's Cell"] = {
      {0x03, 0x02}  -- Kino's Cell
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Giant's Claw/", chests)

  -- Ozzie's Fort
  chests = {
    ["Front Half"] = {
      {0x0A, 0x10},
      {0x0A, 0x20},
      {0x0A, 0x40},
      {0x0A, 0x80}
    },
    ["Back Half"] = {
      {0x0B, 0x01},
      {0x0B, 0x02}
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Ozzie's Fort/", chests)

  --------------------------
  --       1000 AD        --
  --------------------------
  -- Guardia Castle Present
  chests = {
    ["King's Tower"] = {
      {0x1E, 0x08},
      {0x00, 0x10}
    },
    ["Queen's Tower"] = {
      {0x1E, 0x10},
      {0x00, 0x20}
    },
    ["Courtroom Tower"] = {
      {0x1E, 0x20}
    },
    ["Prison Tower"] = {
      {0x1E, 0x40}
    },
    ["Guardia Treasury"] = {
      {0x00, 0x40},
      {0x00, 0x80},
      {0x01, 0x01},
      {0x1D, 0x01},
      {0x1D, 0x02},
      {0x1D, 0x04}
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Guardia Castle Present/", chests)

  -- Truce Mayor's House
  chests = {
    ["Chests"] = {
      {0x00, 0x04},
      {0x00, 0x08}
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Truce Mayor's House/", chests)

  -- Porre Mayor's House
  chests = {
    ["Chests"] = {
      {0x01, 0x80}
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Porre Mayor's House/", chests)

  -- Forest Ruins
  chests = {
    ["Chests"] = {
      {0x01, 0x04}
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Forest Ruins/", chests)

  -- Heckran's Cave
  chests = {
    ["Chests"] = {
      {0x01, 0x08},
      {0x01, 0x10},
      {0x01, 0x20},
      {0x01, 0x40}
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Heckran Cave/", chests)

  --------------------------
  --       2300 AD        --
  --------------------------
  -- Bangor Dome
  chests = {
    ["Sealed Door"] = {
      {0x0D, 0x01},
      {0x0D, 0x02},
      {0x0D, 0x04}
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Bangor Dome/", chests)

  -- Trann Dome
  chests = {
    ["Sealed Door"] = {
      {0x0D, 0x08},
      {0x0D, 0x10}
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Trann Dome/", chests)

  -- Arris Dome
  chests = {
    ["Chests"] = {
      {0x0E, 0x02}, -- Passageway
      {0x1A, 0x01}  -- Food Storage
    },
    ["Sealed Door"] = {
      {0x0E, 0x04},
      {0x0E, 0x08},
      {0x0E, 0x10},
      {0x0E, 0x20}
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Arris Dome/", chests)

  -- Factory Ruins
  chests = {
    ["Left Side"] = {
      {0x0F, 0x02}, -- Auxillary computer (hatch room)
      {0x0F, 0x04}, -- Security Center
      {0x0F, 0x08}, -- Security Center
      {0x10, 0x08}  -- Power Core
    },
    ["Right Side"] = {
      {0x0F, 0x10},
      {0x0F, 0x20},
      {0x0F, 0x40},
      {0x0F, 0x80}, -- hidden chest
      {0x10, 0x01},
      {0x10, 0x02},
      {0x10, 0x04},
      {0x12, 0x08},
      {0x12, 0x10}
      -- 7F001D   80  Inaccessible chest
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Factory/", chests)

  -- Sewers
  chests = {
    ["Chests"] = {
      {0x10, 0x10}, -- Front chest
      {0x10, 0x20}, -- Krawlie chest
      {0x10, 0x40}  -- Back chest (left of exit)
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Sewers/", chests)

  -- Lab16
  chests = {
    ["Chests"] = {
      {0x0D, 0x20}, -- Chest 2 (after 3 volcanos)
      {0x0D, 0x40}, -- Chest 3 (Before 5 volcanos)
      {0x0D, 0x80}, -- Chest to the right of the entrance
      {0x0E, 0x01}  -- East side chest
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Lab16/", chests)

  -- Lab32
  chests = {
    ["Chests"] = {
      {0x0E, 0x80}
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Lab32/", chests)

  -- Geno Dome
  chests = {
    ["First Floor"] = {
      {0x11, 0x08}, -- Control Room (By electricity)
      {0x11, 0x10}, -- Robot storage top chest
      {0x11, 0x20}, -- Robot storage bottom chest
      {0x11, 0x40}, -- Far left chest (by 2nd doll)
      {0x11, 0x80}, -- South electricity room, left chest
      {0x12, 0x01}, -- South electricity room, right chest
      {0x12, 0x02}, -- Proto 4 room, top chest
      {0x12, 0x04}  -- Proto 4 room, bottom chest
    },
    ["Second Floor"] = {
      {0x13, 0x02}, -- Back catwalk chest
      {0x13, 0x04}, -- Laser cell chest
      {0x13, 0x08}, -- Left catwalk chest
      {0x13, 0x10}  -- Chest by first set of laser guards
    }
  }
  chestsOpened = chestsOpened + handleChests(segment, "@Geno Dome/", chests)

  CHECK_COUNTERS.chests = chestsOpened
  updateCollectionCount()

end

--
-- Set up memory watches on memory used for autotracking.
--
printDebug("Adding memory watches")
ScriptHost:AddMemoryWatch("Party", 0x7E2980, 9, updateParty)
ScriptHost:AddMemoryWatch("Events", 0x7F0000, 512, updateEventsAndBosses)
ScriptHost:AddMemoryWatch("Inventory", 0x7E2400, 0xF2, updateItemsFromInventory)
ScriptHost:AddMemoryWatch("Chests", 0x7F0000, 0x20, updateChests)
ScriptHost:AddMemoryWatch("Equipment", 0x7E2627, 0x1E3, updateItemsFromEquipment)
