-----------------------------------------
-- monster_detector.lua
-- Monster detection and information for Kill Time Tracker
-----------------------------------------

local Core = require("_CatLib")
local sdk = sdk

local MonsterDetector = {
    -- Monster information
    monsterDefinitions = {},
    activeMonsters = {},
    
    -- SDK types and methods
    Enemy_ContextHolder = nil,
    EnemyContextHolder_Context = nil,
    GetEnemyNameFunc = nil,
    GetMsgFunc = nil,
    
    -- Quest rank detection
    questRank = 1,
    questDifficulty = 3,
    
    -- Track the primary target
    primaryTarget = nil
}

local KillTimeTracker = nil

-- Initialize with the main context
function MonsterDetector.init(context)
    KillTimeTracker = context
    
    -- Find SDK types needed for monster detection
    MonsterDetector.Enemy_ContextHolder = sdk.find_type_definition("app.EnemyCharacter"):get_field("_Context")
    MonsterDetector.EnemyContextHolder_Context = sdk.find_type_definition("app.cEnemyContextHolder"):get_field("_Em")
    MonsterDetector.GetEnemyNameFunc = sdk.find_type_definition("app.EnemyDef"):get_method("EnemyName(app.EnemyDef.ID)")
    MonsterDetector.GetMsgFunc = sdk.find_type_definition("via.gui.message"):get_method("get(System.Guid)")
    
    -- Initialize the enemy types list
    MonsterDetector.initEnemyTypesList()
    
    -- Hook into enemy updates
    MonsterDetector.setupHooks()
end

-- Setup hooks for monster detection
function MonsterDetector.setupHooks()
    -- Hook into the enemy update method
    sdk.hook(
        sdk.find_type_definition("app.EnemyCharacter"):get_method("doUpdateEnd"),
        function(args)
            pcall(MonsterDetector.updateMonster, sdk.to_managed_object(args[2]))
        end,
        function(retval) return retval end
    )
    
    -- Hook quest scene changes
    sdk.hook(
        sdk.find_type_definition("app.EnemyManager"):get_method("evSceneLoadEnd_ThroughJunction"),
        function(args)
            pcall(MonsterDetector.onSceneLoadEnd)
        end,
        function(retval) return retval end
    )
    
    sdk.hook(
        sdk.find_type_definition("app.EnemyManager"):get_method("evSceneLoadEnd_FastTravel"),
        function(args)
            pcall(MonsterDetector.onSceneLoadEnd)
        end,
        function(retval) return retval end
    )
    
    -- Try to hook targeting system if available
    pcall(function()
        local targetMethod = sdk.find_type_definition("app.TargetSystem"):get_method("setTarget")
        if targetMethod then
            sdk.hook(
                targetMethod,
                function(args)
                    pcall(MonsterDetector.onTargetChanged, args)
                end,
                function(retval) return retval end
            )
        end
    end)
    
    -- Try to hook HUD update for target changes
    pcall(function()
        local hudMethod = sdk.find_type_definition("snow.gui.FieldHudManager"):get_method("update")
        if hudMethod then
            sdk.hook(
                hudMethod,
                function(args)
                    pcall(MonsterDetector.checkHudForTargets)
                end,
                function(retval) return retval end
            )
        end
    end)
end

-- Scene load end handler
function MonsterDetector.onSceneLoadEnd()
    -- Clear the monster list and primary target when scene changes
    MonsterDetector.activeMonsters = {}
    MonsterDetector.primaryTarget = nil
    
    -- Try to detect quest rank and difficulty
    MonsterDetector.detectQuestInfo()
    
    if KillTimeTracker.utils then
        KillTimeTracker.utils.logDebug("Scene changed, cleared monster list and detected quest info")
    end
end

