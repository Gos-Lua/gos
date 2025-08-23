if _G.__L9_ENGINE_NAMI_LOADED then return end
_G.__L9_ENGINE_NAMI_LOADED = true

local Version = 1.0
local Name = "L9Nami"

local Heroes = {"Nami"}
if not table.contains(Heroes, myHero.charName) then return end

require("DepressivePrediction")
require("DamageLib")
local PredictionLoaded = false

DelayAction(function()
    if _G.DepressivePrediction then
        PredictionLoaded = true
        print("L9Nami: DepressivePrediction loaded!")
    end
end, 1.0)

local function CheckPredictionSystem()
    if not PredictionLoaded or not _G.DepressivePrediction then
        return false
    end
    
    if not _G.DepressivePrediction.GetPrediction then
        return false
    end
    
    return true
end

local SPELL_RANGE = {
    Q = 875,
    W = 725,
    E = 800,
    R = 2750
}

local SPELL_SPEED = {
    Q = 1750,
    W = 1500,
    E = 20,
    R = 850
}

local SPELL_DELAY = {
    Q = 0.95,
    W = 0.25,
    E = 0.25,
    R = 0.25
}

local SPELL_RADIUS = {
    Q = 150,
    W = 100,
    E = 100,
    R = 250
}

local function GetPrediction(target, spell)
    if not target or not target.valid then return nil, 0 end
    
    if CheckPredictionSystem() then
        local spellData = {
            range = SPELL_RANGE[spell],
            speed = SPELL_SPEED[spell],
            delay = SPELL_DELAY[spell],
            radius = SPELL_RADIUS[spell]
        }
        
        local sourcePos2D = {x = myHero.pos.x, z = myHero.pos.z}
        
        local unitPos, castPos, timeToHit = _G.DepressivePrediction.GetPrediction(
            target,
            sourcePos2D,
            spellData.speed,
            spellData.delay,
            spellData.radius
        )
        
        if castPos and castPos.x and castPos.z then
            local hitChance = 4
            return {x = castPos.x, z = castPos.z}, hitChance
        end
    end
    
    return {x = target.pos.x, z = target.pos.z}, 2
end

local function GetLowestHealthAlly()
    local lowestHealth = math.huge
    local lowestAlly = nil
    
    for i = 1, Game.HeroCount() do
        local ally = Game.Hero(i)
        if ally and ally.team == myHero.team and ally.networkID ~= myHero.networkID and not ally.dead then
            local healthPercent = ally.health / ally.maxHealth
            if healthPercent < lowestHealth then
                lowestHealth = healthPercent
                lowestAlly = ally
            end
        end
    end
    
    return lowestAlly, lowestHealth
end

local function GetBestAllyForE()
    local bestAlly = nil
    local bestScore = 0
    
    for i = 1, Game.HeroCount() do
        local ally = Game.Hero(i)
        if ally and ally.team == myHero.team and ally.networkID ~= myHero.networkID and not ally.dead then
            local score = 0
            
            -- Priorité aux ADC et assassins
            if ally.charName == "Jinx" or ally.charName == "Caitlyn" or ally.charName == "Vayne" or 
               ally.charName == "Draven" or ally.charName == "Lucian" or ally.charName == "Ezreal" or
               ally.charName == "Zed" or ally.charName == "Katarina" or ally.charName == "Akali" then
                score = score + 100
            end
            
            -- Bonus si l'allié est en combat
            if ally.health < ally.maxHealth * 0.8 then
                score = score + 50
            end
            
            -- Bonus si l'allié est proche d'ennemis
            for j = 1, Game.HeroCount() do
                local enemy = Game.Hero(j)
                if enemy and enemy.team ~= myHero.team and not enemy.dead then
                    if ally.pos:DistanceTo(enemy.pos) < 600 then
                        score = score + 30
                        break
                    end
                end
            end
            
            if score > bestScore then
                bestScore = score
                bestAlly = ally
            end
        end
    end
    
    return bestAlly
end

class "L9Nami"

