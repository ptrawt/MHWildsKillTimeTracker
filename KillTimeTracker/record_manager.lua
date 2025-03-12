-----------------------------------------
-- record_manager.lua
-- Record management for Kill Time Tracker
-----------------------------------------

local Core = require("_CatLib")
local os = os

local RecordManager = {
    BossNameList = {
        'Rathian', 'Rathalos', 'Guardian Rathalos', 'Gravios', 
        'Yian Kut-Ku', 'Gypceros', 'Congalala', 'Blangonga', 
        'Nerscylla', 'Gore Magala', 'Guardian Fulgur Anjanath', 
        'Guardian Ebony Odogaron', 'Doshaguma', 'Guardian Doshaguma', 
        'Balahara', 'Chatacabra', 'Quematrice', 'Lala Barina', 
        'Rompopolo', 'Rey Dau', 'Uth Duna', 'Nu Udra', 
        'Ajarakan', 'Arkveld', 'Guardian Arkveld', 'Hirabami', 
        'Jin Dahaad', 'Xu Wu', 'Zoh Shia'
    },
    
    BossIDList = {
        'EM0001_00_0', 'EM0002_00_0', 'EM0002_50_0', 'EM0005_00_0',
        'EM0008_00_0', 'EM0009_00_0', 'EM0021_00_0', 'EM0022_00_0',
        'EM0070_00_0', 'EM0071_00_0', 'EM0100_51_0', 'EM0113_51_0',
        'EM0150_00_0', 'EM0150_50_0', 'EM0151_00_0', 'EM0152_00_0',
        'EM0153_00_0', 'EM0154_00_0', 'EM0155_00_0', 'EM0156_00_0',
        'EM0157_00_0', 'EM0158_00_0', 'EM0159_00_0', 'EM0160_00_0',
        'EM0160_50_0', 'EM0161_00_0', 'EM0162_00_0', 'EM0163_00_0',
        'EM0164_50_0'
    },
    
    weaponList = {
        "Great Sword", "Long Sword", "Sword & Shield", "Dual Blades",
        "Hammer", "Hunting Horn", "Lance", "Gunlance",
        "Switch Axe", "Charge Blade", "Insect Glaive", "Bow",
        "Light Bowgun", "Heavy Bowgun"
    },
    
    monsterNameMap = {}
}

local KillTimeTracker = nil
local EnemyIdNameMap = Core.GetEnumMap("app.EnemyDef.ID")

-- Initialize with the main context
function RecordManager.init(context)
    KillTimeTracker = context
end

-- Initialize monster name map
function RecordManager.initMonsterNameMap()
    for i = 1, #RecordManager.BossIDList do
        local fullId = RecordManager.BossIDList[i]
        local baseId = string.match(fullId, "EM%d+")
        
        RecordManager.monsterNameMap[fullId] = RecordManager.BossNameList[i]
        if baseId then
            RecordManager.monsterNameMap[baseId] = RecordManager.BossNameList[i]
        end
    end
end

-- Get monster name from EM ID
function RecordManager.getMonsterName(emId)
    if RecordManager.monsterNameMap[emId] then
        return RecordManager.monsterNameMap[emId]
    end
    
    local baseId = string.match(emId, "EM%d+")
    if baseId and RecordManager.monsterNameMap[baseId] then
        return RecordManager.monsterNameMap[baseId]
    end
    
    return "Unknown Monster (" .. emId .. ")"
end

