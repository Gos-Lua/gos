local Version = 1.0
local Name = "L9Rengar"

if myHero.charName ~= "Rengar" then return end
if _G.L9RengarLoaded then return end
_G.L9RengarLoaded = true

class "L9Rengar"

function L9Rengar:__init()
	self.Q = {range = 0, damage = 0}
	self.W = {range = 0, heal = 0}
	self.E = {range = 1000, speed = 1500, delay = 0.25, radius = 70}
	self.R = {range = 0, duration = 0}
	
	self.JumpRange = 600
	self.Ferocity = 0
	self.LastFerocity = 0
	self.JumpTarget = nil
	self.JumpStartTime = 0
	
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

function L9Rengar:CheckPredictionSystem()
	if not self.PredictionLoaded or not _G.DepressivePrediction then return false end
	if not _G.DepressivePrediction.GetPrediction then return false end
	return true
end

function L9Rengar:Ready(slot)
	return _G.L9Engine:IsSpellReady(slot)
end

function L9Rengar:IsValid(unit)
	return _G.L9Engine:IsValidEnemy(unit)
end

function L9Rengar:Distance(a, b)
	return _G.L9Engine:CalculateDistance(a, b)
end

function L9Rengar:GetManaPct()
	return (myHero.mana / myHero.maxMana) * 100
end

function L9Rengar:SelectTarget(range)
	return _G.L9Engine:GetBestTarget(range)
end

function L9Rengar:GetFerocity()
	local ferocity = 0
	for i = 0, myHero.buffCount - 1 do
		local buff = myHero:GetBuff(i)
		if buff and buff.valid and buff.name:lower():find("rengarferocity") then
			ferocity = buff.count or 0
			break
		end
	end
	return ferocity
end

function L9Rengar:IsInBush()
	for i = 0, myHero.buffCount - 1 do
		local buff = myHero:GetBuff(i)
		if buff and buff.valid and buff.name:lower():find("brush") then
			return true
		end
	end
	return false
end

function L9Rengar:CanJump(target)
	if not target then return false end
	local distance = self:Distance(myHero.pos, target.pos)
	return distance <= self.JumpRange and self:IsInBush()
end

function L9Rengar:IsStunned()
	local buffData = _G.L9Engine:GetUnitBuff(myHero, 5)
	return buffData ~= nil
end

function L9Rengar:IsTargetFleeing(target)
	if not target then return false end
	local myPos = myHero.pos
	local targetPos = target.pos
	local targetDirection = (targetPos - myPos):Normalized()
	local targetMovement = target.pos - target.pos
	return targetMovement:Dot(targetDirection) > 0
end

function L9Rengar:GetQDamage(target)
	if not target then return 0 end
	local level = myHero:GetSpellData(_Q).level
	if level == 0 then return 0 end
	
	local baseDamage = {25, 45, 65, 85, 105}
	local adRatio = 0.95
	local damage = baseDamage[level] + (myHero.totalDamage * adRatio)
	
	if self:GetFerocity() >= 4 then
		damage = damage * 1.5
	end
	
	return damage
end

function L9Rengar:GetWDamage(target)
	if not target then return 0 end
	local level = myHero:GetSpellData(_W).level
	if level == 0 then return 0 end
	
	local baseDamage = {50, 80, 110, 140, 170}
	local apRatio = 0.8
	return baseDamage[level] + (myHero.ap * apRatio)
end

function L9Rengar:GetWHeal()
	local level = myHero:GetSpellData(_W).level
	if level == 0 then return 0 end
	
	local baseHeal = {20, 30, 40, 50, 60}
	local apRatio = 0.5
	local heal = baseHeal[level] + (myHero.ap * apRatio)
	
	if self:GetFerocity() >= 4 then
		heal = heal * 2
	end
	
	return heal
end

function L9Rengar:GetEDamage(target)
	if not target then return 0 end
	local level = myHero:GetSpellData(_E).level
	if level == 0 then return 0 end
	
	local baseDamage = {50, 100, 150, 200, 250}
	local adRatio = 0.7
	return baseDamage[level] + (myHero.totalDamage * adRatio)
end

