-- L9Engine compatibility guard
if _G.__L9_ENGINE_THRESH_LOADED then return end
_G.__L9_ENGINE_THRESH_LOADED = true

local Version = 1.0
local Name = "L9Thresh"

-- Hero validation
local Heroes = {"Thresh"}
if not table.contains(Heroes, myHero.charName) then return end

-- Load Thresh-specific prediction system
local ThreshPrediction = require("ThreshPrediction")
local PredictionLoaded = false
local PredictionVersion = "Unknown"

-- Spell constants
local SPELL_RANGE = {
    Q = 1075,
    W = 950,
    E = 400,
    R = 420
}

local SPELL_SPEED = {
    Q = 1900,
    W = math.huge,
    E = math.huge,
    R = math.huge
}

local SPELL_DELAY = {
    Q = 0.5,
    W = 0.25,
    E = 0.25,
    R = 0.25
}

DelayAction(function()
    if ThreshPrediction then
        PredictionLoaded = true
        PredictionVersion = ThreshPrediction.Version or "Unknown"
        print("L9Thresh: ThreshPrediction v" .. PredictionVersion .. " loaded!")
    end
end, 1.0)

-- Check if prediction system is working
local function CheckPredictionSystem()
    if not PredictionLoaded or not ThreshPrediction then
        return false
    end
    
    if not ThreshPrediction.GetPrediction then
        return false
    end
    
    return true
end

-- Get prediction for Thresh Q
local function GetQPrediction(target)
    if not target or not target.valid then return nil, 0 end
    
    if CheckPredictionSystem() then
        local prediction = ThreshPrediction.GetPrediction(target, SPELL_RANGE.Q, SPELL_SPEED.Q, SPELL_DELAY.Q, 70)
        if prediction and prediction.hitchance then
            return prediction.castPos, prediction.hitchance
        end
    end
    
    return {x = target.pos.x, z = target.pos.z}, 2
end

class "L9Thresh"

