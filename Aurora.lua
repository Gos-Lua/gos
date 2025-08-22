-- L9Engine compatibility guard
if _G.__L9_ENGINE_AURORA_LOADED then return end
_G.__L9_ENGINE_AURORA_LOADED = true

local Version = 1.0
local Name = "L9Aurora"

-- Hero validation
local Heroes = {"Aurora"}
if not table.contains(Heroes, myHero.charName) then return end

-- Load prediction system
require("DepressivePrediction")
require("DamageLib")
local PredictionLoaded = false
DelayAction(function()
    if _G.DepressivePrediction then
        PredictionLoaded = true
        print("L9Aurora: DepressivePrediction loaded!")
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
    Q = 900,
    W = 450,
    E = 825,
    R = 700
}

local SPELL_SPEED = {
    Q = 1800,
    W = 20,
    E = 1600,
    R = 2000
}

local SPELL_DELAY = {
    Q = 0.25,
    W = 0.25,
    E = 0.25,
    R = 0.5
}

local SPELL_RADIUS = {
    Q = 80,
    W = 70,
    E = 100,
    R = 200
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

class "L9Aurora"

function L9Aurora:__init()
    self:LoadMenu()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function L9Aurora:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Aurora", name = "L9Aurora"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. Version}})
    
    self.Menu:MenuElement({type = MENU, id = "AutoW", name = "AutoW"})
    self.Menu.AutoW:MenuElement({id = "UseW", name = "Safe Life", value = true})
    self.Menu.AutoW:MenuElement({id = "hp", name = "Self Hp", value = 40, min = 1, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "UseQ", name = "[Q] Aurora Beam", value = true})
    self.Menu.Combo:MenuElement({id = "UseW", name = "[W] Aurora Shield", value = true})
    self.Menu.Combo:MenuElement({id = "UseE", name = "[E] Aurora Burst", value = true})
    self.Menu.Combo:MenuElement({id = "UseR", name = "[R] Aurora Storm", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "[Q] Aurora Beam", value = true})
    self.Menu.Harass:MenuElement({id = "UseE", name = "[E] Aurora Burst", value = true})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
    self.Menu.Clear:MenuElement({id = "UseQ", name = "[Q] Aurora Beam", value = true})
    self.Menu.Clear:MenuElement({id = "UseE", name = "[E] Aurora Burst", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "JClear", name = "JungleClear"})
    self.Menu.JClear:MenuElement({id = "UseQ", name = "[Q] Aurora Beam", value = true})
    self.Menu.JClear:MenuElement({id = "UseE", name = "[E] Aurora Burst", value = true})
    self.Menu.JClear:MenuElement({id = "Mana", name = "Min Mana to JungleClear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
    self.Menu.ks:MenuElement({id = "UseQ", name = "[Q] Aurora Beam", value = true})
    self.Menu.ks:MenuElement({id = "UseE", name = "[E] Aurora Burst", value = true})
    self.Menu.ks:MenuElement({id = "UseR", name = "[R] Aurora Storm", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
    self.Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "Kill", name = "Draw Killable Targets", value = true})
end

function L9Aurora:Tick()
    if myHero.dead or Game.IsChatOpen() then return end
    
    if not CheckPredictionSystem() then return end
    
    local Mode = _G.L9Engine:GetCurrentMode()
    
    if Mode == "Combo" then
        self:Combo()
    elseif Mode == "Harass" then
        self:Harass()
    elseif Mode == "Clear" then
        self:Clear()
        self:JungleClear()
    elseif Mode == "LastHit" then
        -- LastHit not implemented for Aurora
    end
    
    self:KillSteal()
    self:AutoW()
end

function L9Aurora:Combo()
    local target = _G.L9Engine:GetBestTarget(1000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        -- R Logic (Ultimate)
        if myHero.pos:DistanceTo(target.pos) <= 700 and self.Menu.Combo.UseR:Value() and _G.L9Engine:IsSpellReady(_R) then
            local prediction = GetPrediction(target, "R")
            if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                Control.CastSpell(HK_R, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
            else
                Control.CastSpell(HK_R, target.pos)
            end
        end
        
        -- Q Logic
        if myHero.pos:DistanceTo(target.pos) <= 900 and self.Menu.Combo.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
            local prediction = GetPrediction(target, "Q")
            if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                Control.CastSpell(HK_Q, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
            else
                Control.CastSpell(HK_Q, target.pos)
            end
        end
        
        -- E Logic
        if myHero.pos:DistanceTo(target.pos) <= 825 and self.Menu.Combo.UseE:Value() and _G.L9Engine:IsSpellReady(_E) then
            local prediction = GetPrediction(target, "E")
            if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
            else
                Control.CastSpell(HK_E, target.pos)
            end
        end
        
        -- W Logic (Shield)
        if myHero.pos:DistanceTo(target.pos) <= 450 and self.Menu.Combo.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
            Control.CastSpell(HK_W, target)
        end
        
        -- Auto Attack
        if myHero.pos:DistanceTo(target.pos) <= 175 and _G.SDK and _G.SDK.Orbwalker:CanAttack() then
            Control.Attack(target)
        end
    end
end

function L9Aurora:Harass()
    local target = _G.L9Engine:GetBestTarget(1000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
        
        -- Q Logic
        if myHero.pos:DistanceTo(target.pos) <= 900 and self.Menu.Harass.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
            local prediction = GetPrediction(target, "Q")
            if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                Control.CastSpell(HK_Q, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
            else
                Control.CastSpell(HK_Q, target.pos)
            end
        end
        
        -- E Logic
        if myHero.pos:DistanceTo(target.pos) <= 825 and self.Menu.Harass.UseE:Value() and _G.L9Engine:IsSpellReady(_E) then
            local prediction = GetPrediction(target, "E")
            if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
            else
                Control.CastSpell(HK_E, target.pos)
            end
        end
    end
end

function L9Aurora:Clear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        
        if myHero.pos:DistanceTo(minion.pos) <= 900 and minion.team == TEAM_ENEMY and _G.L9Engine:IsValidEnemy(minion) and myHero.mana/myHero.maxMana >= self.Menu.Clear.Mana:Value() / 100 then
            
            -- Q Logic
            if myHero.pos:DistanceTo(minion.pos) <= 900 and _G.L9Engine:IsSpellReady(_Q) and self.Menu.Clear.UseQ:Value() then
                local prediction = GetPrediction(minion, "Q")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                    Control.CastSpell(HK_Q, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                    break
                end
            end
            
            -- E Logic
            if myHero.pos:DistanceTo(minion.pos) <= 825 and _G.L9Engine:IsSpellReady(_E) and self.Menu.Clear.UseE:Value() then
                local prediction = GetPrediction(minion, "E")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                    Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                    break
                end
            end
        end
    end
end

function L9Aurora:JungleClear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        
        if myHero.pos:DistanceTo(minion.pos) <= 900 and minion.team == TEAM_JUNGLE and _G.L9Engine:IsValidEnemy(minion) and myHero.mana/myHero.maxMana >= self.Menu.JClear.Mana:Value() / 100 then
            
            -- Q Logic
            if myHero.pos:DistanceTo(minion.pos) <= 900 and _G.L9Engine:IsSpellReady(_Q) and self.Menu.JClear.UseQ:Value() then
                local prediction = GetPrediction(minion, "Q")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                    Control.CastSpell(HK_Q, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                    break
                end
            end
            
            -- E Logic
            if myHero.pos:DistanceTo(minion.pos) <= 825 and _G.L9Engine:IsSpellReady(_E) and self.Menu.JClear.UseE:Value() then
                local prediction = GetPrediction(minion, "E")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                    Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                    break
                end
            end
        end
    end
end

function L9Aurora:KillSteal()
    local target = _G.L9Engine:GetBestTarget(1000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        -- R KillSteal
        if self.Menu.ks.UseR:Value() and _G.L9Engine:IsSpellReady(_R) and myHero.pos:DistanceTo(target.pos) <= 700 then
            local RDmg = getdmg("R", target, myHero) or 0
            if target.health <= RDmg then
                local prediction = GetPrediction(target, "R")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                    Control.CastSpell(HK_R, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                end
            end
        end
        
        -- Q KillSteal
        if self.Menu.ks.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= 900 then
            local QDmg = getdmg("Q", target, myHero) or 0
            if target.health <= QDmg then
                local prediction = GetPrediction(target, "Q")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                    Control.CastSpell(HK_Q, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                end
            end
        end
        
        -- E KillSteal
        if self.Menu.ks.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and myHero.pos:DistanceTo(target.pos) <= 825 then
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

function L9Aurora:AutoW()
    local target = _G.L9Engine:GetBestTarget(450)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) and myHero.pos:DistanceTo(target.pos) <= 450 and self.Menu.AutoW.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
        if myHero.health/myHero.maxHealth <= self.Menu.AutoW.hp:Value()/100 then
            Control.CastSpell(HK_W, target)
        end
    end
end

function L9Aurora:Draw()
    if myHero.dead then return end
    
    if not CheckPredictionSystem() then return end
    
    local textPos = myHero.pos:To2D()
    
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
    
    if self.Menu.Drawing.Kill:Value() then
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero.isEnemy and _G.L9Engine:IsValidEnemy(hero) and myHero.pos:DistanceTo(hero.pos) <= 2000 then
                local QDmg = getdmg("Q", hero, myHero) or 0
                local EDmg = getdmg("E", hero, myHero) or 0
                local RDmg = getdmg("R", hero, myHero) or 0
                local totalDmg = QDmg + EDmg + RDmg
                
                if hero.health <= totalDmg then
                    local pos = hero.pos:To2D()
                    Draw.Text("TUABLE", 20, pos.x - 30, pos.y - 50, Draw.Color(255, 255, 0, 0))
                end
            end
        end
    end
    
    Draw.Text("Aurora - L9 Script", 15, textPos.x - 80, textPos.y + 40, Draw.Color(255, 255, 255, 255))
end

L9Aurora()

