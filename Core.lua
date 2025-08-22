if _G.L9EngineLoaded then return end
_G.L9EngineLoaded = true

class "L9Engine"

local GITHUB_RAW_URL = "https://raw.githubusercontent.com/Gos-Lua/gos/main/"
local SUPPORTED_CHAMPIONS = {
    "Sylas", "Pyke", "Aurora", "Draven", "XinZhao", "MasterYi", "Thresh"
}

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
    if not championName or not self:IsChampionSupported(championName) then
        self:LogDebug("Champion non supporté: " .. tostring(championName))
        return
    end
    
    local fileName = championName .. ".lua"
    local localPath = COMMON_PATH .. "L9Engine/Champions/" .. fileName
    local remoteUrl = GITHUB_RAW_URL .. fileName
    
    if not FileExist(localPath) or self.Menu.config.forceUpdate:Value() then
        self:DownloadFile(remoteUrl, localPath, championName)
    else
        self:LogDebug("Fichier local trouvé pour " .. championName)
    end
end

function L9Engine:DownloadFile(url, localPath, championName)
    if self.Menu.debug.showDownloads:Value() then
        print("[L9Engine] Téléchargement de " .. championName .. " depuis GitHub...")
    end
    
    self:LogDebug("URL de téléchargement: " .. url)
    self:LogDebug("Chemin local: " .. localPath)
    
    self:LoadChampionFile(localPath, championName)
end

function L9Engine:ForceUpdateChampion(championName)
    self:LogDebug("Mise à jour forcée pour " .. championName)
    self:QueueChampionDownload(championName)
end

function L9Engine:IsChampionSupported(championName)
    for _, supported in ipairs(SUPPORTED_CHAMPIONS) do
        if supported == championName then
            return true
        end
    end
    return false
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
    local filePath = COMMON_PATH .. "L9Engine/Champions/" .. championName .. ".lua"
    
    if self:IsChampionSupported(championName) then
        self:LoadChampionFile(filePath, championName)
    else
        self:LogDebug("Champion non supporté: " .. championName)
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

local championLoader
championLoader = function()
    if _G.L9EngineChampionLoaded then
        return
    end
    
    local championName = myHero.charName
    local filePath = COMMON_PATH .. "L9Engine/Champions/" .. championName .. ".lua"
    
    if FileExist(filePath) then
        local success, error = pcall(dofile, filePath)
        if success then
            _G.L9EngineChampionLoaded = true
            print("[L9Engine] Champion chargé: " .. championName)
        end
    end
end

if Callback then
    Callback.Add("Tick", championLoader)
else
    DelayAction(championLoader, 1)
end

print("[L9Engine] Engine original initialisé avec système de téléchargement")
print("[L9Engine] Champions supportés: " .. table.concat(SUPPORTED_CHAMPIONS, ", "))