function L9Thresh:__init()
    self:LoadMenu()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function L9Thresh:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Thresh", name = "L9Thresh"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. Version}})
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "UseQ", name = "[Q] Death Sentence", value = true})
    self.Menu.Combo:MenuElement({id = "UseW", name = "[W] Dark Passage", value = true})
    self.Menu.Combo:MenuElement({id = "UseE", name = "[E] Flay", value = true})
    self.Menu.Combo:MenuElement({id = "UseR", name = "[R] The Box", value = true})
    self.Menu.Combo:MenuElement({id = "QHitChance", name = "Q Hit Chance", value = 2, min = 1, max = 4, identifier = ""})
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "[Q] Death Sentence", value = true})
    self.Menu.Harass:MenuElement({id = "UseE", name = "[E] Flay", value = false})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"})
    self.Menu.Harass:MenuElement({id = "QHitChance", name = "Q Hit Chance", value = 3, min = 1, max = 4, identifier = ""})
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
    self.Menu.Clear:MenuElement({id = "UseQ", name = "[Q] Death Sentence", value = false})
    self.Menu.Clear:MenuElement({id = "UseE", name = "[E] Flay", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "JClear", name = "JungleClear"})
    self.Menu.JClear:MenuElement({id = "UseQ", name = "[Q] Death Sentence", value = true})
    self.Menu.JClear:MenuElement({id = "UseE", name = "[E] Flay", value = true})
    self.Menu.JClear:MenuElement({id = "Mana", name = "Min Mana to JungleClear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
    self.Menu.ks:MenuElement({id = "UseQ", name = "[Q] Death Sentence", value = true})
    self.Menu.ks:MenuElement({id = "UseE", name = "[E] Flay", value = true})
    self.Menu.ks:MenuElement({id = "UseR", name = "[R] The Box", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
    self.Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = false})
end

function L9Thresh:Tick()
    if myHero.dead or Game.IsChatOpen() then return end
    
    if not CheckPredictionSystem() then return end
    
    local Mode = _G.L9Engine:GetMode()
    
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

function L9Thresh:Combo()
    local target = _G.L9Engine:GetTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidTarget(target) then
        -- R Logic (The Box)
        if myHero.pos:DistanceTo(target.pos) <= 420 and self.Menu.Combo.UseR:Value() and _G.L9Engine:Ready(_R) then
            Control.CastSpell(HK_R, target.pos)
        end
        
        -- E Logic (Flay)
        if myHero.pos:DistanceTo(target.pos) <= 400 and self.Menu.Combo.UseE:Value() and _G.L9Engine:Ready(_E) then
            Control.CastSpell(HK_E, target.pos)
        end
        
        -- Q Logic (Death Sentence)
        if myHero.pos:DistanceTo(target.pos) <= 1075 and self.Menu.Combo.UseQ:Value() and _G.L9Engine:Ready(_Q) then
            local prediction, hitChance = GetQPrediction(target)
            if prediction and hitChance >= self.Menu.Combo.QHitChance:Value() then
                Control.CastSpell(HK_Q, Vector(prediction.x, myHero.pos.y, prediction.z))
            end
        end
        
        -- W Logic (Dark Passage) - for allies
        if self.Menu.Combo.UseW:Value() and _G.L9Engine:Ready(_W) then
            -- Logic for casting W on allies can be added here
            -- This is a simplified version
        end
    end
end

function L9Thresh:Harass()
    local target = _G.L9Engine:GetTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidTarget(target) and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
        
        -- Q Logic (Death Sentence)
        if myHero.pos:DistanceTo(target.pos) <= 1075 and self.Menu.Harass.UseQ:Value() and _G.L9Engine:Ready(_Q) then
            local prediction, hitChance = GetQPrediction(target)
            if prediction and hitChance >= self.Menu.Harass.QHitChance:Value() then
                Control.CastSpell(HK_Q, Vector(prediction.x, myHero.pos.y, prediction.z))
            end
        end
        
        -- E Logic (Flay)
        if myHero.pos:DistanceTo(target.pos) <= 400 and self.Menu.Harass.UseE:Value() and _G.L9Engine:Ready(_E) then
            Control.CastSpell(HK_E, target.pos)
        end
    end
end

function L9Thresh:LaneClear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        
        if myHero.pos:DistanceTo(minion.pos) <= 400 and minion.team == TEAM_ENEMY and _G.L9Engine:IsValidTarget(minion) and myHero.mana/myHero.maxMana >= self.Menu.Clear.Mana:Value() / 100 then
            
            -- E Logic (Flay)
            if myHero.pos:DistanceTo(minion.pos) <= 400 and _G.L9Engine:Ready(_E) and self.Menu.Clear.UseE:Value() then
                Control.CastSpell(HK_E, minion.pos)
                break
            end
            
            -- Q Logic (Death Sentence)
            if myHero.pos:DistanceTo(minion.pos) <= 1075 and _G.L9Engine:Ready(_Q) and self.Menu.Clear.UseQ:Value() then
                local prediction, hitChance = GetQPrediction(minion)
                if prediction and hitChance >= 2 then
                    Control.CastSpell(HK_Q, Vector(prediction.x, myHero.pos.y, prediction.z))
                    break
                end
            end
        end
    end
end

function L9Thresh:JungleClear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        
        if myHero.pos:DistanceTo(minion.pos) <= 400 and minion.team == TEAM_JUNGLE and _G.L9Engine:IsValidTarget(minion) and myHero.mana/myHero.maxMana >= self.Menu.JClear.Mana:Value() / 100 then
            
            -- E Logic (Flay)
            if myHero.pos:DistanceTo(minion.pos) <= 400 and _G.L9Engine:Ready(_E) and self.Menu.JClear.UseE:Value() then
                Control.CastSpell(HK_E, minion.pos)
                break
            end
            
            -- Q Logic (Death Sentence)
            if myHero.pos:DistanceTo(minion.pos) <= 1075 and _G.L9Engine:Ready(_Q) and self.Menu.JClear.UseQ:Value() then
                local prediction, hitChance = GetQPrediction(minion)
                if prediction and hitChance >= 2 then
                    Control.CastSpell(HK_Q, Vector(prediction.x, myHero.pos.y, prediction.z))
                    break
                end
            end
        end
    end
end

function L9Thresh:KillSteal()
    local target = _G.L9Engine:GetTarget(1200)
    if target == nil then return end
    
    if _G.L9Engine:IsValidTarget(target) then
        -- R KillSteal
        if self.Menu.ks.UseR:Value() and _G.L9Engine:Ready(_R) and myHero.pos:DistanceTo(target.pos) <= 420 then
            local RDmg = getdmg("R", target, myHero) or 0
            if target.health <= RDmg then
                Control.CastSpell(HK_R, target.pos)
            end
        end
        
        -- E KillSteal
        if self.Menu.ks.UseE:Value() and _G.L9Engine:Ready(_E) and myHero.pos:DistanceTo(target.pos) <= 400 then
            local EDmg = getdmg("E", target, myHero) or 0
            if target.health <= EDmg then
                Control.CastSpell(HK_E, target.pos)
            end
        end
        
        -- Q KillSteal
        if self.Menu.ks.UseQ:Value() and _G.L9Engine:Ready(_Q) and myHero.pos:DistanceTo(target.pos) <= 1075 then
            local QDmg = getdmg("Q", target, myHero) or 0
            if target.health <= QDmg then
                local prediction, hitChance = GetQPrediction(target)
                if prediction and hitChance >= 2 then
                    Control.CastSpell(HK_Q, Vector(prediction.x, myHero.pos.y, prediction.z))
                end
            end
        end
    end
end

function L9Thresh:Draw()
    if myHero.dead then return end
    
    if not CheckPredictionSystem() then return end
    
    if self.Menu.Drawing.DrawQ:Value() and _G.L9Engine:Ready(_Q) then
        Draw.Circle(myHero.pos, SPELL_RANGE.Q, 1, Draw.Color(255, 255, 0, 0))
    end
    
    if self.Menu.Drawing.DrawW:Value() and _G.L9Engine:Ready(_W) then
        Draw.Circle(myHero.pos, SPELL_RANGE.W, 1, Draw.Color(255, 0, 255, 0))
    end
    
    if self.Menu.Drawing.DrawE:Value() and _G.L9Engine:Ready(_E) then
        Draw.Circle(myHero.pos, SPELL_RANGE.E, 1, Draw.Color(255, 0, 0, 255))
    end
    
    if self.Menu.Drawing.DrawR:Value() and _G.L9Engine:Ready(_R) then
        Draw.Circle(myHero.pos, SPELL_RANGE.R, 1, Draw.Color(255, 255, 255, 0))
    end
end

L9Thresh()
