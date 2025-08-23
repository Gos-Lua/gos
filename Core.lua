if _G.L9EngineLoaded then return end
_G.L9EngineLoaded = true

class "L9Engine"

local GITHUB_RAW_URL = "https://raw.githubusercontent.com/Gos-Lua/gos/main/"
local VERSION_URL = GITHUB_RAW_URL .. "Common/L9Engine/currentVersion.lua"
local LOCAL_PATH = COMMON_PATH .. "L9Engine/"
local LOCAL_VERSIONFILE = LOCAL_PATH .. "currentVersion.lua"

function L9Engine:__init()
    self.DownloadQueue = {}
    self.DownloadedFiles = {}
    self:InitializeEngine()
end

function L9Engine:InitializeEngine()
    self:CreateMainMenu()
    self:SetupKeybindSystem()
    self:SetupDownloadSystem()
    self:LoadChampionModule()
    self:StartAutoUpdateSystem()
end

function L9Engine:CreateMainMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Engine", name = "L9Engine"})
    self.Menu:MenuElement({name = " ", drop = {"Engine L9 - Version Originale"}})
    
    self.Menu:MenuElement({type = MENU, id = "config", name = "Configuration"})
    self.Menu.config:MenuElement({id = "autoUpdate", name = "Mise à jour automatique", value = true})
    self.Menu.config:MenuElement({id = "forceUpdate", name = "Forcer mise à jour", value = false})
    
    self.Menu:MenuElement({type = MENU, id = "layout", name = "Configuration Clavier"})
    self.Menu.layout:MenuElement({id = "type", name = "Type de clavier", value = 1, drop = {"QWERTY", "AZERTY"}})
    self.Menu.layout:MenuElement({id = "customQ", name = "Touche Q", value = 1, drop = {"Q", "A"}})
    self.Menu.layout:MenuElement({id = "customW", name = "Touche W", value = 1, drop = {"W", "Z"}})
    self.Menu.layout:MenuElement({id = "customE", name = "Touche E", value = 1, drop = {"E", "E"}})
    self.Menu.layout:MenuElement({id = "customR", name = "Touche R", value = 1, drop = {"R", "R"}})
    
    self.Menu:MenuElement({type = MENU, id = "debug", name = "Debug"})
    self.Menu.debug:MenuElement({id = "enabled", name = "Activer Debug", value = false})
    self.Menu.debug:MenuElement({id = "showDownloads", name = "Afficher téléchargements", value = true})
end

function L9Engine:StartAutoUpdateSystem()
    if self.Menu.config.autoUpdate:Value() then
        self:LogDebug("Système de mise à jour automatique activé")
        self:CheckAndUpdateChampions()
    end
end

function L9Engine:CheckAndUpdateChampions()
    self:LoadLocalVersions()
    self:LoadRemoteVersions()
end

function L9Engine:LoadLocalVersions()
    if FileExist(LOCAL_VERSIONFILE) then
        local ok, err = pcall(dofile, LOCAL_VERSIONFILE)
        if ok and type(Data) == "table" then
            self.LocalData = Data
            Data = nil
        else
            self.LocalData = { Core = {Version = 0}, Champions = {} }
        end
    else
        self.LocalData = { Core = {Version = 0}, Champions = {} }
    end
end

function L9Engine:LoadRemoteVersions()
    self:DownloadFile(VERSION_URL, LOCAL_VERSIONFILE, function()
        if FileExist(LOCAL_VERSIONFILE) then
            local ok, err = pcall(dofile, LOCAL_VERSIONFILE)
            if ok and type(Data) == "table" then
                self.RemoteData = Data
                Data = nil
                self:UpdateChampions()
            end
        end
    end)
end

