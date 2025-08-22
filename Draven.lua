-- L9Engine compatibility guard
if _G.__L9_ENGINE_DRAVEN_LOADED then return end
_G.__L9_ENGINE_DRAVEN_LOADED = true

local Version = 1.0
local Name = "L9LeagueOfDraven"

-- Hero validation
local Heroes = {"Draven"}
if not table.contains(Heroes, myHero.charName) then return end

class "L9LeagueOfDraven"

function L9LeagueOfDraven:__init()
    self:LoadMenu()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
end

function L9LeagueOfDraven:LoadMenu()
    self.Menu = MenuElement({type = MENU, id = "L9LeagueOfDraven", name = "L9LeagueOfDraven"})
    self.Menu:MenuElement({name = " ", drop = {"Version " .. Version}})
    
    self.Menu:MenuElement({type = MENU, id = "Combo", name = "Combo"})
    self.Menu.Combo:MenuElement({id = "UseQ", name = "[Q] Spinning Axe", value = true})
    self.Menu.Combo:MenuElement({id = "UseW", name = "[W] Blood Rush", value = true})
    self.Menu.Combo:MenuElement({id = "UseE", name = "[E] Stand Aside", value = true})
    self.Menu.Combo:MenuElement({id = "UseR", name = "[R] Whirling Death", value = true})
    
    self.Menu:MenuElement({type = MENU, id = "Harass", name = "Harass"})
    self.Menu.Harass:MenuElement({id = "UseQ", name = "[Q] Spinning Axe", value = true})
    self.Menu.Harass:MenuElement({id = "UseW", name = "[W] Blood Rush", value = false})
    self.Menu.Harass:MenuElement({id = "Mana", name = "Min Mana to Harass", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "Clear", name = "LaneClear"})
    self.Menu.Clear:MenuElement({id = "UseQ", name = "[Q] Spinning Axe", value = true})
    self.Menu.Clear:MenuElement({id = "UseW", name = "[W] Blood Rush", value = true})
    self.Menu.Clear:MenuElement({id = "Mana", name = "Min Mana to Clear", value = 40, min = 0, max = 100, identifier = "%"})
    
    self.Menu:MenuElement({type = MENU, id = "AntiGapclose", name = "Anti Gapclose"})
    self.Menu.AntiGapclose:MenuElement({id = "UseE", name = "[E] Stand Aside", value = true})
    self.Menu.AntiGapclose:MenuElement({id = "Range", name = "Range", value = 300, min = 100, max = 500})
    
    self.Menu:MenuElement({type = MENU, id = "Drawing", name = "Drawings"})
    self.Menu.Drawing:MenuElement({id = "DrawQ", name = "Draw [Q] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawW", name = "Draw [W] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawE", name = "Draw [E] Range", value = false})
    self.Menu.Drawing:MenuElement({id = "DrawR", name = "Draw [R] Range", value = false})
end

function L9LeagueOfDraven:Tick()
    if myHero.dead or Game.IsChatOpen() then return end
    
    local Mode = _G.L9Engine:GetMode()
    
    if Mode == "Combo" then
        self:Combo()
    elseif Mode == "Harass" then
        self:Harass()
    elseif Mode == "Clear" then
        self:LaneClear()
    elseif Mode == "LastHit" then
        -- LastHit not implemented for Draven
    end
    
    self:AntiGapclose()
end