-- Handle target changes
function MonsterDetector.onTargetChanged(args)
    if #args < 3 then return end
    
    local targetObject = sdk.to_managed_object(args[3])
    if not targetObject then return end
    
    -- Check if this is a monster being targeted
    for ctx, monster in pairs(MonsterDetector.activeMonsters) do
        if ctx == targetObject or 
           (ctx.get_UniqueIndex and targetObject.get_UniqueIndex and 
            ctx:get_UniqueIndex() == targetObject:get_UniqueIndex()) then
            
            -- This monster is being targeted, mark it as primary
            MonsterDetector.primaryTarget = monster
            
            if KillTimeTracker.utils then
                KillTimeTracker.utils.logDebug("Target changed to: " .. monster.name)
            end
            
            break
        end
    end
end

-- Check HUD for monster targets
function MonsterDetector.checkHudForTargets()
    local uiManager = sdk.get_managed_singleton("snow.gui.FieldHudManager") or 
                     sdk.get_managed_singleton("snow.QuestHudManager")
    
    if not uiManager then return end
    
    -- Try to find the highlighted monster
    pcall(function()
        if uiManager.getHighlightedMonster then
            local highlightedMonster = uiManager:getHighlightedMonster()
            if highlightedMonster then
                for ctx, monster in pairs(MonsterDetector.activeMonsters) do
                    if ctx == highlightedMonster or 
                       (ctx.get_UniqueIndex and highlightedMonster.get_UniqueIndex and 
                        ctx:get_UniqueIndex() == highlightedMonster:get_UniqueIndex()) then
                        
                        MonsterDetector.primaryTarget = monster
                        
                        if KillTimeTracker.utils then
                            KillTimeTracker.utils.logDebug("Found highlighted monster in HUD: " .. monster.name)
                        end
                        
                        return
                    end
                end
            end
        end
    end)
end

function MonsterDetector.detectQuestInfo()
    local questManager = sdk.get_managed_singleton("snow.QuestManager")
    if not questManager then return end
    
    -- Try to get the quest data
    local questData = nil
    pcall(function()
        if questManager.getActiveQuestData then
            questData = questManager:getActiveQuestData()
        elseif questManager._ActiveQuestData then
            questData = questManager._ActiveQuestData
        end
    end)
    
    if not questData then return end
    
    -- Extract quest rank and difficulty with expanded detection
    pcall(function()
        local questRank = 1
        local difficulty = 3
        
        -- Try to get quest data from different sources
        local sources = {
            rank = {
                "get_QuestRank", "QuestRank", "get_Rank", "_Rank", 
                "get_CurrentRank", "CurrentRank"
            },
            difficulty = {
                "get_Difficulty", "Difficulty", "get_DifficultyLevel", 
                "_Difficulty", "get_Star", "Star"
            }
        }
        
        -- Detect rank
        for _, source in ipairs(sources.rank) do
            local success, result = pcall(function()
                if type(questData[source]) == "function" then
                    return questData[source](questData)
                elseif questData[source] ~= nil then
                    return questData[source]
                end
            end)
            
            if success and result then
                questRank = math.max(1, math.min(8, tonumber(result) or 1))
                break
            end
        end
        
        -- Detect difficulty
        for _, source in ipairs(sources.difficulty) do
            local success, result = pcall(function()
                if type(questData[source]) == "function" then
                    return questData[source](questData)
                elseif questData[source] ~= nil then
                    return questData[source]
                end
            end)
            
            if success and result then
                difficulty = math.max(1, math.min(5, tonumber(result) or 3))
                break
            end
        end
        
        -- Additional check for specific quest target info
        pcall(function()
            local targetEmIds = questData:getTargetEmId()
            if targetEmIds and targetEmIds:get_Length() > 0 then
                local primaryEmId = targetEmIds:get_Item(0)
                local enemyIdNameMap = Core.GetEnumMap("app.EnemyDef.ID")
                local enemyCodeName = enemyIdNameMap[primaryEmId]
                
                if enemyCodeName then
                    local monsterName = KillTimeTracker.records.getMonsterName(enemyCodeName)
                    
                    if KillTimeTracker.utils and KillTimeTracker.utils.logDebug then
                        KillTimeTracker.utils.logDebug(string.format(
                            "Quest Target: %s, Detected Rank: %d, Difficulty: %d", 
                            monsterName, questRank, difficulty
                        ))
                    end
                end
            end
        end)
        
        -- Update detector and config
        MonsterDetector.questRank = questRank
        MonsterDetector.questDifficulty = difficulty
        
        KillTimeTracker.config.ManualQuestRank = questRank
        KillTimeTracker.config.ManualMonsterDifficulty = difficulty
        
        if KillTimeTracker.utils and KillTimeTracker.utils.logDebug then
            KillTimeTracker.utils.logDebug(string.format(
                "Detected Quest Rank: %d, Difficulty: %d", questRank, difficulty
            ))
        end
    end)
