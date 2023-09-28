--// Services //
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Events = ReplicatedStorage:WaitForChild("Events")

--// Modules //
local GD = require(script.Parent.Parent:WaitForChild("GameData"))

local module = {}

local responses = {}

local function getPlayerNum(userId)
	for playerNum, playerData in pairs(GD.players) do
		if playerData.userId == userId then
			return playerNum
		end
	end
	return nil
end

local function resetResponse(eventName, userId)
	local key = eventName .. tostring(userId)
	if (responses[key]) then
		responses[key] = nil
	end
end

function module.setResponse(eventName, userId, response)
	local key = eventName .. tostring(userId)
	responses[key] = response
end

function module.awaitResponse(timeLimit, eventName, userId, ...)
	local Player = Players:GetPlayerByUserId(userId)
	if not Player then return end
	
	local playerNum = getPlayerNum(userId)
	
	resetResponse(eventName, userId)
	module.sendClient(eventName, userId, ...)
	
	local key = eventName .. tostring(userId)
	local response = nil
	local clientResponsed = false
	
	for _ = 1, timeLimit*4 do
		task.wait(0.25)
		if (responses[key]) then
			response = responses[key]
			clientResponsed = true
			break
		end
		
		if GD.players[playerNum]:get("isBankrupt") then
			module.sendClient("InputPromptTimeout", userId, eventName)
			return nil
		end
	end
	
	if not clientResponsed then
		module.sendClient("InputPromptTimeout", userId, eventName)
		-- TODO: Record this to kick out AFK people
	end
	
	resetResponse(eventName, userId)
	
	return response
end

function module.sendClient(eventName, userId, ...)
	local Player = Players:GetPlayerByUserId(userId)
	if not Player then return end
	
	if (... == nil) then
		local success, response = pcall(function()
			Events[eventName]:FireClient(Player)
		end)
		if not success then print(response) end
	else
		local data = {...}
		local success, response = pcall(function()
			Events[eventName]:FireClient(Player, table.unpack(data))
		end)
		if not success then print(response) end
	end
end

function module.sendAllClientsExcept(eventName, exceptionUserId, ...)
	for playerNum, _ in pairs(GD.players) do
		local isBot = GD.players[playerNum]:get("isBot")		
		local isBankrupt = GD.players[playerNum]:get("isBankrupt")
		local userId = GD.players[playerNum]:get("userId")
		
		if isBot then continue end
		if isBankrupt then continue end
		if userId == exceptionUserId then continue end
		
		module.sendClient(eventName, userId, ...)
	end
end

function module.sendAllClients(eventName, ...)
	for playerNum, _ in pairs(GD.players) do
		local isBot = GD.players[playerNum]:get("isBot")		
		local isBankrupt = GD.players[playerNum]:get("isBankrupt")
		local userId = GD.players[playerNum]:get("userId")

		if isBot then continue end
		if isBankrupt then continue end
		
		module.sendClient(eventName, userId, ...)
	end
end

return module
