-----------------------------------------
-- ui_manager.lua
-- UI handling for Kill Time Tracker
-----------------------------------------

local re, imgui = re, imgui
local Vector2f = Vector2f

local UIManager = {
    isWindowOpen = false,
    wasWindowOpen = false,
    
    manualEntryState = {
        isOpen = false,
        selectedBoss = "",
        selectedWeapon = "",
        minutes = 0,
        seconds = 0,
        milliseconds = 0,
        showMonsterList = false,
        showWeaponList = false,
        questRank = 1,
        monsterStrength = 3,
        isTempered = false,
        playerCount = 1
    }
}

local KillTimeTracker = nil

function UIManager.init(context)
    KillTimeTracker = context
    UIManager.isWindowOpen = KillTimeTracker.config.IsWindowOpen
end

function UIManager.setupUIHandlers()
    re.on_draw_ui(function()
        if imgui.button("Toggle Kill Time Tracker") then
            UIManager.isWindowOpen = not UIManager.isWindowOpen
            KillTimeTracker.config.IsWindowOpen = UIManager.isWindowOpen
            KillTimeTracker.config.saveConfig()
        end
        
        UIManager.drawManualEntryDialog()
        
        if UIManager.isWindowOpen then
            UIManager.wasWindowOpen = true
            
            imgui.push_style_var(11, 5.0)
            imgui.push_style_var(2, 10.0)
            
            imgui.set_next_window_size(Vector2f.new(520, 550), 4)
            
            UIManager.isWindowOpen = imgui.begin_window("[Kill Time Tracker] Monster Hunter Wilds Records", UIManager.isWindowOpen, 32)
            
            UIManager.drawMainContent()
            
            imgui.end_window()
            
            imgui.pop_style_var(2)
        elseif UIManager.wasWindowOpen then
            UIManager.wasWindowOpen = false
            KillTimeTracker.config.IsWindowOpen = UIManager.isWindowOpen
            KillTimeTracker.config.saveConfig()
        end
    end)
end

function UIManager.drawMainContent()
    UIManager.drawHuntRecords()
    UIManager.drawRecentHunts()
    UIManager.drawSettings()
    UIManager.drawAbout()
end