end

-- Initialize the enemy types list
function MonsterDetector.initEnemyTypesList()
    -- Get the enemy enum
    local enemyEnum = MonsterDetector.generateEnumValues("app.EnemyDef.ID")
    
    -- Get the enemy manager
    local enemyManager = sdk.get_managed_singleton("app.EnemyManager")
    if not enemyManager then return end
    
    -- Get valid Em IDs
    local ValidEmIDs = sdk.find_type_definition("app.EnemyManager"):get_field("_ValidEmIds")
    local validEms = ValidEmIDs:get_data(enemyManager)
    if not validEms then return end
    
    -- Get all valid enemy IDs
    local int_array_getItem = sdk.find_type_definition("app.EnemyDef.ID[]"):get_method("get_Item")
    local size = validEms:get_size()
    
    for i = 0, size - 1 do
        pcall(function()
            local EmID = int_array_getItem(validEms, i)
            if EmID and enemyEnum[EmID] then
                local name = MonsterDetector.getEnemyName(EmID)
                MonsterDetector.monsterDefinitions[EmID] = {
                    emType = EmID,
                    emString = enemyEnum[EmID],
                    name = name
                }
                
                if KillTimeTracker.utils and KillTimeTracker.utils.logDebug then
                    KillTimeTracker.utils.logDebug("Registered monster type: " .. name)
                end
            end
        end)
    end
end

-- Get the name of an enemy by ID
function MonsterDetector.getEnemyName(emId)
    -- Try to find the name in our cached names
    local monsterDef = MonsterDetector.monsterDefinitions[emId]
    if monsterDef and monsterDef.name then
        return monsterDef.name
    end
    
    -- Try to get the name from the game
    local name = "Unknown"
    pcall(function()
        local guid = MonsterDetector.GetEnemyNameFunc(nil, emId)
        if guid then
            local nameStr = MonsterDetector.GetMsgFunc(nil, guid)
            if nameStr and nameStr ~= "" then
                name = nameStr
            end
        end
    end)
    
    return name
end

-- Update a monster's information
function MonsterDetector.updateMonster(enemy)
    if not enemy then return end
    
    -- Get enemy context
    local ctx_holder = MonsterDetector.Enemy_ContextHolder:get_data(enemy)
    if not ctx_holder then return end
    
    local ctx = MonsterDetector.EnemyContextHolder_Context:get_data(ctx_holder)
    if not ctx then return end
    
    -- Only handle boss enemies
    local isBoss = ctx:get_IsBoss()
    if not isBoss then return end
    
    -- Check if we already have this monster
    if MonsterDetector.activeMonsters[ctx] then
        -- Update last seen time and any changed status
        local monster = MonsterDetector.activeMonsters[ctx]
        monster.lastUpdate = os.time()
        
        -- Update death state
        pcall(function()
            local browser = ctx:get_Browser()
            if browser then
                monster.isDead = browser:get_IsHealthZero()
                
                -- Check if this was the primary target and it died
                if monster == MonsterDetector.primaryTarget and monster.isDead then
                    MonsterDetector.primaryTarget = nil
                end
            end
        end)
        
        return
    end
    
    -- Create a new monster entry
    local monster = MonsterDetector.createMonsterInfo(ctx)
    if monster and monster.emId then
        MonsterDetector.activeMonsters[ctx] = monster
        
        -- Log the detected monster
        if KillTimeTracker.utils and KillTimeTracker.utils.logDebug then
            KillTimeTracker.utils.logDebug("Detected monster: " .. monster.name)
        end
        
        -- Update the game info with detected monster
        MonsterDetector.updateGameInfoWithMonster(monster)
        
        -- Check if this might be a primary target
        if monster.isTarget or monster.isTempered then
            MonsterDetector.primaryTarget = monster
            if KillTimeTracker.utils and KillTimeTracker.utils.logDebug then
                KillTimeTracker.utils.logDebug("Set as primary target: " .. monster.name)
            end
        end
    end
