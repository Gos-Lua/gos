-- L9Engine compatibility guard
if _G.__L9_ENGINE_XINZHAO_LOADED then return end
_G.__L9_ENGINE_XINZHAO_LOADED = true

local Version = 1.0
local Name = "L9Xin"

-- Hero validation
local Heroes = {"XinZhao"}
if not table.contains(Heroes, myHero.charName) then return end

-- Load prediction system
require("DepressivePrediction")
local PredictionLoaded = false
DelayAction(function()
    if _G.DepressivePrediction then
        PredictionLoaded = true
        print("L9Xin: DepressivePrediction loaded!")
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

-- Variables pour tracker l'état du W
local WLastCastTime = 0
local WTarget = nil
local WDuration = 3.0 -- Durée du W en secondes

-- Fonction pour vérifier si le W a touché la cible récemment
local function IsWActiveOnTarget(target)
    if not target or not WTarget then return false end
    
    -- Vérifier si c'est la même cible et si le W est encore actif
    if target.networkID == WTarget.networkID then
        local timeSinceW = Game.Timer() - WLastCastTime
        return timeSinceW < WDuration
    end
    
    return false
end

-- Fonction pour obtenir la portée réelle de l'E (650 normal, 900 avec W actif sur la cible)
local function GetERange(target)
    if target and IsWActiveOnTarget(target) then
        return 900
    end
    return 650
end

-- Fonction pour vérifier si l'ennemi est bumpé par le Q
local function IsTargetBumped(target)
    local buffNames = {"XinZhaoQKnockup", "XinZhaoQ", "ThreeTalonStrike", "threetalonstrike", "knockup", "airborne"}
    for _, buffName in ipairs(buffNames) do
        local buff = _G.L9Engine:GetBuffData(target, buffName)
        if buff then
            return true
        end
    end
    return false
end

-- Fonction pour compter les hits du Q
local function GetQHits()
    local buffNames = {"XinZhaoQ", "ThreeTalonStrike", "threetalonstrike"}
    for _, buffName in ipairs(buffNames) do
        local buff = _G.L9Engine:GetBuffData(myHero, buffName)
        if buff then
            return buff.count or 0
        end
    end
    return 0
end

local SPELL_RANGE = {
    Q = 175,
    W = 900,
    E = 650, -- Sera ajusté dynamiquement
    R = 500
}

local SPELL_SPEED = {
    W = 2000,
    E = 2000,
    R = 2000
}

local SPELL_DELAY = {
    W = 0.25,
    E = 0.25,
    R = 0.25
}

local SPELL_RADIUS = {
    W = 100,
    E = 50,
    R = 500
}

local function GetPrediction(target, spell)
    if not target or not target.valid then return nil, 0 end
    
    if CheckPredictionSystem() then
        local spellData = {
            range = spell == "E" and GetERange(target) or SPELL_RANGE[spell],
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

class "L9Xin"

function L9Xin:__init()
    self:LoadMenu()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function L9Xin:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Xin", name = "L9Xin"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. Version}})
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "UseQ", name = "[Q] Three Talon Strike", value = true})
    self.Menu.Combo:MenuElement({id = "UseW", name = "[W] Battle Cry", value = true})
    self.Menu.Combo:MenuElement({id = "UseE", name = "[E] Audacious Charge", value = true})
    self.Menu.Combo:MenuElement({id = "UseR", name = "[R] Crescent Guard", value = true})
    self.Menu.Combo:MenuElement({id = "ComboLogic", name = "Combo Logic: W->E->Q->W", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "[Q] Three Talon Strike", value = true})
    self.Menu.Harass:MenuElement({id = "UseW", name = "[W] Battle Cry", value = false})
    self.Menu.Harass:MenuElement({id = "UseE", name = "[E] Audacious Charge", value = true})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
    self.Menu.Clear:MenuElement({id = "UseQ", name = "[Q] Three Talon Strike", value = true})
    self.Menu.Clear:MenuElement({id = "UseW", name = "[W] Battle Cry", value = true})
    self.Menu.Clear:MenuElement({id = "UseE", name = "[E] Audacious Charge", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "JClear", name = "JungleClear"})
    self.Menu.JClear:MenuElement({id = "UseQ", name = "[Q] Three Talon Strike", value = true})
    self.Menu.JClear:MenuElement({id = "UseW", name = "[W] Battle Cry", value = true})
    self.Menu.JClear:MenuElement({id = "UseE", name = "[E] Audacious Charge", value = true})
    self.Menu.JClear:MenuElement({id = "Mana", name = "Min Mana to JungleClear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
    self.Menu.LastHit:MenuElement({id = "UseQ", name = "[Q] Three Talon Strike", value = true})
    self.Menu.LastHit:MenuElement({id = "Mana", name = "Min Mana to LastHit", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
    self.Menu.ks:MenuElement({id = "UseQ", name = "[Q] Three Talon Strike", value = true})
    self.Menu.ks:MenuElement({id = "UseW", name = "[W] Battle Cry", value = true})
    self.Menu.ks:MenuElement({id = "UseE", name = "[E] Audacious Charge", value = true})
    self.Menu.ks:MenuElement({id = "UseR", name = "[R] Crescent Guard", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
    self.Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawWActive", name = "Draw Extended E Range when W active", value = true})
end

function L9Xin:Tick()
    if myHero.dead or Game.IsChatOpen() then return end
    
    if not CheckPredictionSystem() then return end
    
    self:AutoAttackReset()
    
    local Mode = _G.L9Engine:GetMode()
    
    if Mode == "Combo" then
        self:Combo()
    elseif Mode == "Harass" then
        self:Harass()
    elseif Mode == "Clear" then
        self:LaneClear()
        self:JungleClear()
    elseif Mode == "LastHit" then
        self:LastHit()
    end
    
    self:KillSteal()
end

function L9Xin:AutoAttackReset()
    if _G.SDK and _G.SDK.Orbwalker:CanAttack() then
        local target = _G.L9Engine:GetTarget(175)
        if target and _G.L9Engine:IsValidTarget(target, 175) then
            if self.Menu.Combo.UseQ:Value() and _G.L9Engine:Ready(_Q) then
                Control.CastSpell(HK_Q)
            end
        end
    end
end

function L9Xin:Combo()
    local target = _G.L9Engine:GetTarget(1000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidTarget(target) then
        local eRange = GetERange(target)
        local distance = myHero.pos:DistanceTo(target.pos)
        
        -- Logique de combo intelligente
        if self.Menu.Combo.ComboLogic:Value() then
            -- 1. Si pas en range E (650) et W pas actif sur la cible -> Utiliser W pour étendre la portée
            if distance > 650 and not IsWActiveOnTarget(target) and self.Menu.Combo.UseW:Value() and _G.L9Engine:Ready(_W) then
                local prediction = GetPrediction(target, "W")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                    Control.CastSpell(HK_W, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                    -- Enregistrer le cast du W
                    WLastCastTime = Game.Timer()
                    WTarget = target
                else
                    Control.CastSpell(HK_W, target.pos)
                    WLastCastTime = Game.Timer()
                    WTarget = target
                end
                return
            end
            
            -- 2. Si en range E (avec ou sans W) -> E vers la cible
            if distance <= eRange and self.Menu.Combo.UseE:Value() and _G.L9Engine:Ready(_E) then
                local prediction = GetPrediction(target, "E")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                    Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                else
                    Control.CastSpell(HK_E, target.pos)
                end
                return
            end
            
            -- 3. Si proche de la cible -> Q pour les 3 hits
            if distance <= 175 and self.Menu.Combo.UseQ:Value() and _G.L9Engine:Ready(_Q) then
                Control.CastSpell(HK_Q)
                return
            end
            
            -- 4. Si la cible est bumpée par le Q -> W pour le knockback
            if distance <= 175 and IsTargetBumped(target) and self.Menu.Combo.UseW:Value() and _G.L9Engine:Ready(_W) then
                local prediction = GetPrediction(target, "W")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                    Control.CastSpell(HK_W, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                else
                    Control.CastSpell(HK_W, target.pos)
                end
                return
            end
            
            -- 5. R Logic (si tout le reste est fait)
            if distance <= 500 and self.Menu.Combo.UseR:Value() and _G.L9Engine:Ready(_R) then
                local prediction = GetPrediction(target, "R")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                    Control.CastSpell(HK_R, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                else
                    Control.CastSpell(HK_R, target.pos)
                end
            end
            
            -- 6. Auto Attack
            if distance <= 175 and _G.SDK and _G.SDK.Orbwalker:CanAttack() then
                Control.Attack(target)
            end
        else
            -- Ancienne logique simple
            -- E Logic (Gapcloser) - utilise la portée dynamique
            if distance <= eRange and self.Menu.Combo.UseE:Value() and _G.L9Engine:Ready(_E) then
                local prediction = GetPrediction(target, "E")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                    Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                else
                    Control.CastSpell(HK_E, target.pos)
                end
            end
            
            -- W Logic
            if distance <= 900 and self.Menu.Combo.UseW:Value() and _G.L9Engine:Ready(_W) then
                local prediction = GetPrediction(target, "W")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                    Control.CastSpell(HK_W, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                else
                    Control.CastSpell(HK_W, target.pos)
                end
            end
            
            -- R Logic
            if distance <= 500 and self.Menu.Combo.UseR:Value() and _G.L9Engine:Ready(_R) then
                local prediction = GetPrediction(target, "R")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                    Control.CastSpell(HK_R, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                else
                    Control.CastSpell(HK_R, target.pos)
                end
            end
            
            -- Q Logic (Auto Attack Reset)
            if distance <= 175 and self.Menu.Combo.UseQ:Value() and _G.L9Engine:Ready(_Q) then
                Control.CastSpell(HK_Q)
            end
            
            -- Auto Attack
            if distance <= 175 and _G.SDK and _G.SDK.Orbwalker:CanAttack() then
                Control.Attack(target)
            end
        end
    end
end

function L9Xin:Harass()
    local target = _G.L9Engine:GetTarget(1000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidTarget(target) and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
        local eRange = GetERange(target)
        
        -- E Logic
        if myHero.pos:DistanceTo(target.pos) <= eRange and self.Menu.Harass.UseE:Value() and _G.L9Engine:Ready(_E) then
            local prediction = GetPrediction(target, "E")
            if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
            else
                Control.CastSpell(HK_E, target.pos)
            end
        end
        
        -- W Logic
        if myHero.pos:DistanceTo(target.pos) <= 900 and self.Menu.Harass.UseW:Value() and _G.L9Engine:Ready(_W) then
            local prediction = GetPrediction(target, "W")
            if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                Control.CastSpell(HK_W, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
            else
                Control.CastSpell(HK_W, target.pos)
            end
        end
        
        -- Q Logic
        if myHero.pos:DistanceTo(target.pos) <= 175 and self.Menu.Harass.UseQ:Value() and _G.L9Engine:Ready(_Q) then
            Control.CastSpell(HK_Q)
        end
    end
end

function L9Xin:LaneClear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        local eRange = GetERange(minion)
        
        if myHero.pos:DistanceTo(minion.pos) <= eRange and minion.team == TEAM_ENEMY and _G.L9Engine:IsValidTarget(minion) and myHero.mana/myHero.maxMana >= self.Menu.Clear.Mana:Value() / 100 then
            
            -- E Logic
            if myHero.pos:DistanceTo(minion.pos) <= eRange and _G.L9Engine:Ready(_E) and self.Menu.Clear.UseE:Value() then
                local prediction = GetPrediction(minion, "E")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                    Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                    break
                end
            end
            
            -- W Logic
            if myHero.pos:DistanceTo(minion.pos) <= 900 and _G.L9Engine:Ready(_W) and self.Menu.Clear.UseW:Value() then
                local prediction = GetPrediction(minion, "W")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                    Control.CastSpell(HK_W, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                    break
                end
            end
            
            -- Q Logic
            if myHero.pos:DistanceTo(minion.pos) <= 175 and _G.L9Engine:Ready(_Q) and self.Menu.Clear.UseQ:Value() then
                Control.CastSpell(HK_Q)
                break
            end
        end
    end
end

function L9Xin:JungleClear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        local eRange = GetERange(minion)
        
        if myHero.pos:DistanceTo(minion.pos) <= eRange and minion.team == TEAM_JUNGLE and _G.L9Engine:IsValidTarget(minion) and myHero.mana/myHero.maxMana >= self.Menu.JClear.Mana:Value() / 100 then
            
            -- E Logic
            if myHero.pos:DistanceTo(minion.pos) <= eRange and _G.L9Engine:Ready(_E) and self.Menu.JClear.UseE:Value() then
                local prediction = GetPrediction(minion, "E")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                    Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                    break
                end
            end
            
            -- W Logic
            if myHero.pos:DistanceTo(minion.pos) <= 900 and _G.L9Engine:Ready(_W) and self.Menu.JClear.UseW:Value() then
                local prediction = GetPrediction(minion, "W")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                    Control.CastSpell(HK_W, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                    break
                end
            end
            
            -- Q Logic
            if myHero.pos:DistanceTo(minion.pos) <= 175 and _G.L9Engine:Ready(_Q) and self.Menu.JClear.UseQ:Value() then
                Control.CastSpell(HK_Q)
                break
            end
        end
    end
end

function L9Xin:LastHit()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        
        if myHero.pos:DistanceTo(minion.pos) <= 175 and minion.team == TEAM_ENEMY and _G.L9Engine:IsValidTarget(minion) and myHero.mana/myHero.maxMana >= self.Menu.LastHit.Mana:Value() / 100 then
            
            -- Q Logic for LastHit
            if myHero.pos:DistanceTo(minion.pos) <= 175 and _G.L9Engine:Ready(_Q) and self.Menu.LastHit.UseQ:Value() then
                local QDmg = getdmg("Q", minion, myHero) or 0
                if minion.health <= QDmg then
                    Control.CastSpell(HK_Q)
                    break
                end
            end
        end
    end
end

function L9Xin:KillSteal()
    local target = _G.L9Engine:GetTarget(1000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidTarget(target) then
        local eRange = GetERange(target)
        
        -- R KillSteal
        if self.Menu.ks.UseR:Value() and _G.L9Engine:Ready(_R) and myHero.pos:DistanceTo(target.pos) <= 500 then
            local RDmg = getdmg("R", target, myHero) or 0
            if target.health <= RDmg then
                local prediction = GetPrediction(target, "R")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                    Control.CastSpell(HK_R, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                end
            end
        end
        
        -- E KillSteal
        if self.Menu.ks.UseE:Value() and _G.L9Engine:Ready(_E) and myHero.pos:DistanceTo(target.pos) <= eRange then
            local EDmg = getdmg("E", target, myHero) or 0
            if target.health <= EDmg then
                local prediction = GetPrediction(target, "E")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                    Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                end
            end
        end
        
        -- W KillSteal
        if self.Menu.ks.UseW:Value() and _G.L9Engine:Ready(_W) and myHero.pos:DistanceTo(target.pos) <= 900 then
            local WDmg = getdmg("W", target, myHero) or 0
            if target.health <= WDmg then
                local prediction = GetPrediction(target, "W")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                    Control.CastSpell(HK_W, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                end
            end
        end
        
        -- Q KillSteal
        if self.Menu.ks.UseQ:Value() and _G.L9Engine:Ready(_Q) and myHero.pos:DistanceTo(target.pos) <= 175 then
            local QDmg = getdmg("Q", target, myHero) or 0
            if target.health <= QDmg then
                Control.CastSpell(HK_Q)
            end
        end
    end
end

function L9Xin:Draw()
    if myHero.dead then return end
    
    if not CheckPredictionSystem() then return end
    
    if self.Menu.Drawing.DrawQ:Value() and _G.L9Engine:Ready(_Q) then
        Draw.Circle(myHero.pos, SPELL_RANGE.Q, 1, Draw.Color(255, 255, 0, 0))
    end
    
    if self.Menu.Drawing.DrawW:Value() and _G.L9Engine:Ready(_W) then
        Draw.Circle(myHero.pos, SPELL_RANGE.W, 1, Draw.Color(255, 0, 255, 0))
    end
    
    if self.Menu.Drawing.DrawE:Value() and _G.L9Engine:Ready(_E) then
        local target = _G.L9Engine:GetTarget(1000)
        local eRange = target and GetERange(target) or 650
        local color = (target and IsWActiveOnTarget(target)) and Draw.Color(255, 255, 165, 0) or Draw.Color(255, 0, 0, 255) -- Orange si W actif, bleu sinon
        Draw.Circle(myHero.pos, eRange, 1, color)
    end
    
    if self.Menu.Drawing.DrawR:Value() and _G.L9Engine:Ready(_R) then
        Draw.Circle(myHero.pos, SPELL_RANGE.R, 1, Draw.Color(255, 255, 255, 0))
    end
    
    -- Affichage spécial pour la portée étendue de l'E quand W est actif
    if self.Menu.Drawing.DrawWActive:Value() then
        local target = _G.L9Engine:GetTarget(1000)
        if target and IsWActiveOnTarget(target) and _G.L9Engine:Ready(_E) then
            Draw.Circle(myHero.pos, 900, 1, Draw.Color(255, 255, 165, 0)) -- Orange pour la portée étendue
        end
    end
end

L9Xin()
