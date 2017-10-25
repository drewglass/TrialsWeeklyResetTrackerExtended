--namespace
TrialsWeeklyResetTrackerExtended = {}
local TWRTE = TrialsWeeklyResetTrackerExtended

--constants
TWRTE.WEEK_IN_SECONDS = 604800
TWRTE.DAY_IN_SECONDS = 86400
TWRTE.HOUR_IN_SECONDS = 3600
TWRTE.MINUTE_IN_SECONDS = 60
TWRTE.MAX_DIFFERENCE = 5

--runtime data
TWRTE.characterId = GetCurrentCharacterId()
TWRTE.characterName = zo_strformat("<<1>>",GetRawUnitName("player"))
TWRTE.lastQuestId = nil
TWRTE.lastLootId = nil
TWRTE.questIds = {
    [5087] = "",
    [5102] = "",
    [5171] = "",
    [5352] = "",
    [5894] = "",
}
TWRTE.lootIds = {
    [87703] = "",
    [87708] = "",
    [87702] = "",
    [87707] = "",
    [81187] = "",
    [81188] = "",
    [87705] = "",
    [87706] = "",
    [94089] = "",
    [94090] = "",
}

--saved data
TWRTE.data = nil

--turn a number representing seconds into a human readable string
--ex: 123456 == 1d 10h 17m 36s
local function secondsToCooldownString(seconds)
    local cooldownString, days, hours, minutes

    --get days, hours, and minutes
    days = zo_floor(seconds / TWRTE.DAY_IN_SECONDS)
    seconds = seconds % TWRTE.DAY_IN_SECONDS
    hours = zo_floor(seconds / TWRTE.HOUR_IN_SECONDS)
    seconds = seconds % TWRTE.HOUR_IN_SECONDS
    minutes = zo_floor(seconds / TWRTE.MINUTE_IN_SECONDS)
    seconds = seconds % TWRTE.MINUTE_IN_SECONDS

    cooldownString = ""

    --only add a part to the string if it is greater than 0
    if days > 0 then cooldownString = cooldownString..days.."d " end
    if hours > 0 then cooldownString = cooldownString..hours.."h " end
    if minutes > 0 then cooldownString = cooldownString..minutes.."m " end
    if seconds > 0 then cooldownString = cooldownString..seconds.."s" end

    return cooldownString
end

local function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

local function getTrialName(questId)
	local lookup = {
        [5087] = "Hel Ra Citadel",
        [5102] = "Atherian Archive",
        [5171] = "Sanctum Ophidia",
        [5352] = "Maw of Lorkaj",
        [5894] = "Halls of Fabrication"
    }
	
	return lookup[questId]
end

local function getCooldownInfo()	
	local cooldownInfo = {}
	
	--for each character
	for characterId in pairs(TrialsWeeklyResetTrackerExtendedSavedVariables["characters"]) do
		cooldownInfo[TrialsWeeklyResetTrackerExtendedSavedVariables["characters"][characterId]["name"]] = {}
		
		--for each quest saved to this character's cooldown data
		for questId, lootTable in pairs(TrialsWeeklyResetTrackerExtendedSavedVariables["characters"][characterId]["quests"]) do
			--get and output the quest name
			local trialName = getTrialName(questId)
			
			cooldownInfo[TrialsWeeklyResetTrackerExtendedSavedVariables["characters"][characterId]["name"]][trialName] = {}

			--for each coffer saved to this questId
			for lootId, cooldownEnd in pairs(lootTable) do
				local itemLink = "|H1:item:"..lootId..":0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
				local currentTime = GetTimeStamp()

				--output message based on cooldown state
				if cooldownEnd <= currentTime then
					cooldownInfo[TrialsWeeklyResetTrackerExtendedSavedVariables["characters"][characterId]["name"]][trialName][lootId] = 0
				else
					cooldownInfo[TrialsWeeklyResetTrackerExtendedSavedVariables["characters"][characterId]["name"]][trialName][lootId] = cooldownEnd - currentTime
				end
			end
		end
	end	
	
	return cooldownInfo
end

local function displayCooldownInfo()
	local cooldownInfo = getCooldownInfo()
	
	for characterName in pairs(cooldownInfo) do
		if tablelength(cooldownInfo[characterName]) > 0 then
			d(characterName)
		end
		
		for trialName in pairs(cooldownInfo[characterName]) do
			for itemId, cooldown in pairs(cooldownInfo[characterName][trialName]) do
				local itemLink = "|H1:item:"..itemId..":0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
				
				if cooldown <= 0 then
					d("- "..trialName.." ("..itemLink.."): available.")
				else
					d("- "..trialName.." ("..itemLink.."): "..secondsToCooldownString(cooldown)..".")
				end
			end
		end
	end
end
SLASH_COMMANDS["/twrte"] = displayCooldownInfo