-- Get weapon name from player
function RecordManager.getWeaponName()
    local weaponType = Core.GetPlayerWeaponType()
    if weaponType >= 0 then
        local weaponTypeName = Core.GetWeaponTypeName(weaponType)
        if weaponTypeName and weaponTypeName ~= "" then
            return weaponTypeName
        end
    end
    
    local mainWeapon = Core.GetPlayerWeaponHandling()
    if mainWeapon then
        if type(mainWeapon.get_Name) == "function" then
            local name = mainWeapon:get_Name()
            if name and name ~= "" then
                return tostring(name)
            end
        elseif mainWeapon.Name then
            local name = mainWeapon.Name
            if name and name ~= "" then
                return tostring(name)
            end
        elseif mainWeapon.get_WeaponType and type(mainWeapon.get_WeaponType) == "function" then
            local weaponType = mainWeapon:get_WeaponType()
            return "Weapon Type " .. tostring(weaponType)
        end
    end
    
    local weaponTypeNames = {
        [0] = "Great Sword", [1] = "Long Sword", [2] = "Sword & Shield", [3] = "Dual Blades",
        [4] = "Hammer", [5] = "Hunting Horn", [6] = "Lance", [7] = "Gunlance",
        [8] = "Switch Axe", [9] = "Charge Blade", [10] = "Insect Glaive", [11] = "Bow",
        [12] = "Light Bowgun", [13] = "Heavy Bowgun"
    }
    
    if weaponType >= 0 and weaponType <= 13 then
        return weaponTypeNames[weaponType]
    end
    
    return "Unknown Weapon"
end

function RecordManager.getBossNameFromContext()
    -- Method 1: Use quest director's target information
    local questDirector = Core.GetQuestDirector()
    if questDirector and questDirector._QuestData then
        local questData = questDirector._QuestData
        
        if questData.getTargetEmId then
            local targetEmIds = questData:getTargetEmId()
            if targetEmIds and targetEmIds:get_Length() > 0 then
                local targetNames = {}
                local count = targetEmIds:get_Length()
                
                for i = 0, count - 1 do
                    local enemyId = targetEmIds:get_Item(i)
                    
                    if enemyId and enemyId ~= 0 then
                        local monsterName = "Unknown"
                        
                        local enemyCodeName = EnemyIdNameMap[enemyId]
                        if enemyCodeName then
                            monsterName = RecordManager.getMonsterName(enemyCodeName)
                        else
                            local coreName = Core.GetEnemyName and Core.GetEnemyName(enemyId) or nil
                            if coreName and coreName ~= "" then
                                monsterName = RecordManager.getMonsterName(coreName)
                            else
                                monsterName = "Enemy_" .. enemyId
                            end
                        end
                        
                        -- If a specific boss name is detected, use it to find the matching target
                        if KillTimeTracker.monster_detector then
                            for ctx, monster in pairs(KillTimeTracker.monster_detector.activeMonsters) do
                                if monster.name == monsterName then
                                    KillTimeTracker.monster_detector.primaryTarget = monster
                                    break
                                end
                            end
                        end
                        
                        local isTempered = KillTimeTracker.config.ManualTemperedStatus
                        if isTempered and not monsterName:find("Tempered") then
                            monsterName = "Tempered " .. monsterName
                        end
                        
                        local formattedName = KillTimeTracker.utils.getFormattedBossName(
                            monsterName, 
                            KillTimeTracker.config.ManualQuestRank, 
                            KillTimeTracker.config.ManualMonsterDifficulty, 
                            isTempered, 
                            KillTimeTracker.config.getPlayerCount()
                        )
                        
                        table.insert(targetNames, formattedName)
                    end
                end
                
                if #targetNames > 0 then
                    if #targetNames == 1 then
                        return targetNames[1]
                    else
                        return table.concat(targetNames, " & ")
                    end
                end
            end
        end
    end
    
    -- Fallback to manual or default methods
    local questRank = KillTimeTracker.config.ManualQuestRank
    local monsterStrength = KillTimeTracker.config.ManualMonsterDifficulty
    local isTempered = KillTimeTracker.config.ManualTemperedStatus
    local playerCount = KillTimeTracker.config.getPlayerCount()
    
    local fallbackName = isTempered and "Tempered Quest Target" or "Quest Target"
    
    return KillTimeTracker.utils.getFormattedBossName(
        fallbackName, questRank, monsterStrength, isTempered, playerCount
    )
end