end

function MonsterDetector.createMonsterInfo(ctx)
    local monster = {}
    monster.lastUpdate = os.time()
    
    -- Try to get monster ID
    local id = ctx:get_EmID()
    if not id then return nil end
    
    monster.emId = id
    monster.uniqueId = ctx:get_UniqueIndex()
    
    -- Get the monster name
    monster.name = MonsterDetector.getEnemyName(id)
    
    -- More comprehensive target detection with extensive logging
    pcall(function()
        monster.isTarget = false
        local targetChecks = {
            "get_IsTarget", "IsTarget",
            "get_IsPrimaryTarget", "IsPrimaryTarget", 
            "get_IsQuestTarget", "IsQuestTarget"
        }
        
        for _, check in ipairs(targetChecks) do
            local success, result = pcall(function()
                if type(ctx[check]) == "function" then
                    return ctx[check](ctx)
                elseif ctx[check] ~= nil then
                    return ctx[check]
                end
            end)
            
            if success and result then
                monster.isTarget = true
                if KillTimeTracker.utils and KillTimeTracker.utils.logDebug then
                    KillTimeTracker.utils.logDebug(string.format(
                        "Monster %s marked as target by %s", monster.name, check
                    ))
                end
                break
            end
        end
    end)
    
    -- Check quest director's target
    pcall(function()
        local questDirector = Core.GetQuestDirector()
        if questDirector and questDirector._QuestData then
            local targetEmIds = questDirector._QuestData:getTargetEmId()
            if targetEmIds and targetEmIds:get_Length() > 0 then
                for i = 0, targetEmIds:get_Length() - 1 do
                    local targetEmId = targetEmIds:get_Item(i)
                    if targetEmId == id then
                        monster.isTarget = true
                        monster.isQuestTarget = true
                        if KillTimeTracker.utils and KillTimeTracker.utils.logDebug then
                            KillTimeTracker.utils.logDebug(string.format(
                                "Monster %s confirmed as quest director's target", monster.name
                            ))
                        end
                        break
                    end
                end
            end
        end
    end)
    
    return monster
end

-- Update game info with detected monster
function MonsterDetector.updateGameInfoWithMonster(monster)
    -- Update tempered flag
    if monster.isTempered then
        KillTimeTracker.config.ManualTemperedStatus = true
    end
end

