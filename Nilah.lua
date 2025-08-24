local Version = 1.0
local Name = "L9Nilah"

if myHero.charName ~= "Nilah" then return end
if _G.L9NilahLoaded then return end
_G.L9NilahLoaded = true

class "L9Nilah"

-- Configuration des sorts
local Q = { range = 600, width = 100, speed = 2000, delay = 0.25 }
local W = { range = 0, width = 0, speed = math.huge, delay = 0 }
local E = { range = 550, width = 0, speed = math.huge, delay = 0 }
local R = { range = 600, width = 400, speed = math.huge, delay = 0.5 }

-- Variables locales
local lastQTime = 0
local lastWTime = 0
local lastETime = 0
local lastRTime = 0
local passiveStacks = 0

function L9Nilah:__init()
    self:LoadSpells()
    self:CreateMenu()
    
    Callback.Add("Tick", function() self:Tick() end)
    Callback.Add("Draw", function() self:Draw() end)
    
    print("[L9Nilah] Script chargé !")
end

function L9Nilah:CreateMenu()
    self.Menu = MenuElement({type = MENU, id = "L9Nilah", name = "L9 Nilah", leftIcon = "https://raw.githubusercontent.com/LeagueSharp/LeagueSharp/master/LeagueSharp.SDK/Resources/Nilah.png"})
    
    -- Menu Combo
    self.Menu:MenuElement({type = MENU, id = "combo", name = "Combo"})
    self.Menu.combo:MenuElement({id = "useQ", name = "Utiliser Q", value = true})
    self.Menu.combo:MenuElement({id = "useW", name = "Utiliser W (dash)", value = true})
    self.Menu.combo:MenuElement({id = "useE", name = "Utiliser E (dash)", value = true})
    self.Menu.combo:MenuElement({id = "useR", name = "Utiliser R", value = true})
    self.Menu.combo:MenuElement({id = "minEnemiesR", name = "Ennemis minimum pour R", value = 2, min = 1, max = 5})
    self.Menu.combo:MenuElement({id = "useRHP", name = "Utiliser R si ennemi HP < %", value = 50, min = 10, max = 100})
    
    -- Menu Harass
    self.Menu:MenuElement({type = MENU, id = "harass", name = "Harass"})
    self.Menu.harass:MenuElement({id = "useQ", name = "Utiliser Q", value = true})
    self.Menu.harass:MenuElement({id = "useW", name = "Utiliser W", value = false})
    self.Menu.harass:MenuElement({id = "manaHarass", name = "Mana minimum %", value = 40, min = 0, max = 100})
    
    -- Menu Farm
    self.Menu:MenuElement({type = MENU, id = "farm", name = "Farm"})
    self.Menu.farm:MenuElement({id = "useQ", name = "Utiliser Q", value = true})
    self.Menu.farm:MenuElement({id = "useW", name = "Utiliser W", value = false})
    self.Menu.farm:MenuElement({id = "manaFarm", name = "Mana minimum %", value = 30, min = 0, max = 100})
    
    -- Menu Clear
    self.Menu:MenuElement({type = MENU, id = "clear", name = "Clear"})
    self.Menu.clear:MenuElement({id = "useQ", name = "Utiliser Q", value = true})
    self.Menu.clear:MenuElement({id = "useW", name = "Utiliser W", value = true})
    self.Menu.clear:MenuElement({id = "useE", name = "Utiliser E", value = false})
    self.Menu.clear:MenuElement({id = "minMinions", name = "Minions minimum pour W", value = 3, min = 1, max = 10})
    self.Menu.clear:MenuElement({id = "manaClear", name = "Mana minimum %", value = 20, min = 0, max = 100})
    
    -- Menu Misc
    self.Menu:MenuElement({type = MENU, id = "misc", name = "Misc"})
    self.Menu.misc:MenuElement({id = "autoW", name = "Auto W (dash) si ennemi proche", value = true})
    self.Menu.misc:MenuElement({id = "autoE", name = "Auto E pour échapper", value = true})
    self.Menu.misc:MenuElement({id = "autoR", name = "Auto R si plusieurs ennemis", value = true})
    self.Menu.misc:MenuElement({id = "autoRCount", name = "Ennemis pour auto R", value = 3, min = 2, max = 5})
    
    -- Menu Draw
    self.Menu:MenuElement({type = MENU, id = "draw", name = "Draw"})
    self.Menu.draw:MenuElement({id = "drawQ", name = "Dessiner Q range", value = true})
    self.Menu.draw:MenuElement({id = "drawE", name = "Dessiner E range", value = true})
    self.Menu.draw:MenuElement({id = "drawR", name = "Dessiner R range", value = true})
    self.Menu.draw:MenuElement({id = "drawPassive", name = "Afficher stacks passif", value = true})
