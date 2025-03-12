-----------------------------------------
-- data_manager.lua
-- Data handling for Kill Time Tracker
-----------------------------------------

local json, os = json, os

local DataManager = {
    bestTimes = {},
    recentHunts = {},
    killTimeFilePath = "KillTimes.json",
    recentHuntsFilePath = "RecentHunts.json"
}

local KillTimeTracker = nil

function DataManager.init(context)
    KillTimeTracker = context
end

function DataManager.loadData()
    DataManager.loadKillTimes()
    DataManager.loadRecentHunts()
end

function DataManager.loadKillTimes()
    local ok, data = pcall(json.load_file, DataManager.killTimeFilePath)
    if ok and data and type(data) == "table" then
        DataManager.bestTimes = data
    else
        DataManager.bestTimes = {}
        pcall(json.dump_file, DataManager.killTimeFilePath, DataManager.bestTimes)
    end
end

function DataManager.saveKillTimes()
    pcall(json.dump_file, DataManager.killTimeFilePath, DataManager.bestTimes)
end

function DataManager.loadRecentHunts()
    local ok, data = pcall(json.load_file, DataManager.recentHuntsFilePath)
    if ok and data and type(data) == "table" then
        DataManager.recentHunts = data
    else
        DataManager.recentHunts = {}
    end
end

function DataManager.saveRecentHunts()
    pcall(json.dump_file, DataManager.recentHuntsFilePath, DataManager.recentHunts)
end

function DataManager.resetHuntRecords()
    DataManager.bestTimes = {}
    DataManager.saveKillTimes()
    KillTimeTracker.utils.sendNotification("<COLOR FF0000>All hunt records have been reset!</COLOR>")
end

function DataManager.resetRecentHunts()
    DataManager.recentHunts = {}
    DataManager.saveRecentHunts()
    KillTimeTracker.utils.sendNotification("<COLOR FF0000>All recent hunts have been reset!</COLOR>")
end

function DataManager.migrateDataToIncludeTimestamps()
    local hasUpdates = false
    
    for bossName, weapons in pairs(DataManager.bestTimes) do
        for weaponName, record in pairs(weapons) do
            if type(record) == "number" then
                DataManager.bestTimes[bossName][weaponName] = {
                    time = record,
                    timestamp = os.time()
                }
                hasUpdates = true
            end
        end
    end
    
    if hasUpdates then
        DataManager.saveKillTimes()
    end
    
    hasUpdates = false
    for i, hunt in ipairs(DataManager.recentHunts) do
        if not hunt.timestamp then
            hunt.timestamp = os.time()
            hasUpdates = true
        end
    end
    
    if hasUpdates then
        DataManager.saveRecentHunts()
    end
end

function DataManager.migrateRecentHuntsPlayerCount()
    local hasUpdates = false
    
    for i, hunt in ipairs(DataManager.recentHunts) do
        if hunt.playerCount == nil then
            hunt.playerCount = 1
            hasUpdates = true
        elseif hunt.playerCount == 0 then
            hunt.playerCount = 1
            hasUpdates = true
        end
    end
    
    if hasUpdates then
        DataManager.saveRecentHunts()
    end
end

function DataManager.migrateRecordsToIncludePlayerCount()
    local hasUpdates = false
    
    local bestTimesCopy = {}
    for bossName, weapons in pairs(DataManager.bestTimes) do
        bestTimesCopy[bossName] = {}
        for weapon, record in pairs(weapons) do
            bestTimesCopy[bossName][weapon] = record
        end
    end
    
    for bossName, weapons in pairs(bestTimesCopy) do
        local details = KillTimeTracker.utils.extractBossDetails(bossName)
        local playerCount = details.playerCount or 1
        
        if not bossName:match("by %d+ players") and playerCount > 1 then
            local newBossName = KillTimeTracker.utils.formatBossNameWithPlayerCount(bossName, playerCount)
            
            DataManager.bestTimes[newBossName] = weapons
            DataManager.bestTimes[bossName] = nil
            
            hasUpdates = true
        end
        
        for weapon, record in pairs(weapons) do
            if type(record) == "table" and record.playerCount == nil then
                record.playerCount = playerCount
                hasUpdates = true
            end
        end
    end
    
    if hasUpdates then
        DataManager.saveKillTimes()
    end
    
    hasUpdates = false
    for i, hunt in ipairs(DataManager.recentHunts) do
        if hunt.playerCount and hunt.playerCount > 1 and not hunt.bossName:match("by %d+ players") then
            hunt.bossName = KillTimeTracker.utils.formatBossNameWithPlayerCount(hunt.bossName, hunt.playerCount)
            hasUpdates = true
        end
    end
    
    if hasUpdates then
        DataManager.saveRecentHunts()
    end
end

return DataManager