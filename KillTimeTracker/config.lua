-----------------------------------------
-- config.lua
-- Configuration handling for Kill Time Tracker
-----------------------------------------

local re, json = re, json

local Config = {
    IsWindowOpen = false,
    SystemNotifications = true,
    ShowNewRecordDetails = true,
    MaxRecentHunts = 10,
    UseManualRankStar = true,
    ManualQuestRank = 1,
    ManualMonsterDifficulty = 3,
    ManualTemperedStatus = false,
    ManualPlayerCount = 1,
    FallbackAnotherWeapon = true,
    CurrentSet = -1,
    HuntRecordsPlayerFilter = 0,
    AutoDetectMonsterInfo = true  -- New option for auto-detection
}

local KillTimeTracker = nil
local configPath = "KillTimeTrackerConfig.json"

-- Initialize with the main context
function Config.init(context)
    KillTimeTracker = context
end

-- Load configuration from file
function Config.loadConfig()
    local ok, data = pcall(json.load_file, configPath)
    if ok and data and type(data) == "table" then
        if data.SystemNotifications ~= nil then
            Config.SystemNotifications = data.SystemNotifications
        end
        if data.ShowNewRecordDetails ~= nil then
            Config.ShowNewRecordDetails = data.ShowNewRecordDetails
        end
        
        if data.ManualQuestRank ~= nil then
            Config.ManualQuestRank = data.ManualQuestRank
        end
        if data.ManualMonsterDifficulty ~= nil then
            Config.ManualMonsterDifficulty = data.ManualMonsterDifficulty
        elseif data.ManualMonsterStar ~= nil then
            Config.ManualMonsterDifficulty = data.ManualMonsterStar
        elseif data.ManualQuestStar ~= nil then
            Config.ManualMonsterDifficulty = data.ManualQuestStar
        end
        if data.ManualTemperedStatus ~= nil then
            Config.ManualTemperedStatus = data.ManualTemperedStatus
        end
        
        if data.IsWindowOpen ~= nil then
            Config.IsWindowOpen = data.IsWindowOpen
            KillTimeTracker.ui.isWindowOpen = data.IsWindowOpen
        end
        
        if data.ManualPlayerCount ~= nil then
            Config.ManualPlayerCount = data.ManualPlayerCount
        end
        
        if data.HuntRecordsPlayerFilter ~= nil then
            Config.HuntRecordsPlayerFilter = data.HuntRecordsPlayerFilter
        end
        
        if data.MaxRecentHunts ~= nil then
            Config.MaxRecentHunts = data.MaxRecentHunts
        end
        
        -- Load new auto-detection setting
        if data.AutoDetectMonsterInfo ~= nil then
            Config.AutoDetectMonsterInfo = data.AutoDetectMonsterInfo
        end
    end
end

-- Save configuration to file
function Config.saveConfig()
    Config.IsWindowOpen = KillTimeTracker.ui.isWindowOpen
    pcall(json.dump_file, configPath, Config)
end

-- Get current player count
function Config.getPlayerCount()
    if Config.ManualPlayerCount and Config.ManualPlayerCount > 0 then
        return Config.ManualPlayerCount
    end
    return 1
end

return Config