end

function L9Nilah:LoadSpells()
    self.Q = {Slot = 0, Range = Q.range, Width = Q.width, Speed = Q.speed, Delay = Q.delay}
    self.W = {Slot = 1, Range = W.range, Width = W.width, Speed = W.speed, Delay = W.delay}
    self.E = {Slot = 2, Range = E.range, Width = E.width, Speed = E.speed, Delay = E.delay}
    self.R = {Slot = 3, Range = R.range, Width = R.width, Speed = R.speed, Delay = R.delay}
end

function L9Nilah:Tick()
    if myHero.dead then return end
    
    local mode = _G.L9Engine:GetCurrentMode()
    
    if mode == "Combo" then
        self:DoCombo()
    elseif mode == "Harass" then
        self:DoHarass()
    elseif mode == "Clear" then
        self:DoClear()
    elseif mode == "LastHit" then
        self:DoLastHit()
    end
    
    self:DoMisc()
    self:UpdatePassiveStacks()
end

function L9Nilah:DoCombo()
    local target = _G.L9Engine:GetBestTarget(self.R.Range)
    if not target then return end
    
    -- Utiliser R si plusieurs ennemis
    if self.Menu.combo.useR:Value() and _G.L9Engine:IsSpellReady(_SPELL3) then
        local enemies = self:GetEnemiesInRange(myHero.pos, self.R.Range)
        if #enemies >= self.Menu.combo.minEnemiesR:Value() then
            self:TryCastR(target)
        end
    end
    
    -- Utiliser E pour gap close
    if self.Menu.combo.useE:Value() and _G.L9Engine:IsSpellReady(_SPELL2) then
        if _G.L9Engine:CalculateDistance(myHero.pos, target.pos) > self.Q.Range and _G.L9Engine:CalculateDistance(myHero.pos, target.pos) < self.E.Range * 2 then
            self:TryCastE(target)
        end
    end
    
    -- Utiliser Q
    if self.Menu.combo.useQ:Value() and _G.L9Engine:IsSpellReady(_SPELL0) then
        self:TryCastQ(target)
    end
    
    -- Utiliser W pour dash ou buff
    if self.Menu.combo.useW:Value() and _G.L9Engine:IsSpellReady(_SPELL1) then
        if _G.L9Engine:CalculateDistance(myHero.pos, target.pos) > self.Q.Range then
            self:TryCastW(target)
        end
    end
end

function L9Nilah:DoHarass()
    if myHero.mana / myHero.maxMana * 100 < self.Menu.harass.manaHarass:Value() then return end
    
    local target = _G.L9Engine:GetBestTarget(self.Q.Range)
    if not target then return end
    
    if self.Menu.harass.useQ:Value() and _G.L9Engine:IsSpellReady(_SPELL0) then
        self:TryCastQ(target)
    end
    
    if self.Menu.harass.useW:Value() and _G.L9Engine:IsSpellReady(_SPELL1) then
        self:TryCastW(target)
    end
end

function L9Nilah:DoClear()
    if myHero.mana / myHero.maxMana * 100 < self.Menu.clear.manaClear:Value() then return end
    
    local minions = self:GetMinionsInRange(myHero.pos, self.Q.Range)
    
    if self.Menu.clear.useQ:Value() and _G.L9Engine:IsSpellReady(_SPELL0) and #minions > 0 then
        self:TryCastQClear(minions)
    end
    
    if self.Menu.clear.useW:Value() and _G.L9Engine:IsSpellReady(_SPELL1) and #minions >= self.Menu.clear.minMinions:Value() then
        self:TryCastWClear(minions)
    end
    
    if self.Menu.clear.useE:Value() and _G.L9Engine:IsSpellReady(_SPELL2) then
        self:TryCastEClear(minions)
    end
end

function L9Nilah:DoLastHit()
    local minions = self:GetMinionsInRange(myHero.pos, self.Q.Range)
    
    for _, minion in pairs(minions) do
        if minion.health <= self:GetQDamage(minion) and _G.L9Engine:IsSpellReady(_SPELL0) then
            self:TryCastQ(minion)
            break
        end
    end
end