function UIManager.drawHuntRecords()
    if not imgui.collapsing_header("Hunt Records", 1) then return end
    
    if not KillTimeTracker.config.HuntRecordsPlayerFilter then
        KillTimeTracker.config.HuntRecordsPlayerFilter = 0
    end
    
    imgui.text("Filter by Players:")
    imgui.same_line()
    
    local buttonWidth = 25
    
    local buttonText = KillTimeTracker.config.HuntRecordsPlayerFilter == 1 and "[1]" or "1"
    if imgui.button(buttonText, buttonWidth) then
        KillTimeTracker.config.HuntRecordsPlayerFilter = KillTimeTracker.config.HuntRecordsPlayerFilter == 1 and 0 or 1
        KillTimeTracker.config.saveConfig()
    end
    
    imgui.same_line()
    buttonText = KillTimeTracker.config.HuntRecordsPlayerFilter == 2 and "[2]" or "2"
    if imgui.button(buttonText, buttonWidth) then
        KillTimeTracker.config.HuntRecordsPlayerFilter = KillTimeTracker.config.HuntRecordsPlayerFilter == 2 and 0 or 2
        KillTimeTracker.config.saveConfig()
    end
    
    imgui.same_line()
    buttonText = KillTimeTracker.config.HuntRecordsPlayerFilter == 3 and "[3]" or "3"
    if imgui.button(buttonText, buttonWidth) then
        KillTimeTracker.config.HuntRecordsPlayerFilter = KillTimeTracker.config.HuntRecordsPlayerFilter == 3 and 0 or 3
        KillTimeTracker.config.saveConfig()
    end
    
    imgui.same_line()
    buttonText = KillTimeTracker.config.HuntRecordsPlayerFilter == 4 and "[4]" or "4"
    if imgui.button(buttonText, buttonWidth) then
        KillTimeTracker.config.HuntRecordsPlayerFilter = KillTimeTracker.config.HuntRecordsPlayerFilter == 4 and 0 or 4
        KillTimeTracker.config.saveConfig()
    end
    
    imgui.same_line()
    buttonText = KillTimeTracker.config.HuntRecordsPlayerFilter == 0 and "[All]" or "All"
    if imgui.button(buttonText, 40) then
        KillTimeTracker.config.HuntRecordsPlayerFilter = 0
        KillTimeTracker.config.saveConfig()
    end
    
    local filterNames = { "All Records", "Solo Only", "2 Players Only", "3 Players Only", "4 Players Only" }
    local currentFilter = filterNames[KillTimeTracker.config.HuntRecordsPlayerFilter + 1] or "All Records"
    imgui.same_line()
    imgui.text(" | Showing: " .. currentFilter)
    
    imgui.separator()
    
    local bossNames = {}
    for bossName, weapons in pairs(KillTimeTracker.data.bestTimes) do
        local playerCount = 1

        local firstWeapon = next(weapons)
        if firstWeapon then
            local record = weapons[firstWeapon]
            if type(record) == "table" and record.playerCount then
                playerCount = record.playerCount
            end
        end
        
        if KillTimeTracker.config.HuntRecordsPlayerFilter == 0 then
            table.insert(bossNames, bossName)
        elseif KillTimeTracker.config.HuntRecordsPlayerFilter == 1 and playerCount == 1 then
            table.insert(bossNames, bossName)
        elseif KillTimeTracker.config.HuntRecordsPlayerFilter == 2 and playerCount == 2 then
            table.insert(bossNames, bossName)
        elseif KillTimeTracker.config.HuntRecordsPlayerFilter == 3 and playerCount == 3 then
            table.insert(bossNames, bossName)
        elseif KillTimeTracker.config.HuntRecordsPlayerFilter == 4 and playerCount == 4 then
            table.insert(bossNames, bossName)
        end
    end
    
    if #bossNames == 0 then
        local filterIndex = KillTimeTracker.config.HuntRecordsPlayerFilter + 1
        local playerFilterText = filterNames[filterIndex] or "Selected Filter"
        
        if KillTimeTracker.config.HuntRecordsPlayerFilter == 0 then
            imgui.text("No hunt records recorded yet.")
        else
            imgui.text("No " .. playerFilterText .. " records found.")
        end
    else
        local sortedBossNames = KillTimeTracker.utils.sortBossNames(bossNames)
        
        for _, bossName in ipairs(sortedBossNames) do
            if imgui.tree_node(bossName) then
                local bestTime = math.huge
                local weaponTable = KillTimeTracker.data.bestTimes[bossName]
                
                for _, record in pairs(weaponTable) do
                    local time = type(record) == "table" and record.time or record
                    if time < bestTime then
                        bestTime = time
                    end
                end
                
                local sortedWeapons = {}
                for weapon, record in pairs(weaponTable) do
                    local time = type(record) == "table" and record.time or record
                    local timestamp = type(record) == "table" and record.timestamp
                    local recordPlayerCount = type(record) == "table" and record.playerCount or 1
                    
                    table.insert(sortedWeapons, {
                        weapon = weapon, 
                        time = time,
                        timestamp = timestamp,
                        playerCount = recordPlayerCount
                    })
                end
                
                table.sort(sortedWeapons, function(a, b) return a.time < b.time end)
                
                for _, data in ipairs(sortedWeapons) do
                    local timeStr = KillTimeTracker.utils.formatTime(data.time)
                    imgui.text(data.weapon .. ": " .. timeStr)
                    
                    if data.timestamp then
                        imgui.same_line()
                        imgui.text("(" .. os.date("%Y-%m-%d", data.timestamp) .. ")")
                    end
                end
                
                imgui.tree_pop()
            end
        end
    end
    
    imgui.spacing()
    if imgui.button("Reload Hunt Records") then
        KillTimeTracker.data.loadKillTimes()
    end
    
    imgui.same_line()
    if imgui.button("Reset Hunt Records") then
        UIManager.showResetHuntRecordsConfirm()
    end
end

function UIManager.drawRecentHunts()
    if not imgui.collapsing_header("Recent Hunts", 1) then return end
    
    if KillTimeTracker.data.recentHunts and #KillTimeTracker.data.recentHunts > 0 then
        for i, hunt in ipairs(KillTimeTracker.data.recentHunts) do
            local timeStr = KillTimeTracker.utils.formatTime(hunt.killTime or 0)
            local recordPrefix = hunt.wasNewRecord and "[NEW RECORD] " or ""
            
            local huntInfo = string.format("%s%s - %s - %s", 
                recordPrefix,
                hunt.bossName or "Unknown Monster", 
                hunt.weaponName or "Unknown Weapon",
                timeStr
            )
            
            imgui.text(huntInfo)
        end
    else
        imgui.text("No recent hunts recorded yet.")
    end

    imgui.spacing()
    
    if imgui.button("Reload Recent Hunts") then
        KillTimeTracker.data.loadRecentHunts()
    end

    imgui.same_line()
    if imgui.button("Reset Recent Hunts") then
        UIManager.showResetRecentHuntsConfirm()
    end
