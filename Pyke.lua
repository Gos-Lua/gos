-- L9Engine compatibility guard
if _G.__L9_ENGINE_PYKE_LOADED then return end
_G.__L9_ENGINE_PYKE_LOADED = true

local Version = 1.0
local Name = "L9Pyke"

-- Hero validation
local Heroes = {"Pyke"}
if not table.contains(Heroes, myHero.charName) then return end

-- Load prediction system
require("DepressivePrediction")
local PredictionLoaded = false
DelayAction(function()
    if _G.DepressivePrediction then
        PredictionLoaded = true
        print("L9Pyke: DepressivePrediction loaded!")
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
    Q = 1100,
    W = 0,
    E = 550,
    R = 750
}

local SPELL_SPEED = {
    Q = 1900,
    E = 2000,
    R = 2000
}

local SPELL_DELAY = {
    Q = 0.25,
    E = 0.25,
    R = 0.25
}

local SPELL_RADIUS = {
    Q = 100,
    E = 100,
    R = 100
}

local QCharging = false
local QStartTime = 0

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

local function GetUltDamage()
    local level = myHero:GetSpellData(_R).level
    local baseDamage = 250 + (level - 1) * 200
    local bonusAD = myHero.bonusDamage
    return baseDamage + (bonusAD * 0.8)
end

class "L9Pyke"