function L9Engine:UpdateChampions()
    if not self.RemoteData or not self.RemoteData.Champions then return end
    
    self.PendingDownloads = self.PendingDownloads or {count = 0}
    
    for champ, info in pairs(self.RemoteData.Champions) do
        local localEntry = self.LocalData.Champions[champ]
        local needs = (not localEntry) or (info.Version or 0) > (localEntry.Version or 0)
        
        -- Force download if local champion script file is missing
        local fileName = string.format("Champions/%s.lua", champ)
        local champPath = LOCAL_PATH .. fileName
        if not FileExist(champPath) then
            needs = true
        end
        
        if needs then
            if self.Menu.debug.showDownloads:Value() then
                print(string.format("[L9Engine] Téléchargement de %s (v%0.2f)", champ, info.Version or 0))
            end
            self.PendingDownloads.count = self.PendingDownloads.count + 1
            self:DownloadFile(GITHUB_RAW_URL .. "Common/L9Engine/" .. fileName, champPath, function()
                self.PendingDownloads.count = math.max(0, self.PendingDownloads.count - 1)
            end)
        end
    end
    
    -- Poll until downloads finish
    local startTime = os.clock()
    local updaterTick
    updaterTick = function()
        if (not self.PendingDownloads) or (self.PendingDownloads.count == 0) or (os.clock() - startTime > 10) then
            if not self.UpdatePrinted then
                self:LogDebug("Mise à jour terminée")
                self.UpdatePrinted = true
            end
            self.Updated = true
            Callback.Del("Tick", updaterTick)
        end
    end
    Callback.Add("Tick", updaterTick)
end

function L9Engine:DownloadFile(url, path, callback)
    DownloadFileAsync(url, path, function()
        if callback then callback() end
    end)
end

function L9Engine:SetupKeybindSystem()
    self:UpdateKeybindMap()
end

function L9Engine:UpdateKeybindMap()
    local isAZERTY = self.Menu.layout.type:Value() == 2
    
    self.KeybindMap = {
        Q = isAZERTY and self.Menu.layout.customQ:Value() == 2 and HK_A or HK_Q,
        W = isAZERTY and self.Menu.layout.customW:Value() == 2 and HK_Z or HK_W,
        E = HK_E,
        R = HK_R
    }
    
    self:LogDebug("Keybind map updated: " .. (isAZERTY and "AZERTY" or "QWERTY"))
end

function L9Engine:SetupDownloadSystem()
    if self.Menu.config.autoUpdate:Value() then
        self:QueueChampionDownload(myHero.charName)
    end
end

function L9Engine:QueueChampionDownload(championName)
    if not championName then
        self:LogDebug("Champion non supporté: " .. tostring(championName))
        return
    end
    
    local fileName = championName .. ".lua"
    local localPath = LOCAL_PATH .. "Champions/" .. fileName
    local remoteUrl = GITHUB_RAW_URL .. "Common/L9Engine/Champions/" .. fileName
    
    if not FileExist(localPath) or self.Menu.config.forceUpdate:Value() then
        self:DownloadFile(remoteUrl, localPath, championName)
    else
        self:LogDebug("Fichier local trouvé pour " .. championName)
    end
end

function L9Engine:ForceUpdateChampion(championName)
    self:LogDebug("Mise à jour forcée pour " .. championName)
    self:QueueChampionDownload(championName)
end

function L9Engine:IsChampionSupported(championName)
    -- Vérifie si le champion existe dans les données distantes
    if self.RemoteData and self.RemoteData.Champions and self.RemoteData.Champions[championName] then
        return true
    end
    -- Vérifie si le fichier local existe
    local filePath = LOCAL_PATH .. "Champions/" .. championName .. ".lua"
    return FileExist(filePath)
end

function L9Engine:LoadChampionFile(filePath, championName)
    if FileExist(filePath) then
        local success, error = pcall(dofile, filePath)
        if success then
            self:LogDebug("Module chargé avec succès: " .. championName)
            self.DownloadedFiles[championName] = true
        else
            self:LogDebug("Erreur lors du chargement de " .. championName .. ": " .. tostring(error))
        end
    else
        self:LogDebug("Fichier non trouvé: " .. filePath)
    end
end

function L9Engine:LoadChampionModule()
    local championName = myHero.charName
    local filePath = LOCAL_PATH .. "Champions/" .. championName .. ".lua"
    
    if FileExist(filePath) then
        self:LoadChampionFile(filePath, championName)
    else
        self:LogDebug("Champion non trouvé: " .. championName)
    end