end

function UIManager.drawSettings()
    if not imgui.collapsing_header("Settings", 1) then return end
    
    local changed = false
    
    imgui.separator()
    imgui.text("Quest & Monster Settings")
    
    imgui.text("Quest Rank: " .. KillTimeTracker.utils.getQuestRankText(KillTimeTracker.config.ManualQuestRank))
    changed, KillTimeTracker.config.ManualQuestRank = imgui.slider_int("##QuestRank", KillTimeTracker.config.ManualQuestRank, 1, 8)
    if changed then KillTimeTracker.config.saveConfig() end
    
    imgui.text("Monster Strength:")
    changed, KillTimeTracker.config.ManualMonsterDifficulty = imgui.slider_int("##MonsterDifficulty", KillTimeTracker.config.ManualMonsterDifficulty, 1, 5)
    if changed then KillTimeTracker.config.saveConfig() end
    
    changed, KillTimeTracker.config.ManualTemperedStatus = imgui.checkbox("Tempered Monster", KillTimeTracker.config.ManualTemperedStatus)
    if changed then KillTimeTracker.config.saveConfig() end
    
    local previewName = KillTimeTracker.config.ManualTemperedStatus and "Tempered Monster" or "Monster"
    
    local questRankText = KillTimeTracker.utils.getQuestRankText(KillTimeTracker.config.ManualQuestRank)
    local difficultyText = KillTimeTracker.utils.getMonsterStrengthText(KillTimeTracker.config.ManualMonsterDifficulty)
    local formattedName = string.format("%s (%s %s)", 
        previewName, questRankText, difficultyText)
    
    if imgui.button("Add Manual Record") then
        UIManager.openManualEntryDialog()
    end

    imgui.separator()
    imgui.text("Multiplayer Settings")
    
    imgui.text("Manual Player Count:")
    changed, KillTimeTracker.config.ManualPlayerCount = imgui.slider_int("##ManualPlayerCount", 
        KillTimeTracker.config.ManualPlayerCount, 1, 4)
    if changed then 
        KillTimeTracker.config.saveConfig() 
        KillTimeTracker.utils.sendNotification(string.format("<COLOR 00FF00>Player count set to %d</COLOR>", 
            KillTimeTracker.config.ManualPlayerCount))
    end
    
    imgui.separator()
    imgui.text("Recent Hunts Settings")
    
    changed, KillTimeTracker.config.MaxRecentHunts = imgui.slider_int("Maximum Recent Hunts to Track", KillTimeTracker.config.MaxRecentHunts, 5, 50)
    if changed then
        KillTimeTracker.config.saveConfig()
        
        while #KillTimeTracker.data.recentHunts > KillTimeTracker.config.MaxRecentHunts do
            table.remove(KillTimeTracker.data.recentHunts)
        end
        KillTimeTracker.data.saveRecentHunts()
    end

    imgui.separator()
    
    imgui.text("Notification Settings")
    changed, KillTimeTracker.config.SystemNotifications = imgui.checkbox("Show System Notifications", KillTimeTracker.config.SystemNotifications)
    if changed then KillTimeTracker.config.saveConfig() end
    
    changed, KillTimeTracker.config.ShowNewRecordDetails = imgui.checkbox("Show Comparison for Non-Record Times", KillTimeTracker.config.ShowNewRecordDetails)
    if changed then KillTimeTracker.config.saveConfig() end
    
    imgui.text("Preview: " .. formattedName)
    
    if imgui.button("Test Notification") then
        KillTimeTracker.utils.sendNotification("<COLOR 00FF00>Test Notification</COLOR> " .. formattedName .. " from Kill Time Tracker")
    end
end

function UIManager.drawAbout()
    if not imgui.collapsing_header("About", 1) then return end

    imgui.text("Kill Time Tracker v" .. KillTimeTracker.version .. " by ptrawt")
    imgui.text("A mod for tracking monster hunt times in Monster Hunter Wilds")
    imgui.text("Records best times by monster, rank, strength, and weapon")
    
    imgui.spacing()
    imgui.text("New in v1.1.0: Records filtering and multiplayer logging support")
end