function L9Nami:__init()
    self:LoadMenu()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function L9Nami:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Nami", name = "L9Nami"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. Version}})
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "UseQ", name = "[Q] Aqua Prison", value = true})
    self.Menu.Combo:MenuElement({id = "UseW", name = "[W] Ebb and Flow", value = true})
    self.Menu.Combo:MenuElement({id = "UseE", name = "[E] Tidecaller's Blessing", value = true})
    self.Menu.Combo:MenuElement({id = "UseR", name = "[R] Tidal Wave", value = true})
    self.Menu.Combo:MenuElement({id = "QHitChance", name = "Q Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    self.Menu.Combo:MenuElement({id = "RHitChance", name = "R Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "[Q] Aqua Prison", value = true})
    self.Menu.Harass:MenuElement({id = "UseW", name = "[W] Ebb and Flow", value = true})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"})
    self.Menu.Harass:MenuElement({id = "QHitChance", name = "Q Hit Chance", value = 3, min = 1, max = 4, identifier = ""})
    
    self.Menu:MenuElement({type = MENU, id = "Heal", name = "Auto Heal"})
    self.Menu.Heal:MenuElement({id = "UseW", name = "[W] Auto Heal Allies", value = true})
    self.Menu.Heal:MenuElement({id = "HealPercent", name = "Heal Ally Below % HP", value = 60, min = 10, max = 90, identifier = "%"})
    self.Menu.Heal:MenuElement({id = "HealSelf", name = "Heal Self Below % HP", value = 50, min = 10, max = 90, identifier = "%"})
    self.Menu.Heal:MenuElement({id = "Mana", name = "Min Mana to Heal", value = 30, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "Buff", name = "Auto Buff"})
    self.Menu.Buff:MenuElement({id = "UseE", name = "[E] Auto Buff Allies", value = true})
    self.Menu.Buff:MenuElement({id = "BuffPriority", name = "Buff Priority", drop = {"Lowest HP", "ADC/Assassin", "Closest to Enemy"}})
    self.Menu.Buff:MenuElement({id = "BuffRange", name = "Buff Range Check", value = 800, min = 400, max = 1200, identifier = ""})
    self.Menu.Buff:MenuElement({id = "Mana", name = "Min Mana to Buff", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
    self.Menu.Clear:MenuElement({id = "UseQ", name = "[Q] Aqua Prison", value = false})
    self.Menu.Clear:MenuElement({id = "UseW", name = "[W] Ebb and Flow", value = false})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
    self.Menu.ks:MenuElement({id = "UseQ", name = "[Q] Aqua Prison", value = true})
    self.Menu.ks:MenuElement({id = "UseW", name = "[W] Ebb and Flow", value = true})
    self.Menu.ks:MenuElement({id = "UseR", name = "[R] Tidal Wave", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
    self.Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawHeal", name = "Draw Heal Status", value = true})
end

function L9Nami:Tick()
    if myHero.dead or Game.IsChatOpen() then return end
    
    if not CheckPredictionSystem() then return end
    
    local Mode = _G.L9Engine:GetCurrentMode()
    
    -- Auto Heal/Buff prioritaire
    self:AutoHeal()
    self:AutoBuff()
    
    if Mode == "Combo" then
        self:Combo()
    elseif Mode == "Harass" then
        self:Harass()
    elseif Mode == "Clear" then
        self:LaneClear()
    end
    
    self:KillSteal()
end

function L9Nami:AutoHeal()
    if not self.Menu.Heal.UseW:Value() or not _G.L9Engine:IsSpellReady(_W) then return end
    if myHero.mana/myHero.maxMana < self.Menu.Heal.Mana:Value() / 100 then return end
    
    local lowestAlly, lowestHealth = GetLowestHealthAlly()
    local myHealthPercent = myHero.health / myHero.maxHealth
    
    -- Heal l'allié le plus bas en HP
    if lowestAlly and lowestHealth < self.Menu.Heal.HealPercent:Value() / 100 then
        if myHero.pos:DistanceTo(lowestAlly.pos) <= SPELL_RANGE.W then
            Control.CastSpell(_G.L9Engine:GetKeybind("W"), lowestAlly.pos)
            return
        end
    end
    
    -- Heal soi-même si nécessaire
    if myHealthPercent < self.Menu.Heal.HealSelf:Value() / 100 then
        Control.CastSpell(_G.L9Engine:GetKeybind("W"), myHero.pos)
    end
end

function L9Nami:AutoBuff()
    if not self.Menu.Buff.UseE:Value() or not _G.L9Engine:IsSpellReady(_E) then return end
    if myHero.mana/myHero.maxMana < self.Menu.Buff.Mana:Value() / 100 then return end
    
    local targetAlly = nil
    
    if self.Menu.Buff.BuffPriority:Value() == 1 then -- Lowest HP
        local lowestAlly, lowestHealth = GetLowestHealthAlly()
        if lowestAlly and lowestHealth < 0.8 and myHero.pos:DistanceTo(lowestAlly.pos) <= self.Menu.Buff.BuffRange:Value() then
            targetAlly = lowestAlly
        end
    elseif self.Menu.Buff.BuffPriority:Value() == 2 then -- ADC/Assassin
        targetAlly = GetBestAllyForE()
        if targetAlly and myHero.pos:DistanceTo(targetAlly.pos) > self.Menu.Buff.BuffRange:Value() then
            targetAlly = nil
        end
    else -- Closest to Enemy
        local bestAlly = nil
        local closestDistance = math.huge
        
        for i = 1, Game.HeroCount() do
            local ally = Game.Hero(i)
            if ally and ally.team == myHero.team and ally.networkID ~= myHero.networkID and not ally.dead then
                if myHero.pos:DistanceTo(ally.pos) <= self.Menu.Buff.BuffRange:Value() then
                    for j = 1, Game.HeroCount() do
                        local enemy = Game.Hero(j)
                        if enemy and enemy.team ~= myHero.team and not enemy.dead then
                            local distance = ally.pos:DistanceTo(enemy.pos)
                            if distance < closestDistance then
                                closestDistance = distance
                                bestAlly = ally
                            end
                        end
                    end
                end
            end
        end
        targetAlly = bestAlly
    end
    
    if targetAlly then
        Control.CastSpell(_G.L9Engine:GetKeybind("E"), targetAlly.pos)
    end
end

function L9Nami:Combo()
    local target = _G.L9Engine:GetBestTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        if myHero.pos:DistanceTo(target.pos) <= SPELL_RANGE.R and self.Menu.Combo.UseR:Value() and _G.L9Engine:IsSpellReady(_R) then
            local prediction, hitChance = GetPrediction(target, "R")
            if prediction and hitChance >= self.Menu.Combo.RHitChance:Value() then
                Control.CastSpell(_G.L9Engine:GetKeybind("R"), Vector(prediction.x, myHero.pos.y, prediction.z))
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= SPELL_RANGE.Q and self.Menu.Combo.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
            local prediction, hitChance = GetPrediction(target, "Q")
            if prediction and hitChance >= self.Menu.Combo.QHitChance:Value() then
                Control.CastSpell(_G.L9Engine:GetKeybind("Q"), Vector(prediction.x, myHero.pos.y, prediction.z))
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= SPELL_RANGE.W and self.Menu.Combo.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
            Control.CastSpell(_G.L9Engine:GetKeybind("W"), target.pos)
        end
        
        if myHero.pos:DistanceTo(target.pos) <= SPELL_RANGE.E and self.Menu.Combo.UseE:Value() and _G.L9Engine:IsSpellReady(_E) then
            Control.CastSpell(_G.L9Engine:GetKeybind("E"), myHero.pos)
        end
    end
end

function L9Nami:Harass()
    local target = _G.L9Engine:GetBestTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
        
        if myHero.pos:DistanceTo(target.pos) <= SPELL_RANGE.Q and self.Menu.Harass.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
            local prediction, hitChance = GetPrediction(target, "Q")
            if prediction and hitChance >= self.Menu.Harass.QHitChance:Value() then
                Control.CastSpell(_G.L9Engine:GetKeybind("Q"), Vector(prediction.x, myHero.pos.y, prediction.z))
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= SPELL_RANGE.W and self.Menu.Harass.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
            Control.CastSpell(_G.L9Engine:GetKeybind("W"), target.pos)
        end
    end
end

function L9Nami:LaneClear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        
        if myHero.pos:DistanceTo(minion.pos) <= SPELL_RANGE.W and minion.team == TEAM_ENEMY and _G.L9Engine:IsValidEnemy(minion) and myHero.mana/myHero.maxMana >= self.Menu.Clear.Mana:Value() / 100 then
            
            if myHero.pos:DistanceTo(minion.pos) <= SPELL_RANGE.W and _G.L9Engine:IsSpellReady(_W) and self.Menu.Clear.UseW:Value() then
                Control.CastSpell(_G.L9Engine:GetKeybind("W"), minion.pos)
                break
            end
            
            if myHero.pos:DistanceTo(minion.pos) <= SPELL_RANGE.Q and _G.L9Engine:IsSpellReady(_Q) and self.Menu.Clear.UseQ:Value() then
                local prediction, hitChance = GetPrediction(minion, "Q")
                if prediction and hitChance >= 2 then
                    Control.CastSpell(_G.L9Engine:GetKeybind("Q"), Vector(prediction.x, myHero.pos.y, prediction.z))
                    break
                end
            end
        end
    end
end

function L9Nami:KillSteal()
    local target = _G.L9Engine:GetBestTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        if self.Menu.ks.UseR:Value() and _G.L9Engine:IsSpellReady(_R) and myHero.pos:DistanceTo(target.pos) <= SPELL_RANGE.R then
            local RDmg = getdmg("R", target, myHero) or 0
            if target.health <= RDmg then
                local prediction, hitChance = GetPrediction(target, "R")
                if prediction and hitChance >= 2 then
                    Control.CastSpell(_G.L9Engine:GetKeybind("R"), Vector(prediction.x, myHero.pos.y, prediction.z))
                end
            end
        end
        
        if self.Menu.ks.UseW:Value() and _G.L9Engine:IsSpellReady(_W) and myHero.pos:DistanceTo(target.pos) <= SPELL_RANGE.W then
            local WDmg = getdmg("W", target, myHero) or 0
            if target.health <= WDmg then
                Control.CastSpell(_G.L9Engine:GetKeybind("W"), target.pos)
            end
        end
        
        if self.Menu.ks.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= SPELL_RANGE.Q then
            local QDmg = getdmg("Q", target, myHero) or 0
            if target.health <= QDmg then
                local prediction, hitChance = GetPrediction(target, "Q")
                if prediction and hitChance >= 2 then
                    Control.CastSpell(_G.L9Engine:GetKeybind("Q"), Vector(prediction.x, myHero.pos.y, prediction.z))
                end
            end
        end
    end
end

function L9Nami:Draw()
    if myHero.dead then return end
    
    if not CheckPredictionSystem() then return end
    
    if self.Menu.Drawing.DrawQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
        Draw.Circle(myHero.pos, SPELL_RANGE.Q, 1, Draw.Color(255, 255, 0, 0))
    end
    
    if self.Menu.Drawing.DrawW:Value() and _G.L9Engine:IsSpellReady(_W) then
        Draw.Circle(myHero.pos, SPELL_RANGE.W, 1, Draw.Color(255, 0, 255, 0))
    end
    
    if self.Menu.Drawing.DrawE:Value() and _G.L9Engine:IsSpellReady(_E) then
        Draw.Circle(myHero.pos, SPELL_RANGE.E, 1, Draw.Color(255, 0, 0, 255))
    end
    
    if self.Menu.Drawing.DrawR:Value() and _G.L9Engine:IsSpellReady(_R) then
        Draw.Circle(myHero.pos, SPELL_RANGE.R, 1, Draw.Color(255, 255, 255, 0))
    end
    
    if self.Menu.Drawing.DrawHeal:Value() then
        local yOffset = 0
        for i = 1, Game.HeroCount() do
            local ally = Game.Hero(i)
            if ally and ally.team == myHero.team and ally.networkID ~= myHero.networkID and not ally.dead then
                local healthPercent = ally.health / ally.maxHealth
                local color = Draw.Color(255, 255, 255, 255)
                
                if healthPercent < 0.3 then
                    color = Draw.Color(255, 255, 0, 0) -- Rouge
                elseif healthPercent < 0.6 then
                    color = Draw.Color(255, 255, 255, 0) -- Jaune
                end
                
                local textPos = Renderer.WorldToScreen(ally.pos)
                if textPos then
                    Draw.Text(ally.charName .. ": " .. math.floor(healthPercent * 100) .. "%", 15, textPos.x - 40, textPos.y + yOffset, color)
                    yOffset = yOffset + 20
                end
            end
        end
    end
end

L9Nami()