function L9Pyke:__init()
    self:LoadMenu()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function L9Pyke:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Pyke", name = "L9Pyke"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. Version}})
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "UseQ", name = "[Q] Bone Skewer", value = true})
    self.Menu.Combo:MenuElement({id = "UseE", name = "[E] Phantom Undertow", value = true})
    self.Menu.Combo:MenuElement({id = "UseR", name = "[R] Death From Below", value = true})
    self.Menu.Combo:MenuElement({id = "RCount", name = "Min enemies for R", value = 1, min = 1, max = 5})
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "[Q] Bone Skewer", value = true})
    self.Menu.Harass:MenuElement({id = "UseE", name = "[E] Phantom Undertow", value = false})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
    self.Menu.Clear:MenuElement({id = "UseQ", name = "[Q] Bone Skewer", value = true})
    self.Menu.Clear:MenuElement({id = "UseE", name = "[E] Phantom Undertow", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "JClear", name = "JungleClear"})
    self.Menu.JClear:MenuElement({id = "UseQ", name = "[Q] Bone Skewer", value = true})
    self.Menu.JClear:MenuElement({id = "UseE", name = "[E] Phantom Undertow", value = true})
    self.Menu.JClear:MenuElement({id = "Mana", name = "Min Mana to JungleClear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
    self.Menu.ks:MenuElement({id = "UseQ", name = "[Q] Bone Skewer", value = true})
    self.Menu.ks:MenuElement({id = "UseE", name = "[E] Phantom Undertow", value = true})
    self.Menu.ks:MenuElement({id = "UseR", name = "[R] Death From Below", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
    self.Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "Kill", name = "Draw Killable Targets", value = true})
end

function L9Pyke:Tick()
    if myHero.dead or Game.IsChatOpen() then return end
    
    if not CheckPredictionSystem() then return end
    
    local Mode = _G.L9Engine:GetCurrentMode()
    
    if Mode == "Combo" then
        self:Combo()
    elseif Mode == "Harass" then
        self:Harass()
    elseif Mode == "Clear" then
        self:LaneClear()
        self:JungleClear()
    end
    
    self:KillSteal()
end

function L9Pyke:Combo()
    local target = _G.L9Engine:GetBestTarget(1200)
    if not target then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        if self.Menu.Combo.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= 1100 then
            if myHero.activeSpell.valid and myHero.activeSpell.name == "PykeQ" then
                local chargeTime = Game.Timer() - QStartTime
                if chargeTime > 3 then 
                    Control.KeyUp(HK_Q)
                    QCharging = false
                    return 
                end
                
                local range = math.max(math.min(chargeTime, 1.25) * 880, 400)
                local prediction = GetPrediction(target, "Q")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                    if range > 400 and myHero.pos:DistanceTo(target.pos) <= range then
                        Control.KeyUp(HK_Q)
                        QCharging = false
                        return
                    end
                end
            else
                if not QCharging then
                    Control.KeyDown(HK_Q)
                    QCharging = true
                    QStartTime = Game.Timer()
                end
            end
        else
            if QCharging then
                Control.KeyUp(HK_Q)
                QCharging = false
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 550 and self.Menu.Combo.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and not QCharging then
            local prediction = GetPrediction(target, "E")
            if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
            else
                Control.CastSpell(HK_E, target.pos)
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 750 and self.Menu.Combo.UseR:Value() and _G.L9Engine:IsSpellReady(_R) then
            local enemies = {}
            for i = 1, Game.HeroCount() do
                local hero = Game.Hero(i)
                if _G.L9Engine:IsValidEnemy(hero, SPELL_RANGE.R) then
                    table.insert(enemies, hero)
                end
            end
            
            local killableCount = 0
            for _, enemy in pairs(enemies) do
                local ultDamage = GetUltDamage()
                if ultDamage >= enemy.health then
                    killableCount = killableCount + 1
                end
            end
            
            if killableCount >= self.Menu.Combo.RCount:Value() then
                local prediction = GetPrediction(target, "R")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                    Control.CastSpell(HK_R, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                else
                    Control.CastSpell(HK_R, target.pos)
                end
            end
        end
    end
end

function L9Pyke:Harass()
    if myHero.mana/myHero.maxMana * 100 < self.Menu.Harass.Mana:Value() then return end
    
    local target = _G.L9Engine:GetBestTarget(1200)
    if not target then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        if self.Menu.Harass.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= 1100 then
            if myHero.activeSpell.valid and myHero.activeSpell.name == "PykeQ" then
                local chargeTime = Game.Timer() - QStartTime
                if chargeTime > 3 then 
                    Control.KeyUp(HK_Q)
                    QCharging = false
                    return 
                end
                
                local range = math.max(math.min(chargeTime, 1.25) * 880, 400)
                local prediction = GetPrediction(target, "Q")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                    if range > 400 and myHero.pos:DistanceTo(target.pos) <= range then
                        Control.KeyUp(HK_Q)
                        QCharging = false
                        return
                    end
                end
            else
                if not QCharging then
                    Control.KeyDown(HK_Q)
                    QCharging = true
                    QStartTime = Game.Timer()
                end
            end
        else
            if QCharging then
                Control.KeyUp(HK_Q)
                QCharging = false
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 550 and self.Menu.Harass.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and not QCharging then
            local prediction = GetPrediction(target, "E")
            if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
            else
                Control.CastSpell(HK_E, target.pos)
            end
        end
    end
end

function L9Pyke:LaneClear()
    if myHero.mana/myHero.maxMana * 100 < self.Menu.Clear.Mana:Value() then return end
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion.team == TEAM_ENEMY and _G.L9Engine:IsValidEnemy(minion) and myHero.pos:DistanceTo(minion.pos) <= 1100 then
            
            if self.Menu.Clear.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
                if myHero.activeSpell.valid and myHero.activeSpell.name == "PykeQ" then
                    local chargeTime = Game.Timer() - QStartTime
                    if chargeTime > 3 then 
                        Control.KeyUp(HK_Q)
                        QCharging = false
                        return 
                    end
                    
                    local range = math.max(math.min(chargeTime, 1.25) * 880, 400)
                    if myHero.pos:DistanceTo(minion.pos) <= range then
                        Control.KeyUp(HK_Q)
                        QCharging = false
                        return
                    end
                else
                    if not QCharging then
                        Control.KeyDown(HK_Q)
                        QCharging = true
                        QStartTime = Game.Timer()
                    end
                end
            end
            
            if self.Menu.Clear.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and not QCharging then
                local prediction = GetPrediction(minion, "E")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                    Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                    break
                end
            end
        end
    end
end

function L9Pyke:JungleClear()
    if myHero.mana/myHero.maxMana * 100 < self.Menu.JClear.Mana:Value() then return end
    
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion.team == TEAM_JUNGLE and _G.L9Engine:IsValidEnemy(minion) and myHero.pos:DistanceTo(minion.pos) <= 1100 then
            
            if self.Menu.JClear.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
                if myHero.activeSpell.valid and myHero.activeSpell.name == "PykeQ" then
                    local chargeTime = Game.Timer() - QStartTime
                    if chargeTime > 3 then 
                        Control.KeyUp(HK_Q)
                        QCharging = false
                        return 
                    end
                    
                    local range = math.max(math.min(chargeTime, 1.25) * 880, 400)
                    if myHero.pos:DistanceTo(minion.pos) <= range then
                        Control.KeyUp(HK_Q)
                        QCharging = false
                        return
                    end
                else
                    if not QCharging then
                        Control.KeyDown(HK_Q)
                        QCharging = true
                        QStartTime = Game.Timer()
                    end
                end
            end
            
            if self.Menu.JClear.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and not QCharging then
                local prediction = GetPrediction(minion, "E")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                    Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                    break
                end
            end
        end
    end
end

function L9Pyke:KillSteal()
    local target = _G.L9Engine:GetBestTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        if self.Menu.ks.UseR:Value() and _G.L9Engine:IsSpellReady(_R) and myHero.pos:DistanceTo(target.pos) <= 750 then
            local ultDamage = GetUltDamage()
            if target.health <= ultDamage then
                local prediction = GetPrediction(target, "R")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                    Control.CastSpell(HK_R, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                end
            end
        end
        
        if self.Menu.ks.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= 1100 then
            local QDmg = getdmg("Q", target, myHero) or 0
            if target.health <= QDmg then
                if myHero.activeSpell.valid and myHero.activeSpell.name == "PykeQ" then
                    local chargeTime = Game.Timer() - QStartTime
                    if chargeTime > 3 then 
                        Control.KeyUp(HK_Q)
                        QCharging = false
                        return 
                    end
                    
                    local range = math.max(math.min(chargeTime, 1.25) * 880, 400)
                    local prediction = GetPrediction(target, "Q")
                    if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                        if range > 400 and myHero.pos:DistanceTo(target.pos) <= range then
                            Control.KeyUp(HK_Q)
                            QCharging = false
                            return
                        end
                    end
                else
                    if not QCharging then
                        Control.KeyDown(HK_Q)
                        QCharging = true
                        QStartTime = Game.Timer()
                    end
                end
            end
        end
        
        if self.Menu.ks.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and myHero.pos:DistanceTo(target.pos) <= 550 then
            local EDmg = getdmg("E", target, myHero) or 0
            if target.health <= EDmg then
                local prediction = GetPrediction(target, "E")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                    Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                end
            end
        end
    end
end

function L9Pyke:Draw()
    if myHero.dead then return end
    
    if not CheckPredictionSystem() then return end
    
    if self.Menu.Drawing.DrawQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
        Draw.Circle(myHero.pos, SPELL_RANGE.Q, 1, Draw.Color(255, 255, 0, 0))
    end
    
    if self.Menu.Drawing.DrawE:Value() and _G.L9Engine:IsSpellReady(_E) then
        Draw.Circle(myHero.pos, SPELL_RANGE.E, 1, Draw.Color(255, 0, 255, 0))
    end
    
    if self.Menu.Drawing.DrawR:Value() and _G.L9Engine:IsSpellReady(_R) then
        Draw.Circle(myHero.pos, SPELL_RANGE.R, 1, Draw.Color(255, 0, 0, 255))
    end
    
    if self.Menu.Drawing.Kill:Value() then
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero.isEnemy and _G.L9Engine:IsValidEnemy(hero) and _G.L9Engine:CalculateDistance(myHero.pos, hero.pos) <= 2000 then
                local ultDamage = GetUltDamage()
                if hero.health <= ultDamage and _G.L9Engine:IsSpellReady(_R) then
                    local pos = hero.pos:To2D()
                    Draw.Text("TUABLE", 20, pos.x - 30, pos.y - 50, Draw.Color(255, 255, 0, 0))
                end
            end
        end
    end
end

L9Pyke()