function UIManager.openManualEntryDialog()
    UIManager.manualEntryState.isOpen = true
    UIManager.manualEntryState.selectedBoss = ""
    UIManager.manualEntryState.selectedWeapon = ""
    UIManager.manualEntryState.minutes = 0
    UIManager.manualEntryState.seconds = 0
    UIManager.manualEntryState.milliseconds = 0
    UIManager.manualEntryState.showMonsterList = false
    UIManager.manualEntryState.showWeaponList = false
    UIManager.manualEntryState.questRank = KillTimeTracker.config.ManualQuestRank
    UIManager.manualEntryState.monsterStrength = KillTimeTracker.config.ManualMonsterDifficulty
    UIManager.manualEntryState.isTempered = KillTimeTracker.config.ManualTemperedStatus
    UIManager.manualEntryState.playerCount = KillTimeTracker.config.ManualPlayerCount or 1
end

function UIManager.drawManualEntryDialog()
    if not UIManager.manualEntryState.isOpen then return end
    
    imgui.set_next_window_size(Vector2f.new(400, 450), 4)
    imgui.set_next_window_pos(Vector2f.new(300, 200), 4)
    
    local windowFlags = 49
    
    local visible = imgui.begin_window("Add Manual Kill Time", UIManager.manualEntryState.isOpen, windowFlags)
    
    if visible then
        imgui.text("Add Manual Record")
        
        local currentMonsterIndex = 1
        for i, monsterName in ipairs(KillTimeTracker.records.BossNameList) do
            if monsterName == UIManager.manualEntryState.selectedBoss then
                currentMonsterIndex = i
                break
            end
        end
        
        imgui.separator()

        imgui.text("Monster:")
        local monsterChanged, newMonsterIndex = imgui.combo("##MonsterSelect", currentMonsterIndex, KillTimeTracker.records.BossNameList)
        if monsterChanged then
            UIManager.manualEntryState.selectedBoss = KillTimeTracker.records.BossNameList[newMonsterIndex]
        end
        
        if UIManager.manualEntryState.selectedBoss ~= "" then
            imgui.separator()
            imgui.text("Monster Settings")
            
            imgui.text("Quest Rank: " .. KillTimeTracker.utils.getQuestRankText(UIManager.manualEntryState.questRank))
            local changed, newRank = imgui.slider_int("##ManualQuestRank", UIManager.manualEntryState.questRank, 1, 8)
            if changed then
                UIManager.manualEntryState.questRank = newRank
            end
            
            imgui.text("Monster Strength:")
            changed, newDifficulty = imgui.slider_int("##ManualMonsterDifficulty", UIManager.manualEntryState.monsterStrength, 1, 5)
            if changed then
                UIManager.manualEntryState.monsterStrength = newDifficulty
            end
            
            changed, newTempered = imgui.checkbox("Tempered Monster", UIManager.manualEntryState.isTempered)
            if changed then
                UIManager.manualEntryState.isTempered = newTempered
            end
        end
        
        imgui.separator()
        
        local currentWeaponIndex = 1
        for i, weapon in ipairs(KillTimeTracker.records.weaponList) do
            if weapon == UIManager.manualEntryState.selectedWeapon then
                currentWeaponIndex = i
                break
            end
        end
        
        imgui.text("Weapon:")
        local weaponChanged, newWeaponIndex = imgui.combo("##WeaponSelect", currentWeaponIndex, KillTimeTracker.records.weaponList)
        if weaponChanged then
            UIManager.manualEntryState.selectedWeapon = KillTimeTracker.records.weaponList[newWeaponIndex]
        end
        
        imgui.separator()
        
        imgui.text("Kill Time")
        
        local changed = false
        changed, UIManager.manualEntryState.minutes = imgui.drag_int("Minutes", UIManager.manualEntryState.minutes, 1, 0, 59)
        changed, UIManager.manualEntryState.seconds = imgui.drag_int("Seconds", UIManager.manualEntryState.seconds, 1, 0, 59)
        changed, UIManager.manualEntryState.milliseconds = imgui.drag_int("Milliseconds", UIManager.manualEntryState.milliseconds, 1, 0, 99)
        
        local previewTime = UIManager.manualEntryState.minutes * 60 + UIManager.manualEntryState.seconds + UIManager.manualEntryState.milliseconds / 100
        imgui.text("Preview: " .. KillTimeTracker.utils.formatTime(previewTime))

        imgui.separator()
        imgui.text("Quest Players:")
        local playerCountChanged, newPlayerCount = imgui.slider_int(
            "##ManualPlayerCount", 
            UIManager.manualEntryState.playerCount, 
            1, 4
        )
        if playerCountChanged then
            UIManager.manualEntryState.playerCount = newPlayerCount
        end
        
        imgui.separator()
        
        local canAdd = UIManager.manualEntryState.selectedBoss ~= "" and UIManager.manualEntryState.selectedWeapon ~= ""
        if not canAdd then
            imgui.text("Please select a monster and weapon")
        end
        
        local addButtonLabel = canAdd and "Add Record" or "Add Record (Select monster & weapon first)"
        
        if imgui.button(addButtonLabel) and canAdd then
            local totalSeconds = UIManager.manualEntryState.minutes * 60 + UIManager.manualEntryState.seconds + UIManager.manualEntryState.milliseconds / 100
            
            local formattedName = KillTimeTracker.utils.getFormattedBossName(
                UIManager.manualEntryState.selectedBoss,
                UIManager.manualEntryState.questRank,
                UIManager.manualEntryState.monsterStrength,
                UIManager.manualEntryState.isTempered,
                UIManager.manualEntryState.playerCount
            )
            
            local isNewRecord = KillTimeTracker.records.updateBestTime(
                formattedName, 
                UIManager.manualEntryState.selectedWeapon, 
                totalSeconds, 
                nil, 
                UIManager.manualEntryState.playerCount
            )
            KillTimeTracker.data.saveKillTimes()
            
            local huntRecord = KillTimeTracker.records.addRecentHunt(
                formattedName, 
                UIManager.manualEntryState.selectedWeapon, 
                totalSeconds
            )
            huntRecord.playerCount = UIManager.manualEntryState.playerCount
            huntRecord.wasNewRecord = isNewRecord
            KillTimeTracker.data.saveRecentHunts()
            
            local message = string.format(
                "<COLOR 00FFFF>Manual record added:</COLOR> %s with %s in %s",
                formattedName, UIManager.manualEntryState.selectedWeapon, KillTimeTracker.utils.formatTime(totalSeconds)
            )
            KillTimeTracker.utils.sendNotification(message)
            
            UIManager.manualEntryState.isOpen = false
        end
        
        imgui.same_line()
        
        if imgui.button("Cancel") then
            UIManager.manualEntryState.isOpen = false
        end
    end
    
    imgui.end_window()
    
    if not visible and UIManager.manualEntryState.isOpen then
        UIManager.manualEntryState.isOpen = false
    end
