-- L9Engine compatibility guard
if _G.__L9_ENGINE_SYLAS_LOADED then return end
_G.__L9_ENGINE_SYLAS_LOADED = true

local Version = 1.0
local Name = "L9Sylas"

-- Hero validation
local Heroes = {"Sylas"}
if not table.contains(Heroes, myHero.charName) then return end

-- Load prediction system
require("DepressivePrediction")
local PredictionLoaded = false
DelayAction(function()
    if _G.DepressivePrediction then
        PredictionLoaded = true
        print("L9Sylas: DepressivePrediction loaded!")
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
    Q = 775,
    W = 400,
    E = 800
}

local SPELL_SPEED = {
    Q = math.huge,
    W = 20,
    E = 1800
}

local SPELL_DELAY = {
    Q = 0.25,
    W = 0.25,
    E = 0.25
}

local SPELL_RADIUS = {
    Q = 70,
    W = 70,
    E = 60
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

-- Fonction pour calculer les dégâts des sorts
local function getdmg(spell, target, source)
    if not target or not source then return 0 end
    
    if spell == "Q" then
        local level = source:GetSpellData(_Q).level
        if level == 0 then return 0 end
        local baseDmg = 60 + (level - 1) * 40
        local apRatio = 0.6
        return baseDmg + (source.ap * apRatio)
    elseif spell == "W" then
        local level = source:GetSpellData(_W).level
        if level == 0 then return 0 end
        local baseDmg = 65 + (level - 1) * 35
        local apRatio = 0.85
        return baseDmg + (source.ap * apRatio)
    elseif spell == "E" then
        local level = source:GetSpellData(_E).level
        if level == 0 then return 0 end
        local baseDmg = 70 + (level - 1) * 30
        local apRatio = 0.7
        return baseDmg + (source.ap * apRatio)
    end
    
    return 0
end

class "L9Sylas"

function L9Sylas:__init()
    self:LoadMenu()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function L9Sylas:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Sylas", name = "L9Sylas"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. Version}})
    
    self.Menu:MenuElement({type = MENU, id = "AutoW", name = "AutoW"})
    self.Menu.AutoW:MenuElement({id = "UseW", name = "Safe Life", value = true})
    self.Menu.AutoW:MenuElement({id = "hp", name = "Self Hp", value = 40, min = 1, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "UseQ", name = "[Q] Chain Lash", value = true})
    self.Menu.Combo:MenuElement({id = "UseE", name = "[E] Abscond / Abduct", value = true})
    self.Menu.Combo:MenuElement({id = "UseW", name = "[W] Kingslayer", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({type = MENU, id = "LH", name = "LastHit"})
    self.Menu.Harass.LH:MenuElement({id = "UseQL", name = "LastHit[Q] Minions", value = true, tooltip = "There is no Enemy nearby"})
    self.Menu.Harass.LH:MenuElement({id = "UseQLM", name = "LastHit[Q] min Minions", value = 2, min = 1, max = 6})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "[Q] Chain Lash", value = true})
    self.Menu.Harass:MenuElement({id = "UseW", name = "[W] Kingslayer", value = true})
    self.Menu.Harass:MenuElement({id = "UseE", name = "[E] Abscond / Abduct", value = true})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
    self.Menu.Clear:MenuElement({id = "UseQL", name = "[Q] Chain Lash", value = true})
    self.Menu.Clear:MenuElement({id = "UseQLM", name = "[Q] min Minions", value = 2, min = 1, max = 6})
    self.Menu.Clear:MenuElement({id = "UseE", name = "[E] Abscond / Abduct", value = true})
    self.Menu.Clear:MenuElement({id = "UseEM", name = "Use [E] min Minions", value = 3, min = 1, max = 6})
    self.Menu.Clear:MenuElement({id = "UseW", name = "[W] Kingslayer", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "JClear", name = "JungleClear"})
    self.Menu.JClear:MenuElement({id = "UseQ", name = "[Q] Chain Lash", value = true})
    self.Menu.JClear:MenuElement({id = "UseE", name = "[E] Abscond / Abduct", value = true})
    self.Menu.JClear:MenuElement({id = "UseW", name = "[W] Kingslayer", value = true})
    self.Menu.JClear:MenuElement({id = "Mana", name = "Min Mana to JungleClear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
    self.Menu.ks:MenuElement({id = "UseQ", name = "[Q] Chain Lash", value = true})
    self.Menu.ks:MenuElement({id = "UseE", name = "[E] Abscond / Abduct", value = true})
    self.Menu.ks:MenuElement({id = "UseW", name = "[W] Kingslayer", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
    self.Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "Kill", name = "Draw Killable Targets", value = true})
end

function L9Sylas:Tick()
    if myHero.dead or Game.IsChatOpen() then return end
    
    if not CheckPredictionSystem() then return end
    
    local Mode = _G.L9Engine:GetCurrentMode()
    
    if Mode == "Combo" then
        self:Combo()
    elseif Mode == "Harass" then
        self:Harass()
        self:LastHit()
    elseif Mode == "Clear" then
        self:Clear()
        self:JungleClear()
    elseif Mode == "LastHit" then
        self:LastHit()
    end
    
    self:KillSteal()
    self:AutoW()
end

function L9Sylas:Combo()
    local target = _G.L9Engine:GetBestTarget(1300)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        if myHero.pos:DistanceTo(target.pos) < 1300 and self.Menu.Combo.UseE:Value() and _G.L9Engine:IsSpellReady(_E) then
            Control.CastSpell(HK_E, target.pos)
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 800 and _G.L9Engine:IsSpellReady(_E) then
            local prediction = GetPrediction(target, "E")
            if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
            else
                Control.CastSpell(HK_E, target.pos)
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 775 and self.Menu.Combo.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
            local prediction = GetPrediction(target, "Q")
            if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                Control.CastSpell(HK_Q, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
            else
                Control.CastSpell(HK_Q, target.pos)
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 400 and self.Menu.Combo.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
            Control.CastSpell(HK_W, target)
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 175 and _G.SDK and _G.SDK.Orbwalker:CanAttack() then
            Control.Attack(target)
        end
    end
end

function L9Sylas:Harass()
    local target = _G.L9Engine:GetBestTarget(1300)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
        
        if myHero.pos:DistanceTo(target.pos) <= 800 and myHero:GetSpellData(_E).name == "SylasE2" then
            local prediction = GetPrediction(target, "E")
            if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) < 1300 and self.Menu.Harass.UseE:Value() and _G.L9Engine:IsSpellReady(_E) then
            if myHero:GetSpellData(_E).name == "SylasE" then
                Control.CastSpell(HK_E, target.pos)
            end
        end
        
        local passiveBuff = _G.L9Engine:GetUnitBuff(myHero, "SylasPassiveAttack")
        if passiveBuff and passiveBuff.count == 1 and myHero.pos:DistanceTo(target.pos) < 400 then return end
        
        if myHero.pos:DistanceTo(target.pos) <= 775 and self.Menu.Harass.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
            local prediction = GetPrediction(target, "Q")
            if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                Control.CastSpell(HK_Q, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 400 and self.Menu.Harass.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
            Control.CastSpell(HK_W, target)
        end
    end
end

function L9Sylas:LastHit()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        local target = _G.L9Engine:GetBestTarget(1000)
        if target == nil then
            if myHero.pos:DistanceTo(minion.pos) <= 800 and minion.team == TEAM_ENEMY and _G.L9Engine:IsValidEnemy(minion) and myHero.mana/myHero.maxMana >= self.Menu.Clear.Mana:Value() / 100 then
                local count = _G.L9Engine:CountEnemyMinions(225)
                local hp = minion.health
                local QDmg = getdmg("Q", minion, myHero) or 0
                if _G.L9Engine:IsSpellReady(_Q) and self.Menu.Harass.LH.UseQL:Value() and count >= self.Menu.Harass.LH.UseQLM:Value() and hp <= QDmg then
                    Control.CastSpell(HK_Q, minion)
                end
            end
        end
    end
end

function L9Sylas:Clear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        local passiveBuff = _G.L9Engine:GetUnitBuff(myHero, "SylasPassiveAttack")
        
        if myHero.pos:DistanceTo(minion.pos) <= 1300 and minion.team == TEAM_ENEMY and _G.L9Engine:IsValidEnemy(minion) and myHero.mana/myHero.maxMana >= self.Menu.Clear.Mana:Value() / 100 then
            
            if myHero.pos:DistanceTo(minion.pos) <= 800 and myHero:GetSpellData(_E).name == "SylasE2" then
                local prediction = GetPrediction(minion, "E")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 0 then
                    Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                end
            end
            
            if myHero.pos:DistanceTo(minion.pos) < 1300 and _G.L9Engine:IsSpellReady(_E) and self.Menu.Clear.UseE:Value() and myHero:GetSpellData(_E).name == "SylasE" then
                Control.CastSpell(HK_E, minion)
            end
            
            if passiveBuff and passiveBuff.count == 1 and myHero.pos:DistanceTo(minion.pos) < 400 then return end
            
            if myHero.pos:DistanceTo(minion.pos) <= 755 and _G.L9Engine:IsSpellReady(_Q) and self.Menu.Clear.UseQL:Value() and _G.L9Engine:CountEnemyMinions(225) >= self.Menu.Clear.UseQLM:Value() then
                Control.CastSpell(HK_Q, minion)
            end
            
            if myHero.pos:DistanceTo(minion.pos) <= 400 and _G.L9Engine:IsSpellReady(_W) and self.Menu.Clear.UseW:Value() then
                Control.CastSpell(HK_W, minion)
            end
        end
    end
end

function L9Sylas:JungleClear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        
        if myHero.pos:DistanceTo(minion.pos) <= 1300 and minion.team == TEAM_JUNGLE and _G.L9Engine:IsValidEnemy(minion) and myHero.mana/myHero.maxMana >= self.Menu.JClear.Mana:Value() / 100 then
            
            if myHero.pos:DistanceTo(minion.pos) <= 800 and myHero:GetSpellData(_E).name == "SylasE2" then
                local prediction = GetPrediction(minion, "E")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 0 then
                    Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                end
            end
            
            if myHero.pos:DistanceTo(minion.pos) < 1300 and _G.L9Engine:IsSpellReady(_E) and self.Menu.JClear.UseE:Value() and myHero:GetSpellData(_E).name == "SylasE" then
                Control.CastSpell(HK_E, minion)
            end
            
            local passiveBuff = _G.L9Engine:GetUnitBuff(myHero, "SylasPassiveAttack")
            if passiveBuff and passiveBuff.count == 1 and myHero.pos:DistanceTo(minion.pos) < 400 then return end
            
            if myHero.pos:DistanceTo(minion.pos) <= 775 and _G.L9Engine:IsSpellReady(_Q) and self.Menu.JClear.UseQ:Value() then
                Control.CastSpell(HK_Q, minion)
            end
            
            if myHero.pos:DistanceTo(minion.pos) <= 400 and _G.L9Engine:IsSpellReady(_W) and self.Menu.JClear.UseW:Value() then
                Control.CastSpell(HK_W, minion)
            end
        end
    end
end

function L9Sylas:KillSteal()
    local target = _G.L9Engine:GetBestTarget(25000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        if self.Menu.ks.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= 775 then
            local QDmg = getdmg("Q", target, myHero) or 0
            if target.health <= QDmg then
                local prediction = GetPrediction(target, "Q")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                    Control.CastSpell(HK_Q, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                end
            end
        end
        
        if self.Menu.ks.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and myHero.pos:DistanceTo(target.pos) <= 800 then
            local EDmg = getdmg("E", target, myHero) or 0
            if target.health <= EDmg then
                if myHero:GetSpellData(_E).name == "SylasE2" then
                    local prediction = GetPrediction(target, "E")
                    if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                        Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                    end
                elseif myHero:GetSpellData(_E).name == "SylasE" then
                    Control.CastSpell(HK_E, target.pos)
                end
            end
        end
        
        if self.Menu.ks.UseW:Value() and _G.L9Engine:IsSpellReady(_W) and myHero.pos:DistanceTo(target.pos) <= 400 then
            local WDmg = getdmg("W", target, myHero) or 0
            if target.health <= WDmg then
                Control.CastSpell(HK_W, target)
            end
        end
    end
end

function L9Sylas:AutoW()
    local target = _G.L9Engine:GetBestTarget(400)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) and myHero.pos:DistanceTo(target.pos) <= 400 and self.Menu.AutoW.UseW:Value() and _G.L9Engine:IsSpellReady(_W) then
        if myHero.health/myHero.maxHealth <= self.Menu.AutoW.hp:Value()/100 then
            Control.CastSpell(HK_W, target)
        end
    end
end

function L9Sylas:Draw()
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
    
    if self.Menu.Drawing.Kill:Value() then
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero.isEnemy and _G.L9Engine:IsValidEnemy(hero) and myHero.pos:DistanceTo(hero.pos) <= 2000 then
                local QDmg = getdmg("Q", hero, myHero) or 0
                local WDmg = getdmg("W", hero, myHero) or 0
                local EDmg = getdmg("E", hero, myHero) or 0
                local totalDmg = QDmg + WDmg + EDmg
                
                if hero.health <= totalDmg then
                    local pos = hero.pos:To2D()
                    Draw.Text("TUABLE", 20, pos.x - 30, pos.y - 50, Draw.Color(255, 255, 0, 0))
                end
            end
        end
    end
    
    local passiveBuff = _G.L9Engine:GetUnitBuff(myHero, "SylasPassiveAttack")
    local passiveStacks = passiveBuff and passiveBuff.count or 0
    Draw.Text("Passive Stacks: " .. passiveStacks, 15, textPos.x - 80, textPos.y + 60, Draw.Color(255, 255, 255, 255))
end

L9Sylas()