function L9LeagueOfDraven:Combo()
    local target = _G.L9Engine:GetTarget(1000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidTarget(target) then
        -- Q Logic (Spinning Axe)
        if myHero.pos:DistanceTo(target.pos) <= 550 and self.Menu.Combo.UseQ:Value() and _G.L9Engine:Ready(_Q) then
            Control.CastSpell(HK_Q)
        end
        
        -- W Logic (Blood Rush)
        if myHero.pos:DistanceTo(target.pos) <= 400 and self.Menu.Combo.UseW:Value() and _G.L9Engine:Ready(_W) then
            Control.CastSpell(HK_W)
        end
        
        -- E Logic (Stand Aside)
        if myHero.pos:DistanceTo(target.pos) <= 1100 and self.Menu.Combo.UseE:Value() and _G.L9Engine:Ready(_E) then
            Control.CastSpell(HK_E, target.pos)
        end
        
        -- R Logic (Whirling Death)
        if myHero.pos:DistanceTo(target.pos) <= 20000 and self.Menu.Combo.UseR:Value() and _G.L9Engine:Ready(_R) then
            Control.CastSpell(HK_R, target.pos)
        end
        
        -- Auto Attack
        if myHero.pos:DistanceTo(target.pos) <= 550 and _G.SDK and _G.SDK.Orbwalker:CanAttack() then
            Control.Attack(target)
        end
    end
end

function L9LeagueOfDraven:Harass()
    local target = _G.L9Engine:GetTarget(1000)
    if target == nil then return end
    
    if _G.L9Engine:IsValidTarget(target) and myHero.mana/myHero.maxMana >= self.Menu.Harass.Mana:Value() / 100 then
        
        -- Q Logic (Spinning Axe)
        if myHero.pos:DistanceTo(target.pos) <= 550 and self.Menu.Harass.UseQ:Value() and _G.L9Engine:Ready(_Q) then
            Control.CastSpell(HK_Q)
        end
        
        -- W Logic (Blood Rush)
        if myHero.pos:DistanceTo(target.pos) <= 400 and self.Menu.Harass.UseW:Value() and _G.L9Engine:Ready(_W) then
            Control.CastSpell(HK_W)
        end
    end
end

function L9LeagueOfDraven:LaneClear()
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        
        if myHero.pos:DistanceTo(minion.pos) <= 550 and minion.team == TEAM_ENEMY and _G.L9Engine:IsValidTarget(minion) and myHero.mana/myHero.maxMana >= self.Menu.Clear.Mana:Value() / 100 then
            
            -- Q Logic (Spinning Axe)
            if myHero.pos:DistanceTo(minion.pos) <= 550 and _G.L9Engine:Ready(_Q) and self.Menu.Clear.UseQ:Value() then
                Control.CastSpell(HK_Q)
                break
            end
            
            -- W Logic (Blood Rush)
            if myHero.pos:DistanceTo(minion.pos) <= 400 and _G.L9Engine:Ready(_W) and self.Menu.Clear.UseW:Value() then
                Control.CastSpell(HK_W)
                break
            end
        end
    end
end

function L9LeagueOfDraven:AntiGapclose()
    if not self.Menu.AntiGapclose.UseE:Value() or not _G.L9Engine:Ready(_E) then return end
    
    local range = self.Menu.AntiGapclose.Range:Value()
    
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero.isEnemy and _G.L9Engine:IsValidTarget(hero, range) then
            local distance = _G.L9Engine:GetDistance(myHero.pos, hero.pos)
            if distance <= range then
                -- Cast E to push enemy away
                Control.CastSpell(HK_E, hero.pos)
                break
            end
        end
    end
end

function L9LeagueOfDraven:Draw()
    if myHero.dead then return end
    
    local textPos = myHero.pos:To2D()
    
    if self.Menu.Drawing.DrawQ:Value() and _G.L9Engine:Ready(_Q) then
        Draw.Circle(myHero.pos, 550, 1, Draw.Color(255, 255, 0, 0))
    end
    
    if self.Menu.Drawing.DrawW:Value() and _G.L9Engine:Ready(_W) then
        Draw.Circle(myHero.pos, 400, 1, Draw.Color(255, 0, 255, 0))
    end
    
    if self.Menu.Drawing.DrawE:Value() and _G.L9Engine:Ready(_E) then
        Draw.Circle(myHero.pos, 1100, 1, Draw.Color(255, 0, 0, 255))
    end
    
    if self.Menu.Drawing.DrawR:Value() and _G.L9Engine:Ready(_R) then
        Draw.Circle(myHero.pos, 20000, 1, Draw.Color(255, 255, 255, 0))
    end
end

L9LeagueOfDraven()
