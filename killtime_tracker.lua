-----------------------------------------
-- killtime_tracker.lua
-- Kill Time Tracker mod that saves (boss name, weapon type, best kill time)
-- By ptrawt March 12, 2025
-----------------------------------------

local re, sdk, imgui, log, json = re, sdk, imgui, log, json
local Core, CONST = require("_CatLib"), require("_CatLib.const")

local mod = Core.NewMod("Kill Time Tracker")
local version = "1.1.0"

local function logDebug(message)
    log.debug("[KillTimeTracker]: " .. message)
end

local KillTimeTracker = {
    mod = mod,
    version = version
}

local Utils = require("KillTimeTracker.utils")
KillTimeTracker.utils = Utils
Utils.init(KillTimeTracker)

local Config = require("KillTimeTracker.config")
KillTimeTracker.config = Config
Config.init(KillTimeTracker)

local DataManager = require("KillTimeTracker.data_manager")
KillTimeTracker.data = DataManager
DataManager.init(KillTimeTracker)

local RecordManager = require("KillTimeTracker.record_manager")
KillTimeTracker.records = RecordManager
RecordManager.init(KillTimeTracker)

local MonsterDetector = require("KillTimeTracker.monster_detector")
KillTimeTracker.monster_detector = MonsterDetector
MonsterDetector.init(KillTimeTracker)

local GameHooks = require("KillTimeTracker.game_hooks")
KillTimeTracker.hooks = GameHooks
GameHooks.init(KillTimeTracker)

local UIManager = require("KillTimeTracker.ui_manager")
KillTimeTracker.ui = UIManager
UIManager.init(KillTimeTracker)

local function initMod()
    Config.loadConfig()
    DataManager.loadData()
    RecordManager.initMonsterNameMap()
    GameHooks.setupHooks()
    UIManager.setupUIHandlers()
    
    DataManager.migrateDataToIncludeTimestamps()
    DataManager.migrateRecentHuntsPlayerCount()
    DataManager.migrateRecordsToIncludePlayerCount()
    
    logDebug("Kill Time Tracker v" .. version .. " initialized successfully")
end

initMod()

return mod