end

function L9Engine:GetKeybind(spell)
    return self.KeybindMap[spell] or HK_Q
end

function L9Engine:GetLayoutType()
    return self.Menu.layout.type:Value() == 2 and "AZERTY" or "QWERTY"
end

function L9Engine:IsAZERTYLayout()
    return self.Menu.layout.type:Value() == 2
end

function L9Engine:LogDebug(message)
    if self.Menu.debug.enabled:Value() then
        print("[L9Engine] " .. message)
    end
end

function L9Engine:CalculateDistance(pos1, pos2)
    if not pos1 or not pos2 then return math.huge end
    local dx = pos1.x - pos2.x
    local dz = pos1.z - pos2.z
    return math.sqrt(dx * dx + dz * dz)
end

function L9Engine:IsSpellReady(spellSlot)
    if not spellSlot then return false end
    local spellData = myHero:GetSpellData(spellSlot)
    if not spellData then return false end
    return spellData.currentCd == 0 and Game.CanUseSpell(spellSlot) == 0
end

function L9Engine:Ready(spellSlot)
    return self:IsSpellReady(spellSlot)
end

function L9Engine:IsValidEnemy(target, range)
    if not target then return false end
    if target.dead or not target.visible or not target.isTargetable then return false end
    if target.team == myHero.team then return false end
    if range and self:CalculateDistance(myHero.pos, target.pos) > range then return false end
    return true
end

function L9Engine:GetBestTarget(range)
    if _G.SDK then
        return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_PHYSICAL)
    elseif _G.EOWLoaded then
        return EOW:GetTarget(range)
    elseif _G.GOS then
        return GOS:GetTarget(range)
    end
    return nil
end

function L9Engine:GetTarget(range)
    return self:GetBestTarget(range)
end

function L9Engine:IsValidTarget(target, range)
    return self:IsValidEnemy(target, range)
end

function L9Engine:GetMode()
    return self:GetCurrentMode()
end

function L9Engine:GetCurrentMode()
    if _G.SDK then
        if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
            return "Combo"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] then
            return "Harass"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] then
            return "Clear"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] then
            return "LastHit"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
            return "Flee"
        end
    elseif _G.EOWLoaded then
        return EOW.CurrentMode
    elseif _G.GOS then
        return GOS.GetMode()
    end
    return ""
end

function L9Engine:GetUnitBuff(unit, buffName)
    if not unit or not unit.buffCount then return nil end
    for i = 0, unit.buffCount - 1 do
        local buff = unit:GetBuff(i)
        if buff and buff.name == buffName then
            return buff
        end
    end
    return nil
end

function L9Engine:CountEnemyMinions(range)
    local count = 0
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.team == TEAM_ENEMY and self:IsValidEnemy(minion, range) then
            count = count + 1
        end
    end
    return count
end

L9Engine()

local championLoaderStartTime = os.clock()
local championLoader
championLoader = function()
    if _G.L9EngineChampionLoaded then
        Callback.Del("Tick", championLoader)
        return
    end
    
    local championName = myHero.charName
    local filePath = LOCAL_PATH .. "Champions/" .. championName .. ".lua"
    
    if FileExist(filePath) then
        local success, error = pcall(dofile, filePath)
        if success then
            _G.L9EngineChampionLoaded = true
            print("[L9Engine] Champion chargé: " .. championName)
        end
        Callback.Del("Tick", championLoader)
    end
    
    -- Timeout après 60 secondes
    if os.clock() - championLoaderStartTime > 60 then
        if not _G.L9EngineChampionTimeoutPrinted then
            print("[L9Engine] Timeout de chargement du champion: " .. championName)
            _G.L9EngineChampionTimeoutPrinted = true
        end
        Callback.Del("Tick", championLoader)
    end
end

-- Initial attempt after short delay
DelayAction(function() championLoader() end, 0.5)

-- Retry loader until champion loads
Callback.Add("Tick", championLoader)

print("[L9Engine] Engine original initialisé avec système de téléchargement automatique")
print("[L9Engine] Système de mise à jour automatique activé - Téléchargement depuis GitHub")
