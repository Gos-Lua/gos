local Version = 1.0
local Name = "L9Sylas"

if not table.contains then
    table.contains = function(t, value)
        for i = 1, #t do
            if t[i] == value then
                return true
            end
        end
        return false
    end
end

local Heroes = {"Sylas"}
if not table.contains(Heroes, myHero.charName) then return end

require("DepressivePrediction")
require("DamageLib")
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

local function GetDistance(p1, p2)
    if not p1 or not p2 then return math.huge end
    local dx = p1.x - p2.x
    local dz = p1.z - p2.z
    return math.sqrt(dx * dx + dz * dz)
end

local function Ready(spell)
    if not spell then return false end
    local spellData = myHero:GetSpellData(spell)
    if not spellData then return false end
    return spellData.currentCd == 0 and Game.CanUseSpell(spell) == 0
end

local function IsValidTarget(target, range)
    if not target then return false end
    if target.dead or not target.visible or not target.isTargetable then return false end
    if target.team == myHero.team then return false end
    if range and GetDistance(myHero.pos, target.pos) > range then return false end
    return true
end

local function GetBuffData(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then
            return buff
        end
    end
    return {count = 0}
end

local function GetMinionCount(range, pos)
    local pos = pos.pos
    local count = 0
    for i = 1, Game.MinionCount() do
        local hero = Game.Minion(i)
        local Range = range * range
        if hero.team ~= TEAM_ALLY and hero.dead == false and GetDistanceSqr(pos, hero.pos) < Range then
            count = count + 1
        end
    end
    return count
end

local function GetDistanceSqr(p1, p2)
    local dx = p1.x - p2.x
    local dz = p1.z - p2.z
    return dx * dx + dz * dz
end

local function GetMode()
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

local function GetTarget(range)
    if _G.SDK then
        return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL)
    elseif _G.EOWLoaded then
        return EOW:GetTarget(range)
    elseif _G.GOS then
        return GOS:GetTarget(range)
    end
    return nil
end

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

local function keyInList(key, keyList)
    for _, k in ipairs(keyList) do
        if key == k then
            return true
        end
    end
    return false
end

class "L9Sylas"

function L9Sylas:__init()
    self:LoadMenu()
    
    self.keyMap = self:BuildKeyMap()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function L9Sylas:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Sylas", name = "L9Sylas"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. Version}})
    
    self.Menu:MenuElement({type = MENU, id = "keybinds", name = "Keybinds / Layout"})
    self.Menu.keybinds:MenuElement({id = "layout", name = "Keyboard Layout", value = 1, drop = {"QWERTY", "AZERTY"}})
    self.Menu.keybinds:MenuElement({id = "info", name = "Actions (Space/Combo, V/Clear, X/LastHit, C/Harass)", type = SPACE})
    self.Menu.keybinds:MenuElement({id = "remapAbilities", name = "Remap ability keys to slots (cast with keys)", value = false, tooltip = "When enabled, pressing the configured Q/W/E/R keys will simulate HK_Q/HK_W/HK_E/HK_R to cast abilities."})
    
    local defaultQ, defaultW, defaultE, defaultR = string.byte("Q"), string.byte("W"), string.byte("E"), string.byte("R")
    self.Menu.keybinds:MenuElement({id = "keyQ", name = "Ability Q Key", key = defaultQ, toggle = false, onKeyChange = function(k)
        self.abilitiesVK = self.abilitiesVK or {}
        self.abilitiesVK.q = k
        self.keyMap = self:BuildKeyMap()
    end})
    self.Menu.keybinds:MenuElement({id = "keyW", name = "Ability W Key", key = defaultW, toggle = false, onKeyChange = function(k)
        self.abilitiesVK = self.abilitiesVK or {}
        self.abilitiesVK.w = k
        self.keyMap = self:BuildKeyMap()
    end})
    self.Menu.keybinds:MenuElement({id = "keyE", name = "Ability E Key", key = defaultE, toggle = false, onKeyChange = function(k)
        self.abilitiesVK = self.abilitiesVK or {}
        self.abilitiesVK.e = k
        self.keyMap = self:BuildKeyMap()
    end})
    self.Menu.keybinds:MenuElement({id = "keyR", name = "Ability R Key", key = defaultR, toggle = false, onKeyChange = function(k)
        self.abilitiesVK = self.abilitiesVK or {}
        self.abilitiesVK.r = k
        self.keyMap = self:BuildKeyMap()
    end})
    self.abilitiesVK = { q = defaultQ, w = defaultW, e = defaultE, r = defaultR }
    
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

