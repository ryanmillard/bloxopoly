--// Services //
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

--// Public Modules //
local RulesModule = require(ReplicatedStorage.PublicModules:WaitForChild("RulesModule"))
local TilesModule = require(script.Parent.Parent.Modules:WaitForChild("TilesModule"))
local MoneyModule = require(script.Parent.Parent.Modules:WaitForChild("MoneyModule"))
local EventModule = require(script.Parent.Parent.Modules:WaitForChild("EventModule"))

local NPCs = ReplicatedStorage:WaitForChild("NPCs")

local GD = require(ServerScriptService:WaitForChild("GameData"))

local function playerAssetValueChanged(playerNum, attributeName, attributeValue)
	local attributesAllowed = {"jailFreeCards", "busTickets"}
	if not table.find(attributesAllowed, attributeName) then return end
	EventModule.sendAllClients("AssetValueChanged", playerNum, attributeName, attributeValue)
end

local Player = {}
Player.__index = Player -- Adds functions into player object

function Player.new(playerNum: number, username: string, userId: number, teamId: number, colourId: number)
	local instance = setmetatable({}, Player)
	
	local startingMoney = RulesModule.get("playerStartingMoney")
	
	-- Identifiers
	instance.playerNum = playerNum
	instance.userId = userId
	instance.isBot = false
	instance.badge = ""
	instance.username = username
	
	-- Assets
	instance.money = startingMoney
	instance.properties = {}
	instance.jailFreeCards = 0
	instance.busTickets = 0
	
	-- States
	instance.position = 1
	instance.jailTurns = 0
	instance.inJail = false
	instance.isBankrupt = false
	
	-- Stats
	instance.totalRentPaid = 0
	instance.totalRentReceived = 0
	instance.peakNetWorth = 0
	instance.timeFinished = 0
	
	return instance
end

function Player:set(attribute, data)
	self[attribute] = data
	playerAssetValueChanged(self.playerNum, attribute, self[attribute])
end

function Player:get(attribute)
	return self[attribute]
end

function Player:update(attribute, data)
	self[attribute] += data
	playerAssetValueChanged(self.playerNum, attribute, self[attribute])
end

function Player:createPlayerNPC()
	if (self.isBot and not NPCs:FindFirstChild("Bot")) or (not self.isBot) then
		local Dummy = NPCs:WaitForChild("CharacterDummy"):Clone()
		Dummy.Name = if (self.isBot) then "Bot" else self.userId
		Dummy.Parent = NPCs
		
		local humanoidDescription = nil
		for _ = 1, 3 do
			local success, response = pcall(function()
				humanoidDescription = Players:GetHumanoidDescriptionFromUserId(self.userId)
			end)

			if success then
				Dummy.Humanoid:ApplyDescription(humanoidDescription)
				break
			else
				warn("[" .. self.playerNum .. "] " .. response)
				task.wait(0.5)
			end
		end
		
		-- Shrink down player character to fitmodule
		Dummy.Humanoid.BodyDepthScale.Value = 0.5
		Dummy.Humanoid.BodyHeightScale.Value = 0.5
		Dummy.Humanoid.BodyWidthScale.Value = 0.5
		Dummy.Humanoid.HeadScale.Value = 0.5
	end
end

function Player:getPlayerObject()
	return Players:GetPlayerByUserId(self.userId)
end

function Player:addProperty(tileNum:number)
	table.insert(self.properties, tileNum)
	EventModule.sendAllClients("TileOwnerStatusChanged", tileNum, true, self.playerNum)
end

function Player:removeProperty(tileNum:number)
	table.remove(self.properties, table.find(self.properties, tileNum))
	EventModule.sendAllClients("TileOwnerStatusChanged", tileNum, false, self.playerNum)
end

function Player:move(newPosition:number, goForwards:boolean, fastMovement:boolean)
	EventModule.sendAllClients("MovePlayer", self.playerNum, newPosition, goForwards, fastMovement)
	
	-- Move player but also give passing go money!
	local previousPosition = self.position		
	self.position = newPosition
	
	local transitionTime = if fastMovement then 0.1 else 0.25
	
	local givePassStartSalary = coroutine.create(function()
		local spacesTotal = TilesModule.calculateTileDistance(previousPosition, newPosition, goForwards)
		local spacesBeforeTarget = 0
		print(previousPosition, self.position)
		for i = 1, spacesTotal do
			if goForwards then
				previousPosition = if previousPosition == GD.tilesAmount then 1 else previousPosition + 1
			else
				previousPosition = if previousPosition == 1 then GD.tilesAmount else previousPosition - 1
			end
			spacesBeforeTarget += 1
			if previousPosition == 1 then
				task.wait(spacesBeforeTarget * transitionTime)
				local passStartAmount = RulesModule.get("passStartSalary")
				MoneyModule.update(self.playerNum, passStartAmount)
			end
		end 
	end)
	coroutine.resume(givePassStartSalary)
end

function Player:jail()
	local maxTurnsInJail = RulesModule.get("maxTurnsInJail")
	
	self.position = GD.jailTile
	self.jailTurns = maxTurnsInJail
	self.inJail = true
	
	EventModule.sendAllClients("PlayerJailed", self.playerNum, GD.jailTile)
end

function Player:bankrupt()
	self.isBankrupt = true
	self.timeFinished = os.time()
	EventModule.sendAllClients("PlayerBankrupted", self.playerNum)
end

return Player