function L9Rengar:PredictCastPos(target, which)
	if not target or not target.valid then return nil, 0 end
	if self:CheckPredictionSystem() then
		local s = {range = self.E.range, speed = self.E.speed, delay = self.E.delay, radius = self.E.radius}
		local src2D = {x = myHero.pos.x, z = myHero.pos.z}
		local _, castPos, _ = _G.DepressivePrediction.GetPrediction(target, src2D, s.speed, s.delay, s.radius)
		if castPos and castPos.x and castPos.z then
			return {x = castPos.x, z = castPos.z}, 4
		end
	end
	return {x = target.pos.x, z = target.pos.z}, 2
end

function L9Rengar:LoadMenu()
	self.Menu = MenuElement({type = _G.MENU, id = Name, name = "L9 Rengar"})
	self.Menu:MenuElement({name = " ", drop = {"Version " .. tostring(Version)}})

	self.Menu:MenuElement({type = _G.MENU, id = "combo", name = "Combo"})
	self.Menu.combo:MenuElement({id = "useQ", name = "Use Q", value = true})
	self.Menu.combo:MenuElement({id = "useW", name = "Use W", value = true})
	self.Menu.combo:MenuElement({id = "useE", name = "Use E", value = true})
	self.Menu.combo:MenuElement({id = "useR", name = "Use R", value = true})
	self.Menu.combo:MenuElement({id = "minHC", name = "Min Hitchance", value = 2, min = 1, max = 6, step = 1})

	self.Menu:MenuElement({type = _G.MENU, id = "harass", name = "Harass"})
	self.Menu.harass:MenuElement({id = "useQ", name = "Use Q", value = true})
	self.Menu.harass:MenuElement({id = "useE", name = "Use E", value = true})
	self.Menu.harass:MenuElement({id = "mana", name = "Min Mana%", value = 25, min = 0, max = 100, identifier = "%"})

	self.Menu:MenuElement({type = _G.MENU, id = "passive", name = "Passive Logic"})
	self.Menu.passive:MenuElement({id = "useQPassive", name = "Q Passive (One Shot)", value = true})
	self.Menu.passive:MenuElement({id = "useWPassive", name = "W Passive (Stun)", value = true})
	self.Menu.passive:MenuElement({id = "useEPassive", name = "E Passive (Fleeing)", value = true})
	self.Menu.passive:MenuElement({id = "qHp", name = "Q Passive HP%", value = 30, min = 10, max = 50, step = 5})

	self.Menu:MenuElement({type = _G.MENU, id = "misc", name = "Misc"})
	self.Menu.misc:MenuElement({id = "autoJump", name = "Auto Jump", value = true})
	self.Menu.misc:MenuElement({id = "autoW", name = "Auto W (Stun)", value = true})
	self.Menu.misc:MenuElement({id = "resetAA", name = "Reset AA with Q", value = true})

	self.Menu:MenuElement({type = _G.MENU, id = "draw", name = "Drawing"})
	self.Menu.draw:MenuElement({id = "q", name = "Draw Q", value = true})
	self.Menu.draw:MenuElement({id = "e", name = "Draw E", value = true})
	self.Menu.draw:MenuElement({id = "jump", name = "Draw Jump Range", value = true})
	self.Menu.draw:MenuElement({id = "ferocity", name = "Draw Ferocity", value = true})
end

function L9Rengar:BuildKeyMap()
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

function L9Rengar:keyInList(code, list)
	for i=1,#list do if code == list[i] then return true end end
	return false
end

function L9Rengar:OnWndMsg(msg, wParam)
	if msg == KEY_DOWN then
		if self:keyInList(wParam, self.keyMap.combo) then self.keys.space = true end
		if self:keyInList(wParam, self.keyMap.harass) then self.keys.c = true end
		if self.keyMap.abilities and self:keyInList(wParam, self.keyMap.abilities.q) then
			local t = self:SelectTarget(650)
			if t then self:TryCastQ(t) end
		end
		if self.keyMap.abilities and self:keyInList(wParam, self.keyMap.abilities.w) then
			local t = self:SelectTarget(500)
			if t then self:TryCastW(t) end
		end
	elseif msg == KEY_UP then
		if self:keyInList(wParam, self.keyMap.combo) then self.keys.space = false end
		if self:keyInList(wParam, self.keyMap.harass) then self.keys.c = false end
	end
end

function L9Rengar:TryCastQ(target)
	if not self:Ready(_Q) then return end
	if not target then return end
	
	if self:Distance(myHero.pos, target.pos) <= 150 then
		Control.CastSpell(HK_Q)
		if self.Menu.misc.resetAA:Value() then
			Control.Attack(target)
		end
	end