function L9Sylas:BuildKeyMap()
    local layoutIdx = self.Menu and self.Menu.keybinds and self.Menu.keybinds.layout:Value() or 1
    local isAZERTY = (layoutIdx == 2)
    local VK = {
        SPACE = 32, A = 65, C = 67, V = 86, X = 88, Q = 81, W = 87, E = 69, R = 82
    }
    local abilitiesVK = self.abilitiesVK or { q = VK.Q, w = VK.W, e = VK.E, r = VK.R }
    return {
        combo = {VK.SPACE},
        clear = {VK.V},
        lasthit = {VK.X},
        harass = {VK.C},
        abilities = {
            q = {abilitiesVK.q},
            w = {abilitiesVK.w},
            e = {abilitiesVK.e},
            r = {abilitiesVK.r}
        }
    }
end

function L9Sylas:Tick()
    if myHero.dead or Game.IsChatOpen() then return end
    
    if not CheckPredictionSystem() then return end
    
    self.keyMap = self:BuildKeyMap()
    
    local Mode = GetMode()
    
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
    local target = GetTarget(1300)
    if target == nil then return end
    
    if IsValidTarget(target) then
        if myHero.pos:DistanceTo(target.pos) < 1300 and self.Menu.Combo.UseE:Value() and Ready(_E) then
            Control.CastSpell(HK_E, target.pos)
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 800 and Ready(_E) then
            local prediction = GetPrediction(target, "E")
            if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
            else
                Control.CastSpell(HK_E, target.pos)
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 775 and self.Menu.Combo.UseQ:Value() and Ready(_Q) then
            local prediction = GetPrediction(target, "Q")
            if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                Control.CastSpell(HK_Q, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
            else
                Control.CastSpell(HK_Q, target.pos)
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 400 and self.Menu.Combo.UseW:Value() and Ready(_W) then
            Control.CastSpell(HK_W, target)
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 175 and _G.SDK and _G.SDK.Orbwalker:CanAttack() then
            Control.Attack(target)
        end
    end
end

function L9Sylas:Harass()
    local target = GetTarget(1300)
    if target == nil then return end
    
    if IsValidTarget(target) and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
        
        if myHero.pos:DistanceTo(target.pos) <= 800 and myHero:GetSpellData(_E).name == "SylasE2" then
            local prediction = GetPrediction(target, "E")
            if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) < 1300 and self.Menu.Harass.UseE:Value() and Ready(_E) then
            if myHero:GetSpellData(_E).name == "SylasE" then
                Control.CastSpell(HK_E, target.pos)
            end
        end
        
        local passiveBuff = GetBuffData(myHero, "SylasPassiveAttack")
        if passiveBuff.count == 1 and myHero.pos:DistanceTo(target.pos) < 400 then return end
        
        if myHero.pos:DistanceTo(target.pos) <= 775 and self.Menu.Harass.UseQ:Value() and Ready(_Q) then
            local prediction = GetPrediction(target, "Q")
            if prediction and prediction[1] and prediction[2] and prediction[2] >= 2 then
                Control.CastSpell(HK_Q, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
            end
        end
        
        if myHero.pos:DistanceTo(target.pos) <= 400 and self.Menu.Harass.UseW:Value() and Ready(_W) then
            Control.CastSpell(HK_W, target)
        end
    end
end

function L9Sylas:LastHit()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        local target = GetTarget(1000)
        if target == nil then
            if myHero.pos:DistanceTo(minion.pos) <= 800 and minion.team == TEAM_ENEMY and IsValidTarget(minion) and myHero.mana/myHero.maxMana >= self.Menu.Clear.Mana:Value() / 100 then
                local count = GetMinionCount(225, minion)
                local hp = minion.health
                local QDmg = getdmg("Q", minion, myHero) or 0
                if Ready(_Q) and self.Menu.Harass.LH.UseQL:Value() and count >= self.Menu.Harass.LH.UseQLM:Value() and hp <= QDmg then
                    Control.CastSpell(HK_Q, minion)
                end
            end
        end
    end
end

function L9Sylas:Clear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        local passiveBuff = GetBuffData(myHero, "SylasPassiveAttack")
        
        if myHero.pos:DistanceTo(minion.pos) <= 1300 and minion.team == TEAM_ENEMY and IsValidTarget(minion) and myHero.mana/myHero.maxMana >= self.Menu.Clear.Mana:Value() / 100 then
            
            if myHero.pos:DistanceTo(minion.pos) <= 800 and myHero:GetSpellData(_E).name == "SylasE2" then
                local prediction = GetPrediction(minion, "E")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 0 then
                    Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                end
            end
            
            if myHero.pos:DistanceTo(minion.pos) < 1300 and Ready(_E) and self.Menu.Clear.UseE:Value() and myHero:GetSpellData(_E).name == "SylasE" then
                Control.CastSpell(HK_E, minion)
            end
            
            if passiveBuff.count == 1 and myHero.pos:DistanceTo(minion.pos) < 400 then return end
            
            if myHero.pos:DistanceTo(minion.pos) <= 755 and Ready(_Q) and self.Menu.Clear.UseQL:Value() and GetMinionCount(225, minion) >= self.Menu.Clear.UseQLM:Value() then
                Control.CastSpell(HK_Q, minion)
            end
            
            if myHero.pos:DistanceTo(minion.pos) <= 400 and Ready(_W) and self.Menu.Clear.UseW:Value() then
                Control.CastSpell(HK_W, minion)
            end
        end
    end
end

function L9Sylas:JungleClear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        
        if myHero.pos:DistanceTo(minion.pos) <= 1300 and minion.team == TEAM_JUNGLE and IsValidTarget(minion) and myHero.mana/myHero.maxMana >= self.Menu.JClear.Mana:Value() / 100 then
            
            if myHero.pos:DistanceTo(minion.pos) <= 800 and myHero:GetSpellData(_E).name == "SylasE2" then
                local prediction = GetPrediction(minion, "E")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 0 then
                    Control.CastSpell(HK_E, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                end
            end
            
            if myHero.pos:DistanceTo(minion.pos) < 1300 and Ready(_E) and self.Menu.JClear.UseE:Value() and myHero:GetSpellData(_E).name == "SylasE" then
                Control.CastSpell(HK_E, minion)
            end
            
            local passiveBuff = GetBuffData(myHero, "SylasPassiveAttack")
            if passiveBuff.count == 1 and myHero.pos:DistanceTo(minion.pos) < 400 then return end
            
            if myHero.pos:DistanceTo(minion.pos) <= 775 and Ready(_Q) and self.Menu.JClear.UseQ:Value() then
                Control.CastSpell(HK_Q, minion)
            end
            
            if myHero.pos:DistanceTo(minion.pos) <= 400 and Ready(_W) and self.Menu.JClear.UseW:Value() then
                Control.CastSpell(HK_W, minion)
            end
        end
    end
end

function L9Sylas:KillSteal()
    local target = GetTarget(25000)
    if target == nil then return end
    
    if IsValidTarget(target) then
        if self.Menu.ks.UseQ:Value() and Ready(_Q) and myHero.pos:DistanceTo(target.pos) <= 775 then
            local QDmg = getdmg("Q", target, myHero) or 0
            if target.health <= QDmg then
                local prediction = GetPrediction(target, "Q")
                if prediction and prediction[1] and prediction[2] and prediction[2] >= 1 then
                    Control.CastSpell(HK_Q, Vector(prediction[1].x, myHero.pos.y, prediction[1].z))
                end
            end
        end
        
        if self.Menu.ks.UseE:Value() and Ready(_E) and myHero.pos:DistanceTo(target.pos) <= 800 then
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
        
        if self.Menu.ks.UseW:Value() and Ready(_W) and myHero.pos:DistanceTo(target.pos) <= 400 then
            local WDmg = getdmg("W", target, myHero) or 0
            if target.health <= WDmg then
                Control.CastSpell(HK_W, target)
            end
        end
    end
end

function L9Sylas:AutoW()
    local target = GetTarget(400)
    if target == nil then return end
    
    if IsValidTarget(target) and myHero.pos:DistanceTo(target.pos) <= 400 and self.Menu.AutoW.UseW:Value() and Ready(_W) then
        if myHero.health/myHero.maxHealth <= self.Menu.AutoW.hp:Value()/100 then
            Control.CastSpell(HK_W, target)
        end
    end
end

function L9Sylas:Draw()
    if myHero.dead then return end
    
    if not CheckPredictionSystem() then return end
    
    local textPos = myHero.pos:To2D()
    
    if self.Menu.Drawing.DrawQ:Value() and Ready(_Q) then
        Draw.Circle(myHero.pos, SPELL_RANGE.Q, 1, Draw.Color(255, 255, 0, 0))
    end
    
    if self.Menu.Drawing.DrawW:Value() and Ready(_W) then
        Draw.Circle(myHero.pos, SPELL_RANGE.W, 1, Draw.Color(255, 0, 255, 0))
    end
    
    if self.Menu.Drawing.DrawE:Value() and Ready(_E) then
        Draw.Circle(myHero.pos, SPELL_RANGE.E, 1, Draw.Color(255, 0, 0, 255))
    end
    
    if self.Menu.Drawing.Kill:Value() then
        for i = 1, Game.HeroCount() do
            local hero = Game.Hero(i)
            if hero.isEnemy and IsValidTarget(hero) and myHero.pos:DistanceTo(hero.pos) <= 2000 then
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
    
    local passiveBuff = GetBuffData(myHero, "SylasPassiveAttack")
    Draw.Text("Passive Stacks: " .. (passiveBuff.count or 0), 15, textPos.x - 80, textPos.y + 60, Draw.Color(255, 255, 255, 255))
end

L9Sylas()