function L9Nilah:DoMisc()
    -- Auto W si alliés proches
    if self.Menu.misc.autoW:Value() and _G.L9Engine:IsSpellReady(_SPELL1) then
        local allies = self:GetAlliesInRange(600)
        if #allies > 0 then
            self:TryCastW()
        end
    end
    
    -- Auto E pour échapper
    if self.Menu.misc.autoE:Value() and _G.L9Engine:IsSpellReady(_SPELL2) then
        local nearbyEnemy = self:GetNearestEnemy(400)
        if nearbyEnemy and myHero.health / myHero.maxHealth < 0.3 then
            -- Dash vers un allié proche
            local allies = self:GetAlliesInRange(800)
            if #allies > 0 then
                Control.CastSpell(_G.L9Engine:GetKeybind("E"), allies[1])
            end
        end
    end
    
    -- Auto R si plusieurs ennemis
    if self.Menu.misc.autoR:Value() and _G.L9Engine:IsSpellReady(_SPELL3) then
        local enemies = self:GetEnemiesInRange(myHero.pos, self.R.Range)
        if #enemies >= self.Menu.misc.autoRCount:Value() then
            self:TryCastR(enemies[1])
        end
    end
end

function L9Nilah:TryCastQ(target)
    if not target or not _G.L9Engine:IsValidEnemy(target, self.Q.Range) then return false end
    
    Control.CastSpell(_G.L9Engine:GetKeybind("Q"), target.pos)
    return true
end

function L9Nilah:TryCastQClear(minions)
    if #minions == 0 then return false end
    
    -- Q sur le minion le plus proche
    local nearestMinion = nil
    local minDist = math.huge
    
    for _, minion in pairs(minions) do
        local dist = _G.L9Engine:CalculateDistance(myHero.pos, minion.pos)
        if dist < minDist then
            minDist = dist
            nearestMinion = minion
        end
    end
    
    if nearestMinion then
        Control.CastSpell(_G.L9Engine:GetKeybind("Q"), nearestMinion.pos)
        return true
    end
    return false
end

function L9Nilah:TryCastW(target)
    -- W buff d'équipe (pas de cible nécessaire)
    Control.CastSpell(_G.L9Engine:GetKeybind("W"))
    return true
end

function L9Nilah:TryCastWClear(minions)
    -- W buff d'équipe (pas de cible nécessaire)
    Control.CastSpell(_G.L9Engine:GetKeybind("W"))
    return true
end

function L9Nilah:TryCastE(target)
    if not target or not _G.L9Engine:IsValidEnemy(target, self.E.Range * 2) then return false end
    
    -- E dash vers la cible
    Control.CastSpell(_G.L9Engine:GetKeybind("E"), target)
    return true
end

function L9Nilah:TryCastEClear(minions)
    if #minions == 0 then return false end
    
    -- E dash vers le minion le plus proche
    local nearestMinion = nil
    local minDist = math.huge
    
    for _, minion in pairs(minions) do
        local dist = _G.L9Engine:CalculateDistance(myHero.pos, minion.pos)
        if dist < minDist then
            minDist = dist
            nearestMinion = minion
        end
    end
    
    if nearestMinion then
        Control.CastSpell(_G.L9Engine:GetKeybind("E"), nearestMinion)
        return true
    end
    return false
end

function L9Nilah:TryCastR(target)
    if not target or not _G.L9Engine:IsValidEnemy(target, self.R.Range) then return false end
    
    Control.CastSpell(_G.L9Engine:GetKeybind("R"), target.pos)
    return true
end

function L9Nilah:GetQPrediction(target)
    if _G.DepressivePrediction then
        return _G.DepressivePrediction.GetPrediction(target, self.Q.Range, self.Q.Speed, self.Q.Delay, self.Q.Width, myHero.pos, false)
    elseif _G.SDK then
        return _G.SDK.Prediction:GetPrediction(target, self.Q.Range, self.Q.Speed, self.Q.Delay, self.Q.Width, myHero.pos, false)
    end
    return nil
end

function L9Nilah:GetRPrediction(target)
    if _G.DepressivePrediction then
        return _G.DepressivePrediction.GetPrediction(target, self.R.Range, self.R.Speed, self.R.Delay, self.R.Width, myHero.pos, false)
    elseif _G.SDK then
        return _G.SDK.Prediction:GetPrediction(target, self.R.Range, self.R.Speed, self.R.Delay, self.R.Width, myHero.pos, false)
    end
    return nil
end

function L9Nilah:GetDashPosition(target)
    if not target then return nil end
    
    local targetPos = target.pos
    local myPos = myHero.pos
    local direction = (targetPos - myPos):Normalized()
    local dashDistance = 300 -- Distance de dash approximative
    
    local dashPos = myPos + direction * dashDistance
    
    -- Vérifier si la position est valide
    if self:IsValidPosition(dashPos) then
        return dashPos
    end
    
    return nil
end

function L9Nilah:GetEscapePosition()
    local myPos = myHero.pos
    local escapeDistance = 400
    
    -- Essayer plusieurs directions
    local directions = {
        Vector(myPos.x + escapeDistance, myPos.y, myPos.z),
        Vector(myPos.x - escapeDistance, myPos.y, myPos.z),
        Vector(myPos.x, myPos.y, myPos.z + escapeDistance),
        Vector(myPos.x, myPos.y, myPos.z - escapeDistance)
    }
    
    for _, pos in pairs(directions) do
        if self:IsValidPosition(pos) then
            return pos
        end
    end
    
    return nil
