-----------------------------------------
-- utils.lua
-- Utility functions for Kill Time Tracker
-----------------------------------------

local re, sdk, imgui, log, json = re, sdk, imgui, log, json
local Core = require("_CatLib")

local Utils = {}
local KillTimeTracker = nil

function Utils.init(context)
    KillTimeTracker = context
end

function Utils.formatTime(seconds)
    local truncatedSeconds = math.floor(seconds * 100) / 100
    local minutes = math.floor(truncatedSeconds / 60)
    local secs = math.floor(truncatedSeconds % 60)
    local ms = math.floor((truncatedSeconds * 100 + 0.000001) % 100)
    return string.format("%d'%02d\"%02d", minutes, secs, ms)
end

function Utils.getQuestRankText(rank)
    if rank >= 1 and rank <= 3 then
        return "LR" .. rank
    elseif rank >= 4 and rank <= 8 then
        return "HR" .. rank
    else
        return "R" .. (rank - 8)
    end
end

function Utils.getMonsterStrengthText(strength)
    return "Strength" .. strength
end

function Utils.formatBossNameWithPlayerCount(bossName, playerCount)
    if not playerCount or playerCount <= 1 then
        if bossName:match("by %d+ players") then
            return bossName:gsub(" by %d+ players", "")
        end
        return bossName
    end
    
    if bossName:match("by %d+ players") then
        return bossName:gsub("by %d+ players", string.format("by %d players", playerCount))
    end
    
    return string.format("%s by %d players", bossName, playerCount)
end

function Utils.getFormattedBossName(monsterName, questRank, monsterStrength, isTempered, playerCount)
    local temperedPrefix = ""
    if isTempered and not monsterName:match("^Tempered") then
        temperedPrefix = "Tempered "
    end
    
    local questRankText = Utils.getQuestRankText(questRank)
    local difficultyText = Utils.getMonsterStrengthText(monsterStrength)
    
    local baseName = string.format("%s%s (%s %s)", 
        temperedPrefix, monsterName, questRankText, difficultyText)
    
    if playerCount and playerCount > 1 then
        return string.format("%s by %d players", baseName, playerCount)
    end
    
    return baseName
end

function Utils.extractBossDetails(bossName)
    local isTempered = bossName:match("^Tempered") ~= nil
    
    local cleanName = bossName:gsub("^Tempered%s+", "")
    
    local baseName = cleanName:match("^([^(]+)")
    if baseName then
        baseName = baseName:gsub("%s+$", "")
    else
        baseName = "Unknown"
    end
    
    local rankText, strengthText = bossName:match("%(([^%s]+)%s+([^%)]+)%)")
    
    local playerCount = bossName:match("by (%d+) players?")
    playerCount = playerCount and tonumber(playerCount) or 1
    
    local rankNumber = 0
    local strengthNumber = 0
    
    if rankText then
        if rankText:match("^LR(%d+)$") then
            rankNumber = tonumber(rankText:match("^LR(%d+)$")) or 0
        elseif rankText:match("^HR(%d+)$") then
            rankNumber = tonumber(rankText:match("^HR(%d+)$")) or 0
            if rankNumber > 0 then
                rankNumber = rankNumber + 3
            end
        elseif rankText:match("^R(%d+)$") then
            rankNumber = tonumber(rankText:match("^R(%d+)$")) or 0
            rankNumber = rankNumber + 9
        end
    end
    
    if strengthText then
        strengthNumber = tonumber(strengthText:match("Strength(%d+)")) or 0
    end
    
    return {
        name = baseName,
        isTempered = isTempered,
        rankNumber = rankNumber,
        strengthNumber = strengthNumber,
        playerCount = playerCount,
        fullName = bossName
    }
end

function Utils.sortBossNames(bossNames)
    local bossDetails = {}
    for i, bossName in ipairs(bossNames) do
        local details = Utils.extractBossDetails(bossName)
        details.originalIndex = i
        table.insert(bossDetails, details)
    end
    
    table.sort(bossDetails, function(a, b)
        if a.rankNumber ~= b.rankNumber then
            return a.rankNumber > b.rankNumber
        end
        
        if a.isTempered ~= b.isTempered then
            return a.isTempered
        end
        
        if a.name ~= b.name then
            return a.name < b.name
        end
        
        if a.strengthNumber ~= b.strengthNumber then
            return a.strengthNumber > b.strengthNumber
        end
        
        if a.playerCount ~= b.playerCount then
            return a.playerCount < b.playerCount
        end
        
        return a.originalIndex < b.originalIndex
    end)
    
    local sortedNames = {}
    for _, details in ipairs(bossDetails) do
        table.insert(sortedNames, details.fullName)
    end
    
    return sortedNames
end

function Utils.sendNotification(message)
    if not KillTimeTracker or not KillTimeTracker.config or not KillTimeTracker.config.SystemNotifications then 
        if Core.SendMessage then
            Core.SendMessage(message)
        else
            local chatManager = sdk.get_managed_singleton("snow.gui.ChatManager")
            if chatManager then
                if chatManager.reqAddChatInfomation then
                    chatManager:reqAddChatInfomation(message, 2)
                elseif chatManager.reqAddSystemMessage then
                    chatManager:reqAddSystemMessage(message)
                end
            end
        end
        return
    end
    
    if not KillTimeTracker.config.SystemNotifications then return end
    
    if Core.SendMessage then
        Core.SendMessage(message)
    else
        local chatManager = sdk.get_managed_singleton("snow.gui.ChatManager")
        if chatManager then
            if chatManager.reqAddChatInfomation then
                chatManager:reqAddChatInfomation(message, 2)
            elseif chatManager.reqAddSystemMessage then
                chatManager:reqAddSystemMessage(message)
            end
        end
    end
end

return Utils