local function updateCooldownInfo()
    --questIds and their matching lootIds
    local lookup = {
        --Hel Ra Citadel, "Assaulting the Citadel"
        [5087] = {
            [87703] = "", --Warrior's Dulled Coffer
            [87708] = "", --Warrior's Honed Coffer
        },
        --Atherian Archive, "The Mage's Tower"
        [5102] = {
            [87702] = "", --Mage's Ignorant Coffer
            [87707] = "", --Mage's Knowledgeable Coffer
        },
        --Sanctum Ophidia, "The Oldest Ghost"
        [5171] = {
            [81187] = "", --Serpent's Languid Coffer
            [81188] = "", --Serpent's Coiled Coffer
            [87705] = "", --Serpent's Languid Coffer
            [87706] = "", --Serpent's Coiled Coffer
        },
        --Maw of Lorkaj, "Into the Maw"
        [5352] = {
            [94089] = "", --Dro-m'Athra's Burnished Coffer
            [94090] = "", --Dro-m'Athra's Shining Coffer
        },
        --Halls of Fabrication, "Forging the Future"
        [5894] = {
            [126130] = "", --Fabricant's Burnished Coffer
            [126131] = "", --Fabricant's Shining Coffer
        }
    }

    --only continue if both quest and loot ids are initialized
    if not TWRTE.lastQuestId or not TWRTE.lastLootId then return end

    --only continue if we have matching information
    if not lookup[TWRTE.lastQuestId][TWRTE.lastLootId] then return end

    --get timestamps for comparison
    local lootTimestamp = tonumber(TWRTE.lootIds[TWRTE.lastLootId])
    local questTimestamp = tonumber(TWRTE.questIds[TWRTE.lastQuestId])

    --make sure they exist
    if not lootTimestamp or not questTimestamp then return end

    --calculate difference
    local difference = zo_abs(lootTimestamp - questTimestamp)

    --update cooldown info if difference is within acceptable margin
    if difference < TWRTE.MAX_DIFFERENCE then
        --ensure there is a place to save cooldown
        TrialsWeeklyResetTrackerExtendedSavedVariables["characters"][TWRTE.characterId]["quests"][TWRTE.lastQuestId] = TrialsWeeklyResetTrackerExtendedSavedVariables["characters"][TWRTE.characterId]["quests"][TWRTE.lastQuestId] or {}

        --save the current time plus one week for the cooldown
        TrialsWeeklyResetTrackerExtendedSavedVariables["characters"][TWRTE.characterId]["quests"][TWRTE.lastQuestId][TWRTE.lastLootId] = GetTimeStamp() + TWRTE.WEEK_IN_SECONDS
    end
end

--triggered when someone in the group loots something
local function lootReceived(eventCode, receivedBy, itemName, quantity, itemSound, lootType, receivedBySelf, isPickpocketLoot, questItemIconPath, itemId)
    --only continue if the event was triggered for the player
    if not receivedBySelf then return end
	
	TrialsWeeklyResetTrackerExtendedSavedVariables["characters"][TWRTE.characterId]["lastLootedItemId"] = itemId

    --if it is an item we're interested in
    if TWRTE.lootIds[itemId] then
        --save timestamp and the itemId
        TWRTE.lootIds[itemId] = GetTimeStamp()
        TWRTE.lastLootId = itemId
    end

    --update the cooldown info
    updateCooldownInfo()
end
EVENT_MANAGER:RegisterForEvent("TWRTE_LOOT_RECEIVED", EVENT_LOOT_RECEIVED, lootReceived)

--triggered on quest complete or abandon
local function questRemoved(eventCode, isCompleted, journalIndex, questName, zoneIndex, poiIndex, questId)
    --only continue if quest is complete
    if not isCompleted then return end
	
	local questName = GetCompletedQuestInfo(questId)
	
	TrialsWeeklyResetTrackerExtendedSavedVariables["characters"][TWRTE.characterId]["lastCompletedQuest"] = TrialsWeeklyResetTrackerExtendedSavedVariables["characters"][TWRTE.characterId]["lastCompletedQuest"] or {}
	TrialsWeeklyResetTrackerExtendedSavedVariables["characters"][TWRTE.characterId]["lastCompletedQuest"]["id"] = questId
	TrialsWeeklyResetTrackerExtendedSavedVariables["characters"][TWRTE.characterId]["lastCompletedQuest"]["name"] = questName

    --if it is a quest we're interested in
    if TWRTE.questIds[questId] then
        --save timestamp and the questId
        TWRTE.questIds[questId] = GetTimeStamp()
        TWRTE.lastQuestId = questId
    end

    --this is probably unnecessary, but in the event the loot is received before the quest is "completed" we'll call here as well
    updateCooldownInfo()
end
EVENT_MANAGER:RegisterForEvent("TWRTE_QUEST_REMOVED", EVENT_QUEST_REMOVED, questRemoved)

local function migrateVersion1ToVersion2(data)
	for characterId in pairs(data["characters"]) do
		data["characters"][characterId]["lastCompletedQuest"] = {}
		data["characters"][characterId]["lastCompletedQuest"]["id"] = -1
		data["characters"][characterId]["lastCompletedQuest"]["name"] = ""
		data["characters"][characterId]["lastLootedItemId"] = -1
	end
	
	data["version"] = 2
end

local function addonLoaded(eventCode, addonName)
    if addonName ~= "TrialsWeeklyResetTrackerExtended" then return end

    --setup saved variables
    TrialsWeeklyResetTrackerExtendedSavedVariables = TrialsWeeklyResetTrackerExtendedSavedVariables or {}
    TWRTE.data = TrialsWeeklyResetTrackerExtendedSavedVariables
	TWRTE.data["version"] = TWRTE.data["version"] or 2
	
	if TWRTE.data["version"] == 1 then
		migrateVersion1ToVersion2(TWRTE.data)
	end
	
	TWRTE.data["characters"] = TWRTE.data["characters"] or {}
    TWRTE.data["characters"][TWRTE.characterId] = TWRTE.data["characters"][TWRTE.characterId] or {}
	TWRTE.data["characters"][TWRTE.characterId]["quests"] = TWRTE.data["characters"][TWRTE.characterId]["quests"] or {}
	TWRTE.data["characters"][TWRTE.characterId]["name"] = TWRTE.characterName
end
EVENT_MANAGER:RegisterForEvent("TWRTE_ADDON_LOADED", EVENT_ADD_ON_LOADED, addonLoaded)