local Version = 1.0
local Name = "L9Kayn"

if myHero.charName ~= "Kayn" then return end
if _G.L9KaynLoaded then return end
_G.L9KaynLoaded = true

class "L9Kayn"

function L9Kayn:__init()
	self.Q = {range = 500, pred = {delay = 0.55, radius = 50, range = 350, speed = math.huge}}
	self.W_RED = {delay = 0.55, radius = 45, range = 700, speed = math.huge}
	self.W_BLUE = {delay = 0.0, radius = 45, range = 900, speed = math.huge}
	self.E = {range = 0, duration = 1.5}
	self.R = {range = 550, damage = 0}
	
	local ok, err = pcall(function() require("DepressivePrediction") end)
	self.PredictionLoaded = false
	DelayAction(function()
		if ok and _G.DepressivePrediction then
			self.PredictionLoaded = true
		end
	end, 0.7)

	self:LoadMenu()
	self:BuildKeyMap()
	
	Callback.Add("Tick", function() self:Tick() end)
	Callback.Add("Draw", function() self:Draw() end)
	Callback.Add("WndMsg", function(msg, wParam) self:OnWndMsg(msg, wParam) end)
end

function L9Kayn:CheckPredictionSystem()
	if not self.PredictionLoaded or not _G.DepressivePrediction then return false end
	if not _G.DepressivePrediction.GetPrediction then return false end
	return true
end

function L9Kayn:Ready(slot)
	return _G.L9Engine:IsSpellReady(slot)
end

function L9Kayn:IsValid(unit)
	return _G.L9Engine:IsValidEnemy(unit)
end

function L9Kayn:Distance(a, b)
	return _G.L9Engine:CalculateDistance(a, b)
end

function L9Kayn:GetManaPct()
	return (myHero.mana / myHero.maxMana) * 100
end

function L9Kayn:IsRedForm()
	local w = myHero:GetSpellData(_W)
	return w and w.range == 700
end

function L9Kayn:IsBlueForm()
	local w = myHero:GetSpellData(_W)
	return w and w.range == 900
end

function L9Kayn:SelectTarget(range)
	return _G.L9Engine:GetBestTarget(range)
end

function L9Kayn:PredictCastPos(target, which)
	if not target or not target.valid then return nil, 0 end
	if self:CheckPredictionSystem() then
		local s = {}
		if which == "Q" then
			s = {range = self.Q.pred.range, speed = self.Q.pred.speed, delay = self.Q.pred.delay, radius = self.Q.pred.radius}
		else
			local W = self:IsBlueForm() and self.W_BLUE or self.W_RED
			s = {range = W.range, speed = W.speed, delay = W.delay, radius = W.radius}
		end
		local src2D = {x = myHero.pos.x, z = myHero.pos.z}
		local _, castPos, _ = _G.DepressivePrediction.GetPrediction(target, src2D, s.speed, s.delay, s.radius)
		if castPos and castPos.x and castPos.z then
			return {x = castPos.x, z = castPos.z}, 4
		end
	end
	return {x = target.pos.x, z = target.pos.z}, 2
end

function L9Kayn:HasSlowBuff()
	local buffData = _G.L9Engine:GetUnitBuff(myHero, 10)
	return buffData ~= nil
end

function L9Kayn:GetProfileType()
	return self.Menu.profile.type:Value()
end

function L9Kayn:IsClassicProfile()
	return self:GetProfileType() == 1
end

function L9Kayn:IsBlueProfile()
	return self:GetProfileType() == 2
end

function L9Kayn:IsRedProfile()
	return self:GetProfileType() == 3
end

function L9Kayn:GetRDamage(target)
	if not target then return 0 end
	local level = myHero:GetSpellData(_R).level
	if level == 0 then return 0 end
	
	local baseDamage = {150, 250, 350}
	local adRatio = 1.75
	
	if self:IsBlueProfile() then
		adRatio = 2.0
	elseif self:IsRedProfile() then
		adRatio = 1.5
	end
	
	local damage = baseDamage[level] + (myHero.totalDamage * adRatio)
	return damage
end

function L9Kayn:GetRHealAmount()
	if self:IsRedProfile() then
		local level = myHero:GetSpellData(_R).level
		if level == 0 then return 0 end
		local baseHeal = {100, 150, 200}
		local apRatio = 0.8
		return baseHeal[level] + (myHero.ap * apRatio)
	end
	return 0
end

