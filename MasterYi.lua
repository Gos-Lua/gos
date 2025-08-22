-- L9Engine compatibility guard
if _G.__L9_ENGINE_MASTERYI_LOADED then return end
_G.__L9_ENGINE_MASTERYI_LOADED = true

local Version = 1.0
local Name = "L9Yi"

-- Hero validation
local Heroes = {"MasterYi"}
if not table.contains(Heroes, myHero.charName) then return end

local function IsAutoAttacking()
    return myHero.attackData.state == STATE_WINDUP or myHero.attackData.state == STATE_ATTACK
end

local function CanAutoAttack()
    return myHero.attackData.state == STATE_ATTACK or myHero.attackData.state == STATE_WINDUP
end

local function GetAutoAttackDamage()
    return myHero.totalDamage
end

local function GetQDamage()
    local level = myHero:GetSpellData(_Q).level
    local baseDamage = ({25, 60, 95, 130, 165})[level] or 165
    local bonusDamage = myHero.bonusDamage * 0.6
    return baseDamage + bonusDamage
end

class "L9Yi"

function L9Yi:__init()
    self:LoadMenu()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    Callback.Add("Attack", function(unit) self:OnAttack(unit) end)
end

function L9Yi:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Yi", name = "L9Yi"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. Version}})
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "UseQ", name = "[Q] Alpha Strike", value = true})
    self.Menu.Combo:MenuElement({id = "UseW", name = "[W] Meditate", value = true})
    self.Menu.Combo:MenuElement({id = "UseE", name = "[E] Wuju Style", value = true})
    self.Menu.Combo:MenuElement({id = "UseR", name = "[R] Highlander", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "[Q] Alpha Strike", value = true})
    self.Menu.Harass:MenuElement({id = "UseE", name = "[E] Wuju Style", value = false})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
    self.Menu.Clear:MenuElement({id = "UseQ", name = "[Q] Alpha Strike", value = true})
    self.Menu.Clear:MenuElement({id = "UseE", name = "[E] Wuju Style", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "JClear", name = "JungleClear"})
    self.Menu.JClear:MenuElement({id = "UseQ", name = "[Q] Alpha Strike", value = true})
    self.Menu.JClear:MenuElement({id = "UseE", name = "[E] Wuju Style", value = true})
    self.Menu.JClear:MenuElement({id = "Mana", name = "Min Mana to JungleClear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "LastHit", name = "LastHit"})
    self.Menu.LastHit:MenuElement({id = "UseQ", name = "[Q] Alpha Strike", value = true})
    self.Menu.LastHit:MenuElement({id = "Mana", name = "Min Mana to LastHit", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "ks", name = "KillSteal"})
    self.Menu.ks:MenuElement({id = "UseQ", name = "[Q] Alpha Strike", value = true})
    self.Menu.ks:MenuElement({id = "UseE", name = "[E] Wuju Style", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
    self.Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = false})
end

function L9Yi:OnAttack(unit)
    -- Auto attack reset logic can be added here if needed
end

function L9Yi:Tick()
    if myHero.dead or Game.IsChatOpen() then return end
    
    self:AutoAttackReset()
    
    local Mode = _G.L9Engine:GetCurrentMode()
    
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

function L9Yi:AutoAttackReset()
    if _G.SDK and _G.SDK.Orbwalker:CanAttack() then
        local target = _G.L9Engine:GetBestTarget(600)
        if target and _G.L9Engine:IsValidEnemy(target, 600) then
            if self.Menu.Combo.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
                Control.CastSpell(HK_Q, target)
            end
        end
    end
end

function L9Yi:Combo()
    local target = _G.L9Engine:GetBestTarget(600)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        -- R Logic (Ultimate)
        if myHero.pos:DistanceTo(target.pos) <= 600 and self.Menu.Combo.UseR:Value() and _G.L9Engine:IsSpellReady(_R) then
            Control.CastSpell(HK_R)
        end
        
        -- E Logic (Wuju Style)
        if myHero.pos:DistanceTo(target.pos) <= 175 and self.Menu.Combo.UseE:Value() and _G.L9Engine:IsSpellReady(_E) then
            Control.CastSpell(HK_E)
        end
        
        -- Q Logic (Alpha Strike)
        if myHero.pos:DistanceTo(target.pos) <= 600 and self.Menu.Combo.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
            Control.CastSpell(HK_Q, target)
        end
        
        -- W Logic (Meditate) - for sustain
        if self.Menu.Combo.UseW:Value() and _G.L9Engine:IsSpellReady(_W) and myHero.health/myHero.maxHealth < 0.5 then
            Control.CastSpell(HK_W)
        end
        
        -- Auto Attack
        if myHero.pos:DistanceTo(target.pos) <= 175 and _G.SDK and _G.SDK.Orbwalker:CanAttack() then
            Control.Attack(target)
        end
    end
end

function L9Yi:Harass()
    local target = _G.L9Engine:GetBestTarget(600)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
        
        -- Q Logic (Alpha Strike)
        if myHero.pos:DistanceTo(target.pos) <= 600 and self.Menu.Harass.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
            Control.CastSpell(HK_Q, target)
        end
        
        -- E Logic (Wuju Style)
        if myHero.pos:DistanceTo(target.pos) <= 175 and self.Menu.Harass.UseE:Value() and _G.L9Engine:IsSpellReady(_E) then
            Control.CastSpell(HK_E)
        end
    end
end

function L9Yi:LaneClear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        
        if myHero.pos:DistanceTo(minion.pos) <= 600 and minion.team == TEAM_ENEMY and _G.L9Engine:IsValidEnemy(minion) and myHero.mana/myHero.maxMana >= self.Menu.Clear.Mana:Value() / 100 then
            
            -- Q Logic (Alpha Strike)
            if myHero.pos:DistanceTo(minion.pos) <= 600 and _G.L9Engine:IsSpellReady(_Q) and self.Menu.Clear.UseQ:Value() then
                Control.CastSpell(HK_Q, minion)
                break
            end
            
            -- E Logic (Wuju Style)
            if myHero.pos:DistanceTo(minion.pos) <= 175 and _G.L9Engine:IsSpellReady(_E) and self.Menu.Clear.UseE:Value() then
                Control.CastSpell(HK_E)
                break
            end
        end
    end
end

function L9Yi:JungleClear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        
        if myHero.pos:DistanceTo(minion.pos) <= 600 and minion.team == TEAM_JUNGLE and _G.L9Engine:IsValidEnemy(minion) and myHero.mana/myHero.maxMana >= self.Menu.JClear.Mana:Value() / 100 then
            
            -- Q Logic (Alpha Strike)
            if myHero.pos:DistanceTo(minion.pos) <= 600 and _G.L9Engine:IsSpellReady(_Q) and self.Menu.JClear.UseQ:Value() then
                Control.CastSpell(HK_Q, minion)
                break
            end
            
            -- E Logic (Wuju Style)
            if myHero.pos:DistanceTo(minion.pos) <= 175 and _G.L9Engine:IsSpellReady(_E) and self.Menu.JClear.UseE:Value() then
                Control.CastSpell(HK_E)
                break
            end
        end
    end
end

function L9Yi:LastHit()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        
        if myHero.pos:DistanceTo(minion.pos) <= 600 and minion.team == TEAM_ENEMY and _G.L9Engine:IsValidEnemy(minion) and myHero.mana/myHero.maxMana >= self.Menu.LastHit.Mana:Value() / 100 then
            
            -- Q Logic for LastHit
            if myHero.pos:DistanceTo(minion.pos) <= 600 and _G.L9Engine:IsSpellReady(_Q) and self.Menu.LastHit.UseQ:Value() then
                local QDmg = GetQDamage()
                if minion.health <= QDmg then
                    Control.CastSpell(HK_Q, minion)
                    break
                end
            end
        end
    end
end

function L9Yi:KillSteal()
    local target = _G.L9Engine:GetBestTarget(600)
    if target == nil then return end
    
    if _G.L9Engine:IsValidEnemy(target) then
        -- Q KillSteal
        if self.Menu.ks.UseQ:Value() and _G.L9Engine:IsSpellReady(_Q) and myHero.pos:DistanceTo(target.pos) <= 600 then
            local QDmg = GetQDamage()
            if target.health <= QDmg then
                Control.CastSpell(HK_Q, target)
            end
        end
        
        -- E KillSteal
        if self.Menu.ks.UseE:Value() and _G.L9Engine:IsSpellReady(_E) and myHero.pos:DistanceTo(target.pos) <= 175 then
            local EDmg = getdmg("E", target, myHero) or 0
            if target.health <= EDmg then
                Control.CastSpell(HK_E)
            end
        end
    end
end

function L9Yi:Draw()
    if myHero.dead then return end
    
    if self.Menu.Drawing.DrawQ:Value() and _G.L9Engine:IsSpellReady(_Q) then
        Draw.Circle(myHero.pos, 600, 1, Draw.Color(255, 255, 0, 0))
    end
    
    if self.Menu.Drawing.DrawE:Value() and _G.L9Engine:IsSpellReady(_E) then
        Draw.Circle(myHero.pos, 175, 1, Draw.Color(255, 0, 255, 0))
    end
    
    if self.Menu.Drawing.DrawR:Value() and _G.L9Engine:IsSpellReady(_R) then
        Draw.Circle(myHero.pos, 600, 1, Draw.Color(255, 0, 0, 255))
    end
end

L9Yi()