function MonsterDetector.getPrimaryQuestTarget()
    -- Add comprehensive logging for all active monsters
    log.debug("[KillTimeTracker] --- Active Monsters Debug ---")
    for ctx, monster in pairs(MonsterDetector.activeMonsters) do
        log.debug(string.format(
            "[KillTimeTracker] Monster: %s, EmID: %s, isTarget: %s, isDead: %s, UniqueIndex: %s", 
            monster.name, 
            ctx.get_EmID and ctx:get_EmID() or "N/A",
            tostring(monster.isTarget),
            tostring(monster.isDead),
            ctx.get_UniqueIndex and tostring(ctx:get_UniqueIndex()) or "N/A"
        ))
    end
    
    log.debug("[KillTimeTracker] --- Quest Director Debug ---")
    
    local questDirector = Core.GetQuestDirector()
    if questDirector and questDirector._QuestData then
        log.debug("[KillTimeTracker] Quest Director exists")
        
        pcall(function()
            if questDirector._QuestData.getTargetEmId then
                local targetEmIds = questDirector._QuestData:getTargetEmId()
                if targetEmIds and targetEmIds:get_Length() > 0 then
                    for i = 0, targetEmIds:get_Length() - 1 do
                        log.debug(string.format(
                            "[KillTimeTracker] Quest Target EM ID %d: %s", 
                            i, tostring(targetEmIds:get_Item(i))
                        ))
                    end
                end
            end
        end)
    else
        log.debug("[KillTimeTracker] No Quest Director found")
    end
    
    local questData = questDirector._QuestData
    
    -- Try to get target EM IDs directly from quest data
    pcall(function()
        if questData.getTargetEmId then
            local targetEmIds = questData:getTargetEmId()
            if targetEmIds and targetEmIds:get_Length() > 0 then
                local primaryEmId = targetEmIds:get_Item(0)
                
                -- Find matching monster in active monsters by EM ID
                for ctx, monster in pairs(MonsterDetector.activeMonsters) do
                    if ctx.get_EmID and ctx:get_EmID() == primaryEmId then
                        if KillTimeTracker.utils and KillTimeTracker.utils.logDebug then
                            KillTimeTracker.utils.logDebug("Found primary target by quest EM ID: " .. monster.name)
                        end
                        MonsterDetector.primaryTarget = monster
                        return monster
                    end
                end
            end
        end
    end)
    
    -- If direct EM ID matching fails, try name-based matching
    pcall(function()
        if questData.getTargetEmId then
            local targetEmIds = questData:getTargetEmId()
            if targetEmIds and targetEmIds:get_Length() > 0 then
                local primaryEmId = targetEmIds:get_Item(0)
                
                -- Get the expected monster name from the EM ID
                local enemyIdNameMap = Core.GetEnumMap("app.EnemyDef.ID")
                local enemyCodeName = enemyIdNameMap[primaryEmId]
                
                if enemyCodeName then
                    local expectedMonsterName = KillTimeTracker.records.getMonsterName(enemyCodeName)
                    
                    -- Find monster by name
                    for ctx, monster in pairs(MonsterDetector.activeMonsters) do
                        if monster.name == expectedMonsterName then
                            if KillTimeTracker.utils and KillTimeTracker.utils.logDebug then
                                KillTimeTracker.utils.logDebug("Found primary target by expected name: " .. monster.name)
                            end
                            MonsterDetector.primaryTarget = monster
                            return monster
                        end
                    end
                end
            end
        end
    end)
    
    -- Fallback to other detection methods
    for ctx, monster in pairs(MonsterDetector.activeMonsters) do
        -- Check for monsters with explicit target flags
        if monster.isTarget or monster.isQuestTarget then
            if KillTimeTracker.utils and KillTimeTracker.utils.logDebug then
                KillTimeTracker.utils.logDebug("Found primary target by target flag: " .. monster.name)
            end
            MonsterDetector.primaryTarget = monster
            return monster
        end
    end
    
    -- If no specific target found, return first non-dead monster
    for ctx, monster in pairs(MonsterDetector.activeMonsters) do
        if not monster.isDead then
            if KillTimeTracker.utils and KillTimeTracker.utils.logDebug then
                KillTimeTracker.utils.logDebug("Using first living monster as fallback: " .. monster.name)
            end
            MonsterDetector.primaryTarget = monster
            return monster
        end
    end
    
    return nil
end