end

function UIManager.showResetHuntRecordsConfirm()
    local showConfirmDialog = false
    
    re.on_draw_ui(function()
        if not showConfirmDialog then return end
        
        imgui.set_next_window_size(Vector2f.new(300, 150), 4)
        imgui.set_next_window_pos(Vector2f.new(400, 300), 4)
        
        local visible = imgui.begin_window("Confirm Reset Hunt Records", true, 64)
        
        if visible then
            imgui.text("Are you sure you want to reset ALL hunt records?")
            imgui.text("This action cannot be undone.")
            
            if imgui.button("Confirm Reset") then
                KillTimeTracker.data.resetHuntRecords()
                showConfirmDialog = false
                imgui.end_window()
                return
            end
            
            imgui.same_line()
            
            if imgui.button("Cancel") or not visible then
                showConfirmDialog = false
            end
            
            imgui.end_window()
        else
            showConfirmDialog = false
        end
    end)
    
    showConfirmDialog = true
end

function UIManager.showResetRecentHuntsConfirm()
    local showConfirmDialog = false
    
    re.on_draw_ui(function()
        if not showConfirmDialog then return end
        
        imgui.set_next_window_size(Vector2f.new(300, 150), 4)
        imgui.set_next_window_pos(Vector2f.new(400, 300), 4)
        
        local visible = imgui.begin_window("Confirm Reset Recent Hunts", true, 64)
        
        if visible then
            imgui.text("Are you sure you want to reset ALL recent hunts?")
            imgui.text("This action cannot be undone.")
            
            if imgui.button("Confirm Reset") then
                KillTimeTracker.data.resetRecentHunts()
                showConfirmDialog = false
                imgui.end_window()
                return
            end
            
            imgui.same_line()
            
            if imgui.button("Cancel") or not visible then
                showConfirmDialog = false
            end
            
            imgui.end_window()
        else
            showConfirmDialog = false
        end
    end)
    
    showConfirmDialog = true
end

return UIManager