function L9Kayn:LoadMenu()
	self.Menu = MenuElement({type = _G.MENU, id = Name, name = "L9 Kayn"})
	self.Menu:MenuElement({name = " ", drop = {"Version " .. tostring(Version)}})

	self.Menu:MenuElement({type = _G.MENU, id = "profile", name = "Profile"})
	self.Menu.profile:MenuElement({id = "type", name = "Profile Type", value = 1, drop = {"Classic", "Blue", "Red"}})
	self.Menu.profile:MenuElement({id = "info", name = "Classic: Normal spells", type = _G.SPACE})
	self.Menu.profile:MenuElement({id = "info2", name = "Blue: W damage + mobile W + R damage", type = _G.SPACE})
	self.Menu.profile:MenuElement({id = "info3", name = "Red: Q damage + W bump + R heal", type = _G.SPACE})

	self.Menu:MenuElement({type = _G.MENU, id = "combo", name = "Combo"})
	self.Menu.combo:MenuElement({id = "useQ", name = "Use Q", value = true})
	self.Menu.combo:MenuElement({id = "useW", name = "Use W", value = true})
	self.Menu.combo:MenuElement({id = "useR", name = "Use R Finisher", value = true})
	self.Menu.combo:MenuElement({id = "rHp", name = "R Finisher HP%", value = 25, min = 10, max = 50, step = 5})
	self.Menu.combo:MenuElement({id = "minHC", name = "Min Hitchance", value = 2, min = 1, max = 6, step = 1})

	self.Menu:MenuElement({type = _G.MENU, id = "harass", name = "Harass"})
	self.Menu.harass:MenuElement({id = "useQ", name = "Use Q", value = true})
	self.Menu.harass:MenuElement({id = "useW", name = "Use W", value = true})
	self.Menu.harass:MenuElement({id = "mana", name = "Min Mana%", value = 25, min = 0, max = 100, identifier = "%"})

	self.Menu:MenuElement({type = _G.MENU, id = "misc", name = "Misc"})
	self.Menu.misc:MenuElement({id = "useE", name = "Use E Anti-Slow", value = true})
	self.Menu.misc:MenuElement({id = "useRLife", name = "Use R Life Saver", value = true})
	self.Menu.misc:MenuElement({id = "rLifeHp", name = "R Life Saver HP%", value = 15, min = 5, max = 30, step = 5})

	self.Menu:MenuElement({type = _G.MENU, id = "draw", name = "Drawing"})
	self.Menu.draw:MenuElement({id = "q", name = "Draw Q", value = true})
	self.Menu.draw:MenuElement({id = "w", name = "Draw W", value = true})
	self.Menu.draw:MenuElement({id = "r", name = "Draw R", value = true})
end

function L9Kayn:BuildKeyMap()
	local VK = {SPACE=32, C=67, Q=81, W=87, A=65, Z=90}
	self.keyMap = {
		combo={VK.SPACE},
		harass={VK.C},
		abilities={
			q={VK.Q, VK.A},
			w={VK.W, VK.Z}
		}
	}
	self.keys = {space=false, c=false}
end

function L9Kayn:keyInList(code, list)
	for i=1,#list do if code == list[i] then return true end end
	return false
end

function L9Kayn:OnWndMsg(msg, wParam)
	if msg == KEY_DOWN then
		if self:keyInList(wParam, self.keyMap.combo) then self.keys.space = true end
		if self:keyInList(wParam, self.keyMap.harass) then self.keys.c = true end
		if self.keyMap.abilities and self:keyInList(wParam, self.keyMap.abilities.q) then
			local t = self:SelectTarget(650)
			if t then self:TryCastQ(t) end
		end
		if self.keyMap.abilities and self:keyInList(wParam, self.keyMap.abilities.w) then
			local range = (self:IsBlueForm() and self.W_BLUE.range or self.W_RED.range)
			local t = self:SelectTarget(range)
			if t then self:TryCastW(t) end
		end
	elseif msg == KEY_UP then
		if self:keyInList(wParam, self.keyMap.combo) then self.keys.space = false end
		if self:keyInList(wParam, self.keyMap.harass) then self.keys.c = false end
	end
end

function L9Kayn:TryCastQ(target)
	if not self:Ready(_Q) then return end
	if self:Distance(myHero.pos, target.pos) > self.Q.range then return end
	local pos2D, hc = self:PredictCastPos(target, "Q")
	if pos2D and hc >= self.Menu.combo.minHC:Value() then
		local castPos = Vector(pos2D.x, myHero.pos.y, pos2D.z)
		Control.CastSpell(HK_Q, castPos)
	end
end

function L9Kayn:TryCastW(target)
	if not self:Ready(_W) then return end
	local W = self:IsBlueForm() and self.W_BLUE or self.W_RED
	if self:Distance(myHero.pos, target.pos) > (W.range - 10) then return end
	local pos2D, hc = self:PredictCastPos(target, "W")
	if pos2D and hc >= self.Menu.combo.minHC:Value() then
		local castPos = Vector(pos2D.x, myHero.pos.y, pos2D.z)
		Control.CastSpell(HK_W, castPos)
	end
end

function L9Kayn:TryCastE()
	if not self:Ready(_E) then return end
	if not self.Menu.misc.useE:Value() then return end
	if self:HasSlowBuff() then
		Control.CastSpell(HK_E)
	end
end