-- Get current monster info for the hunt - without using getBossNameFromContext
function MonsterDetector.getCurrentTargetMonsterInfo()
    -- Try to get the primary target first
    local target = MonsterDetector.getPrimaryQuestTarget()
    
    if target then
        local temperedPrefix = target.isTempered and "Tempered " or ""
        local baseName = temperedPrefix .. target.name
        
        return {
            name = baseName,
            questRank = MonsterDetector.questRank,
            monsterStrength = MonsterDetector.questDifficulty,
            isTempered = target.isTempered
        }
    end
    
    -- Try to use any detected monsters
    local firstMonster = nil
    for _, monster in pairs(MonsterDetector.activeMonsters) do
        if not monster.isDead then
            firstMonster = monster
            break
        end
    end
    
    if firstMonster then
        local temperedPrefix = firstMonster.isTempered and "Tempered " or ""
        local baseName = temperedPrefix .. firstMonster.name
        
        return {
            name = baseName,
            questRank = MonsterDetector.questRank,
            monsterStrength = MonsterDetector.questDifficulty,
            isTempered = firstMonster.isTempered
        }
    end
    
    -- Fall back to manual settings
    return {
        name = "Unknown Monster",
        questRank = KillTimeTracker.config.ManualQuestRank,
        monsterStrength = KillTimeTracker.config.ManualMonsterDifficulty,
        isTempered = KillTimeTracker.config.ManualTemperedStatus
    }
end

-- Helper function to directly access quest info from quest director
function MonsterDetector.getQuestDirectorMonsterInfo()
    local questDirector = Core.GetQuestDirector()
    if not questDirector then 
        return nil
    end
    
    local questData = questDirector._QuestData
    if not questData then
        return nil
    end
    
    local questRank = KillTimeTracker.config.ManualQuestRank
    local monsterStrength = KillTimeTracker.config.ManualMonsterDifficulty
    local isTempered = KillTimeTracker.config.ManualTemperedStatus
    
    if questData.getTargetEmId then
        local targetEmIds = questData:getTargetEmId()
        if targetEmIds and targetEmIds:get_Length() > 0 then
            local targetNames = {}
            local count = targetEmIds:get_Length()
            
            for i = 0, count - 1 do
                local enemyId = targetEmIds:get_Item(i)
                
                if enemyId and enemyId ~= 0 then
                    local monsterName = "Unknown"
                    
                    local EnemyIdNameMap = Core.GetEnumMap("app.EnemyDef.ID")
                    local enemyCodeName = EnemyIdNameMap[enemyId]
                    if enemyCodeName then
                        monsterName = KillTimeTracker.records.getMonsterName(enemyCodeName)
                    else
                        local coreName = Core.GetEnemyName and Core.GetEnemyName(enemyId) or nil
                        if coreName and coreName ~= "" then
                            monsterName = KillTimeTracker.records.getMonsterName(coreName)
                        else
                            monsterName = "Enemy_" .. enemyId
                        end
                    end
                    
                    if isTempered and not monsterName:find("Tempered") then
                        monsterName = "Tempered " .. monsterName
                    end
                    
                    table.insert(targetNames, monsterName)
                end
            end
            
            if #targetNames > 0 then
                if #targetNames == 1 then
                    return {
                        name = targetNames[1],
                        questRank = questRank,
                        monsterStrength = monsterStrength,
                        isTempered = isTempered
                    }
                else
                    return {
                        name = table.concat(targetNames, " & "),
                        questRank = questRank,
                        monsterStrength = monsterStrength,
                        isTempered = isTempered
                    }
                end
            end
        end
    end
    
    return nil
end

-- Helper function to generate enum values
function MonsterDetector.generateEnumValues(typename)
    local t = sdk.find_type_definition(typename)
    if not t then return {} end

    local fields = t:get_fields()
    local enum = {}

    for _, field in ipairs(fields) do
        if field:is_static() then
            local name = field:get_name()
            local raw_value = field:get_data(nil)
            enum[raw_value] = name
        end
    end

    return enum
end

return MonsterDetector