end

function L9Nilah:IsValidPosition(pos)
    if not pos then return false end
    
    -- Vérifier si la position est dans les limites de la map
    if pos.x < 0 or pos.x > 15000 or pos.z < 0 or pos.z > 15000 then
        return false
    end
    
    -- Vérifier s'il y a des obstacles
    if MapPosition:inWall(pos) then
        return false
    end
    
    return true
end

function L9Nilah:GetEnemiesInRange(pos, range)
    local enemies = {}
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if _G.L9Engine:IsValidEnemy(hero, range) and _G.L9Engine:CalculateDistance(pos, hero.pos) <= range then
            table.insert(enemies, hero)
        end
    end
    return enemies
end

function L9Nilah:GetMinionsInRange(pos, range)
    local minions = {}
    for i = 1, Game.MinionCount() do
        local minion = Game.Minion(i)
        if minion and minion.team ~= myHero.team and not minion.dead and _G.L9Engine:CalculateDistance(pos, minion.pos) <= range then
            table.insert(minions, minion)
        end
    end
    return minions
end

function L9Nilah:GetNearestEnemy(range)
    local nearest = nil
    local minDist = math.huge
    
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if _G.L9Engine:IsValidEnemy(hero, range) then
            local dist = _G.L9Engine:CalculateDistance(myHero.pos, hero.pos)
            if dist < minDist then
                minDist = dist
                nearest = hero
            end
        end
    end
    
    return nearest
end

function L9Nilah:GetAlliesInRange(range)
    local allies = {}
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero and hero.team == myHero.team and not hero.dead and hero.networkID ~= myHero.networkID then
            local dist = _G.L9Engine:CalculateDistance(myHero.pos, hero.pos)
            if dist <= range then
                table.insert(allies, hero)
            end
        end
    end
    return allies
end

function L9Nilah:GetMinionCenter(minions)
    if #minions == 0 then return nil end
    
    local centerX = 0
    local centerZ = 0
    
    for _, minion in pairs(minions) do
        centerX = centerX + minion.pos.x
        centerZ = centerZ + minion.pos.z
    end
    
    centerX = centerX / #minions
    centerZ = centerZ / #minions
    
    return Vector(centerX, myHero.pos.y, centerZ)
end

function L9Nilah:CountMinionsHit(pos, range, width)
    local count = 0
    local minions = self:GetMinionsInRange(pos, range)
    
    for _, minion in pairs(minions) do
        local dist = _G.L9Engine:CalculateDistance(pos, minion.pos)
        if dist <= width / 2 then
            count = count + 1
        end
    end
    
    return count
end

function L9Nilah:GetQDamage(target)
    if not target then return 0 end
    
    local level = myHero:GetSpellData(_SPELL0).level
    local baseDamage = 5 + (level - 1) * 15
    local adRatio = 0.9
    
    return baseDamage + (myHero.totalDamage * adRatio)
end

function L9Nilah:UpdatePassiveStacks()
    -- Mettre à jour les stacks du passif (Nilah gagne des stacks en attaquant)
    local passiveBuff = myHero:GetBuff("NilahPassive")
    if passiveBuff then
        passiveStacks = passiveBuff.count or 0
    else
        passiveStacks = 0
    end
end

function L9Nilah:Draw()
    if myHero.dead then return end
    
    local myPos = myHero.pos
    
    -- Dessiner Q range
    if self.Menu.draw.drawQ:Value() and _G.L9Engine:IsSpellReady(_SPELL0) then
        Draw.Circle(myPos, self.Q.Range, 1, Draw.Color(255, 255, 255, 255))
    end
    
    -- Dessiner E range
    if self.Menu.draw.drawE:Value() and _G.L9Engine:IsSpellReady(_SPELL2) then
        Draw.Circle(myPos, self.E.Range, 1, Draw.Color(255, 0, 255, 255))
    end
    
    -- Dessiner R range
    if self.Menu.draw.drawR:Value() and _G.L9Engine:IsSpellReady(_SPELL3) then
        Draw.Circle(myPos, self.R.Range, 1, Draw.Color(255, 255, 0, 255))
    end
    
    -- Afficher stacks passif
    if self.Menu.draw.drawPassive:Value() then
        local textPos = Renderer.WorldToScreen(myPos)
        if textPos then
            Draw.Text("Passif: " .. passiveStacks .. " stacks", 15, textPos.x - 30, textPos.y - 50, Draw.Color(255, 255, 255, 255))
        end
    end
end

L9Nilah()