function L9Kayn:TryCastRFinisher(target)
	if not self:Ready(_R) then return end
	if not self.Menu.combo.useR:Value() then return end
	if not target then return end
	if self:Distance(myHero.pos, target.pos) > self.R.range then return end
	
	local targetHp = (target.health / target.maxHealth) * 100
	if targetHp > self.Menu.combo.rHp:Value() then return end
	
	local rDamage = self:GetRDamage(target)
	if target.health <= rDamage then
		Control.CastSpell(HK_R, target)
	end
end

function L9Kayn:TryCastRLifeSaver()
	if not self:Ready(_R) then return end
	if not self.Menu.misc.useRLife:Value() then return end
	
	local myHp = (myHero.health / myHero.maxHealth) * 100
	if myHp > self.Menu.misc.rLifeHp:Value() then return end
	
	if self:IsRedProfile() then
		local healAmount = self:GetRHealAmount()
		local missingHealth = myHero.maxHealth - myHero.health
		if healAmount >= missingHealth * 0.3 then
			local bestTarget = nil
			local bestDistance = math.huge
			
			for i = 1, Game.HeroCount() do
				local enemy = Game.Hero(i)
				if enemy and enemy.team ~= myHero.team and self:IsValid(enemy) then
					local distance = self:Distance(myHero.pos, enemy.pos)
					if distance <= self.R.range and distance < bestDistance then
						bestTarget = enemy
						bestDistance = distance
					end
				end
			end
			
			if bestTarget then
				Control.CastSpell(HK_R, bestTarget)
			end
		end
	else
		local bestTarget = nil
		local bestDistance = math.huge
		
		for i = 1, Game.HeroCount() do
			local enemy = Game.Hero(i)
			if enemy and enemy.team ~= myHero.team and self:IsValid(enemy) then
				local distance = self:Distance(myHero.pos, enemy.pos)
				if distance <= self.R.range and distance < bestDistance then
					bestTarget = enemy
					bestDistance = distance
				end
			end
		end
		
		if bestTarget then
			Control.CastSpell(HK_R, bestTarget)
		end
	end
end

function L9Kayn:DoCombo()
	local range = (self:IsBlueForm() and self.W_BLUE.range or self.W_RED.range)
	local target = self:SelectTarget(math.max(900, range))
	if not target then return end
	
	if self:IsClassicProfile() then
		if self.Menu.combo.useW:Value() then self:TryCastW(target) end
		if self.Menu.combo.useQ:Value() then self:TryCastQ(target) end
	elseif self:IsBlueProfile() then
		if self.Menu.combo.useW:Value() then self:TryCastW(target) end
		if self.Menu.combo.useQ:Value() then self:TryCastQ(target) end
	elseif self:IsRedProfile() then
		if self.Menu.combo.useQ:Value() then self:TryCastQ(target) end
		if self.Menu.combo.useW:Value() then self:TryCastW(target) end
	end
	
	if self.Menu.combo.useR:Value() then self:TryCastRFinisher(target) end
end

function L9Kayn:DoHarass()
	if self:GetManaPct() < self.Menu.harass.mana:Value() then return end
	local range = (self:IsBlueForm() and self.W_BLUE.range or self.W_RED.range)
	local target = self:SelectTarget(math.max(900, range))
	if not target then return end
	
	if self.Menu.harass.useW:Value() then self:TryCastW(target) end
	if self.Menu.harass.useQ:Value() then self:TryCastQ(target) end
end

function L9Kayn:Tick()
	if myHero.dead or Game.IsChatOpen() then return end
	
	self:TryCastE()
	self:TryCastRLifeSaver()
	
	local currentMode = _G.L9Engine:GetCurrentMode()
	
	if self.keys.space or currentMode == "Combo" then self:DoCombo() end
	if self.keys.c or currentMode == "Harass" then self:DoHarass() end
end

function L9Kayn:Draw()
	if myHero.dead then return end
	
	local profileColor = Draw.Color(150, 255, 255, 255)
	if self:IsBlueProfile() then
		profileColor = Draw.Color(150, 100, 150, 255)
	elseif self:IsRedProfile() then
		profileColor = Draw.Color(150, 255, 100, 100)
	end
	
	if self.Menu.draw.q:Value() and self:Ready(_Q) then
		Draw.Circle(myHero.pos, 500, 1, profileColor)
	end
	if self.Menu.draw.w:Value() and self:Ready(_W) then
		local r = (self:IsBlueForm() and self.W_BLUE.range or self.W_RED.range)
		Draw.Circle(myHero.pos, r, 1, profileColor)
	end
	if self.Menu.draw.r:Value() and self:Ready(_R) then
		Draw.Circle(myHero.pos, self.R.range, 1, profileColor)
	end
	
	local profileText = "Classic"
	if self:IsBlueProfile() then
		profileText = "Blue"
	elseif self:IsRedProfile() then
		profileText = "Red"
	end
	
	if Draw.Text then
		Draw.Text("Profile: " .. profileText, 14, 40, 380, profileColor)
	end
end

L9Kayn()
