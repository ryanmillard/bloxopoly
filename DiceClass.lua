--// Services //
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DiceTemplate = ReplicatedStorage:WaitForChild("DiceTemplate")

--// Modules //
local ImageModule = require(ReplicatedStorage:WaitForChild("PublicModules"):WaitForChild("ImageModule"))
local GD = require(script.Parent.Parent:WaitForChild("GameData"))

local DiceFolder = game.Workspace:WaitForChild("Dice")

local Events = ReplicatedStorage:WaitForChild("Events")

local DICE_FACES = {
	Top = 6,
	Bottom = 1,
	Left = 4,
	Right = 3,
	Back = 5,
	Front = 2
}

local DICE_ANGLES = {
	Vector3.new(0, -90, 180),
	Vector3.new(90, 90, 0),
	Vector3.new(0, 0, 90),
	Vector3.new(0, 180, -90),
	Vector3.new(-90, 90, 0),
	Vector3.new(0, 0, 0)
}

local height = 18

local Dice = {}
Dice.__index = Dice

function Dice.new(playerNum:number, id:number, x:number, z:number)
	local instance = setmetatable({}, Dice)
	
	instance.XCoordinate = x
	instance.ZCoordinate = z
	instance.diceID = id

	instance.object = DiceTemplate:Clone()
	instance.object.Name = "Dice" .. id
	instance.object.Position = Vector3.new(x,45,z)
	instance.object.Parent = DiceFolder:WaitForChild(playerNum)
	
	instance.trailEnabled = false
	
	return instance
end

function Dice:setTrailEnabled(isEnabled)
	self.trailEnabled = isEnabled 
end

function Dice:setDiceColour(r,g,b)
	self.diceColour = {r,g,b}
	local colour = Color3.fromRGB(r,g,b)
	local h,s,v = colour:ToHSV()
	local darker = Color3.fromHSV(h,s,v*0.5)
	
	self.object.Color = colour
	self.object.Trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colour),
		ColorSequenceKeypoint.new(1, darker)
	})
end

function Dice:setDotColour(r,g,b)
	self.dotColour = {r,g,b}
	local colour = Color3.fromRGB(r,g,b)
	for _, child in pairs(self.object:GetDescendants()) do
		if child:IsA("ImageLabel") then
			child.ImageColor3 = colour
		end
	end
end

function Dice:setDotImage(imageID)
	for _, child in pairs(self.object:GetDescendants()) do
		if child:IsA("ImageLabel") then
			child.Image = ImageModule.getLink(imageID)
		end
	end
end

function Dice:setDiceMaterial(material)
	self.material = material
	self.object.Material = material
end

function Dice:getFacedUp()
	local upVector = Vector3.new(0,1,0)
	local maxDotValue
	local maxDotNormalID

	for _, normalID in ipairs(Enum.NormalId:GetEnumItems()) do
		local vec = Vector3.FromNormalId(normalID)
		local diceVecInWorldSpace = self.object.CFrame:VectorToWorldSpace(vec)
		local dotValue = upVector:Dot(diceVecInWorldSpace)
		if (not maxDotValue or dotValue > maxDotValue) then
			maxDotValue = dotValue
			maxDotNormalID = normalID
		end
	end

	return DICE_FACES[maxDotNormalID.Name]
end

function Dice:roll()
	Events.DiceRolled:FireAllClients()
	
	for i = 1, 20 do
		local x = math.rad(math.random(-90, 90))
		local y = math.rad(math.random(-90, 90))
		local z = math.rad(math.random(-90, 90))
		self.object.CFrame = CFrame.new(self.XCoordinate,height,self.ZCoordinate) * CFrame.fromEulerAnglesXYZ(x, y, z)
		task.wait(0.025)
	end
	
	if self.trailEnabled then self.object.Trail.Enabled = true end
	self.object.Anchored = false

	task.wait(2)

	self.object.Anchored = true
	if self.trailEnabled then self.object.Trail.Enabled = false end

	-- Read the face thats up
	local result = Dice.getFacedUp(self)
	GD.diceResults[self.diceID] = result

	task.wait(0.25)

	local StartCFrame = Instance.new("CFrameValue")
	StartCFrame.Value = self.object.CFrame

	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut, 0, false, 0)
	local tween = TweenService:Create(self.object, tweenInfo, {Position = Vector3.new(self.XCoordinate, height, self.ZCoordinate)})

	self.object.Orientation = DICE_ANGLES[result]
	tween:Play()
	
	task.wait(0.5)
end

function Dice:resetFace()
	self.object.Orientation = DICE_ANGLES[1]
end

function Dice:show()
	self.object.CFrame = CFrame.new(self.XCoordinate*10,height,self.ZCoordinate*10) * CFrame.fromEulerAnglesXYZ(math.rad(DICE_ANGLES[1].X), math.rad(DICE_ANGLES[1].Y), math.rad(DICE_ANGLES[1].Z))
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut, 0, false, 0)
	local showTween = TweenService:Create(self.object, tweenInfo, {Position = Vector3.new(self.XCoordinate,height,self.ZCoordinate)})
	showTween:Play()
	task.wait(1)	
end

function Dice:hide()
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut, 0, false, 0)
	local hideTween = TweenService:Create(self.object, tweenInfo, {Position = Vector3.new(self.XCoordinate*10,height,self.ZCoordinate*10)})
	hideTween:Play()
	task.wait(1)	
end

return Dice