end

function L9Rengar:TryCastW(target)
	if not self:Ready(_W) then return end
	if not target then return end
	
	if self:Distance(myHero.pos, target.pos) <= 500 then
		Control.CastSpell(HK_W)
	end
end

function L9Rengar:TryCastE(target)
	if not self:Ready(_E) then return end
	if not target then return end
	
	if self:Distance(myHero.pos, target.pos) > self.E.range then return end
	
	local pos2D, hc = self:PredictCastPos(target, "E")
	if pos2D and hc >= self.Menu.combo.minHC:Value() then
		local castPos = Vector(pos2D.x, myHero.pos.y, pos2D.z)
		Control.CastSpell(HK_E, castPos)
	end
end

function L9Rengar:TryCastR(target)
	if not self:Ready(_R) then return end
	if not target then return end
	
	if self:Distance(myHero.pos, target.pos) <= 1000 then
		Control.CastSpell(HK_R)
	end
end

function L9Rengar:TryPassiveLogic(target)
	if not target then return end
	
	local ferocity = self:GetFerocity()
	if ferocity < 4 then return end
	
	local targetHp = (target.health / target.maxHealth) * 100
	
	if self.Menu.passive.useQPassive:Value() and targetHp <= self.Menu.passive.qHp:Value() then
		if self:GetQDamage(target) >= target.health then
			self:TryCastQ(target)
			return
		end
	end
	
	if self.Menu.passive.useWPassive:Value() and self:IsStunned() then
		self:TryCastW(target)
		return
	end
	
	if self.Menu.passive.useEPassive:Value() and self:IsTargetFleeing(target) then
		self:TryCastE(target)
		return
	end
	
	self:TryCastQ(target)
end

function L9Rengar:DoCombo()
	local target = self:SelectTarget(1000)
	if not target then return end
	
	if self:CanJump(target) and self.Menu.misc.autoJump:Value() then
		self.JumpTarget = target
		self.JumpStartTime = Game.Timer()
	end
	
	if self.Menu.combo.useE:Value() then self:TryCastE(target) end
	if self.Menu.combo.useW:Value() then self:TryCastW(target) end
	if self.Menu.combo.useQ:Value() then self:TryCastQ(target) end
	if self.Menu.combo.useR:Value() then self:TryCastR(target) end
	
	self:TryPassiveLogic(target)
end

function L9Rengar:DoHarass()
	if self:GetManaPct() < self.Menu.harass.mana:Value() then return end
	
	local target = self:SelectTarget(1000)
	if not target then return end
	
	if self.Menu.harass.useE:Value() then self:TryCastE(target) end
	if self.Menu.harass.useQ:Value() then self:TryCastQ(target) end
end

function L9Rengar:Tick()
	if myHero.dead or Game.IsChatOpen() then return end
	
	self.Ferocity = self:GetFerocity()
	
	if self.Menu.misc.autoW:Value() and self:IsStunned() then
		local target = self:SelectTarget(500)
		if target then self:TryCastW(target) end
	end
	
	local currentMode = _G.L9Engine:GetCurrentMode()
	
	if self.keys.space or currentMode == "Combo" then self:DoCombo() end
	if self.keys.c or currentMode == "Harass" then self:DoHarass() end
end

function L9Rengar:Draw()
	if myHero.dead then return end
	
	local ferocity = self:GetFerocity()
	local ferocityColor = Draw.Color(150, 255, 255, 255)
	if ferocity >= 4 then
		ferocityColor = Draw.Color(150, 255, 100, 100)
	end
	
	if self.Menu.draw.q:Value() and self:Ready(_Q) then
		Draw.Circle(myHero.pos, 150, 1, ferocityColor)
	end
	if self.Menu.draw.e:Value() and self:Ready(_E) then
		Draw.Circle(myHero.pos, self.E.range, 1, Draw.Color(150, 100, 255, 100))
	end
	if self.Menu.draw.jump:Value() and self:IsInBush() then
		Draw.Circle(myHero.pos, self.JumpRange, 1, Draw.Color(150, 255, 255, 100))
	end
	if self.Menu.draw.ferocity:Value() then
		local ferocityText = "Ferocity: " .. ferocity .. "/4"
		if Draw.Text then
			Draw.Text(ferocityText, 14, 40, 400, ferocityColor)
		end
	end
end

L9Rengar()