-- Get best time for a boss
function RecordManager.getBestTimeForBoss(bossName)
    if not KillTimeTracker.data.bestTimes[bossName] then
        return nil
    end
    
    local bestTime = math.huge
    local bestWeapon = nil
    local bestTimestamp = nil
    
    for weapon, record in pairs(KillTimeTracker.data.bestTimes[bossName]) do
        local time = type(record) == "table" and record.time or record
        
        if time < bestTime then
            bestTime = time
            bestWeapon = weapon
            bestTimestamp = type(record) == "table" and record.timestamp
        end
    end
    
    local currentWeapon = RecordManager.getWeaponName()
    local currentWeaponRecord = KillTimeTracker.data.bestTimes[bossName][currentWeapon]
    local currentWeaponBest = nil
    local currentWeaponTimestamp = nil
    
    if currentWeaponRecord then
        currentWeaponBest = type(currentWeaponRecord) == "table" and currentWeaponRecord.time or currentWeaponRecord
        currentWeaponTimestamp = type(currentWeaponRecord) == "table" and currentWeaponRecord.timestamp
    end
    
    return {
        overallBestTime = bestTime ~= math.huge and bestTime or nil,
        overallBestWeapon = bestWeapon,
        overallTimestamp = bestTimestamp,
        currentWeaponBestTime = currentWeaponBest,
        currentWeaponTimestamp = currentWeaponTimestamp
    }
end

-- Add a new recent hunt
function RecordManager.addRecentHunt(bossName, weaponName, killTime, timestamp)
    local huntRecord = {
        bossName = bossName,
        weaponName = weaponName,
        killTime = killTime,
        timestamp = timestamp or os.time(),
        wasNewRecord = false,
        playerCount = KillTimeTracker.config.getPlayerCount() or 1
    }
    
    table.insert(KillTimeTracker.data.recentHunts, 1, huntRecord)
    
    while #KillTimeTracker.data.recentHunts > KillTimeTracker.config.MaxRecentHunts do
        table.remove(KillTimeTracker.data.recentHunts)
    end
    
    KillTimeTracker.data.saveRecentHunts()
    
    return huntRecord
end

-- Update best time for a boss/weapon
function RecordManager.updateBestTime(bossName, weaponName, killTime, timestamp, playerCount)
    timestamp = timestamp or os.time()
    playerCount = playerCount or KillTimeTracker.config.getPlayerCount()
    
    local formattedBossName = KillTimeTracker.utils.formatBossNameWithPlayerCount(bossName, playerCount)
    
    if not KillTimeTracker.data.bestTimes[formattedBossName] then
        KillTimeTracker.data.bestTimes[formattedBossName] = {}
    end
    
    local isNewRecord = false
    local recordInfo = KillTimeTracker.data.bestTimes[formattedBossName][weaponName]
    
    if not recordInfo or (killTime < recordInfo.time) then
        KillTimeTracker.data.bestTimes[formattedBossName][weaponName] = {
            time = killTime,
            timestamp = timestamp,
            playerCount = playerCount
        }
        isNewRecord = true
    end
    
    local timeFormatted = KillTimeTracker.utils.formatTime(killTime)
    
    if isNewRecord then
        local message = string.format(
            "<COLOR 00FF00>New Record!</COLOR> %s with <COLOR FFFF00>%s</COLOR> in <COLOR 00FFFF>%s</COLOR>",
            formattedBossName, weaponName, timeFormatted
        )
        KillTimeTracker.utils.sendNotification(message)
    else
        local message = string.format(
            "%s hunt complete with <COLOR FFFF00>%s</COLOR> in <COLOR 00FFFF>%s</COLOR>",
            formattedBossName, weaponName, timeFormatted
        )
        KillTimeTracker.utils.sendNotification(message)
        
        if KillTimeTracker.config.ShowNewRecordDetails and recordInfo then
            local bestTime = KillTimeTracker.utils.formatTime(recordInfo.time)
            local diffTime = killTime - recordInfo.time
            local diffFormatted = KillTimeTracker.utils.formatTime(diffTime)
            
            local comparisonMessage = string.format(
                "Best time: <COLOR 00FFFF>%s</COLOR> (<COLOR FF5050>+%s</COLOR>)",
                bestTime, diffFormatted
            )
            KillTimeTracker.utils.sendNotification(comparisonMessage)
        end
    end
    
    return isNewRecord
end

return RecordManager