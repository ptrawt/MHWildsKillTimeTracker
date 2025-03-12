-----------------------------------------
-- game_hooks.lua
-- Game event hooks for Kill Time Tracker
-----------------------------------------

local Core = require("_CatLib")
local os = os

local GameHooks = {}
local KillTimeTracker = nil

function GameHooks.init(context)
    KillTimeTracker = context
end

function GameHooks.setupHooks()
    GameHooks.setupQuestStartHandler()
    GameHooks.setupQuestEndHandler()
end

function GameHooks.setupQuestStartHandler()
    Core.OnQuestStartEnter(function()
        local bossName = KillTimeTracker.records.getBossNameFromContext()
        
        local bestTimeInfo = KillTimeTracker.records.getBestTimeForBoss(bossName)
        local currentWeapon = KillTimeTracker.records.getWeaponName()
        
        if bestTimeInfo and bestTimeInfo.overallBestTime then
            local bestTimeStr = KillTimeTracker.utils.formatTime(bestTimeInfo.overallBestTime)
            local overallMessage = string.format(
                "<COLOR FFFF00>Best Record:</COLOR> %s with <COLOR 00FFFF>%s</COLOR> in <COLOR 00FF00>%s</COLOR>",
                bossName, bestTimeInfo.overallBestWeapon, bestTimeStr
            )
            KillTimeTracker.utils.sendNotification(overallMessage)
            
            if bestTimeInfo.currentWeaponBestTime then
                local currentWeaponBestStr = KillTimeTracker.utils.formatTime(bestTimeInfo.currentWeaponBestTime)
                
                if bestTimeInfo.currentWeaponBestTime ~= bestTimeInfo.overallBestTime or 
                   currentWeapon ~= bestTimeInfo.overallBestWeapon then
                    local currentWeaponMessage = string.format(
                        "<COLOR FFFF00>Your %s Best:</COLOR> <COLOR 00FFFF>%s</COLOR>",
                        currentWeapon, currentWeaponBestStr
                    )
                    KillTimeTracker.utils.sendNotification(currentWeaponMessage)
                end
            else
                local noRecordMessage = string.format(
                    "<COLOR FFFF00>No record yet with %s</COLOR>",
                    currentWeapon
                )
                KillTimeTracker.utils.sendNotification(noRecordMessage)
            end
        else
            local firstTimeMessage = string.format(
                "<COLOR FFFF00>First time hunting %s!</COLOR>",
                bossName
            )
            KillTimeTracker.utils.sendNotification(firstTimeMessage)
        end
    end)
end

function GameHooks.setupQuestEndHandler()
    Core.OnQuestEnd(function()
        local questDirector = Core.GetQuestDirector()
        if not questDirector then return end
        
        local questElapsed = Core.GetQuestElapsedTime() or 0
        local isSuccess = false
        
        local successChecks = {
            function() return questDirector.isQuestClearShowing and questDirector:isQuestClearShowing() end,
            function() return questDirector.isQuestSuccessFreePlayTime and questDirector:isQuestSuccessFreePlayTime() end,
            function() return questDirector.isTargetClearAll and questDirector:isTargetClearAll() end,
            function() return questDirector.isQuestSuccess and questDirector:isQuestSuccess() end
        }
        
        for _, checkFunc in ipairs(successChecks) do
            local success, result = pcall(checkFunc)
            if success and result then
                isSuccess = true
                break
            end
        end
        
        if not isSuccess and questDirector.get_CurFlow then
            local questFlow = questDirector:get_CurFlow()
            
            local success, flowResult = pcall(function()
                if questFlow and questFlow.get_type_definition then
                    local flowType = questFlow:get_type_definition():get_name()
                    
                    if flowType:find("QuestClear") or flowType:find("QuestSuccess") then
                        return true
                    end
                    
                    if flowType == "cQuestResult" then
                        local resultData = nil
                        if questFlow.get_QuestResultData then
                            resultData = questFlow:get_QuestResultData()
                        elseif questFlow.getQuestResultData then
                            resultData = questFlow:getQuestResultData()
                        end
                        
                        if resultData then
                            if resultData.get_QuestStatus then
                                return resultData:get_QuestStatus() == 1
                            elseif resultData.getQuestStatus then
                                return resultData:getQuestStatus() == 1
                            end
                        end
                    end
                end
                return false
            end)
            
            if success and flowResult then
                isSuccess = true
            end
        end
        
        if not isSuccess then
            if KillTimeTracker.utils and KillTimeTracker.utils.logDebug then
                KillTimeTracker.utils.logDebug("Quest not successful. Skipping record.")
            end
            return
        end
        
        local bossName = KillTimeTracker.records.getBossNameFromContext()
        local weaponName = KillTimeTracker.records.getWeaponName()
        local timestamp = os.time()
        local playerCount = KillTimeTracker.config.getPlayerCount()

        local huntRecord = KillTimeTracker.records.addRecentHunt(bossName, weaponName, questElapsed, timestamp)
        huntRecord.playerCount = playerCount
        
        local isNewRecord = KillTimeTracker.records.updateBestTime(bossName, weaponName, questElapsed, timestamp, playerCount)
        
        huntRecord.wasNewRecord = isNewRecord
        KillTimeTracker.data.saveRecentHunts()
        
        KillTimeTracker.data.saveKillTimes()

        local playerCountMessage = string.format(
            "<COLOR FFFF00>Quest Completed</COLOR> with <COLOR 00FF00>%d player(s)</COLOR>",
            playerCount
        )
        KillTimeTracker.utils.sendNotification(playerCountMessage)
    end)
end

return GameHooks