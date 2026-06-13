local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PassStore = DataStoreService:GetDataStore("PlaytimePass_v2")

local PlaytimePassFunction = ReplicatedStorage:FindFirstChild("PlaytimePassFunction") or Instance.new("RemoteFunction")
PlaytimePassFunction.Name = "PlaytimePassFunction"
PlaytimePassFunction.Parent = ReplicatedStorage

local AddRollCreditsEvent = ReplicatedStorage:FindFirstChild("AddRollCreditsEvent") or Instance.new("BindableEvent")
AddRollCreditsEvent.Name = "AddRollCreditsEvent"
AddRollCreditsEvent.Parent = ReplicatedStorage

local RESET_INTERVAL = 24 * 60 * 60

local milestones = {
	{Seconds = 10 * 60, Label = "10 min"},
	{Seconds = 20 * 60, Label = "20 min"},
	{Seconds = 40 * 60, Label = "40 min"},
	{Seconds = 60 * 60, Label = "1 hour"},
	{Seconds = 90 * 60, Label = "1h 30m"},
	{Seconds = 2 * 60 * 60, Label = "2 hours"},
	{Seconds = 3 * 60 * 60, Label = "3 hours"},
	{Seconds = 4 * 60 * 60, Label = "4 hours"},
	{Seconds = 5.5 * 60 * 60, Label = "5h 30m"},
	{Seconds = 7 * 60 * 60, Label = "7 hours"},
	{Seconds = 8.5 * 60 * 60, Label = "8h 30m"},
	{Seconds = 10 * 60 * 60, Label = "10 hours"},
}

local playerData = {}
local lastTick = {}

local function currentCycleId()
	return math.floor(os.time() / RESET_INTERVAL)
end

local function cycleEndTime()
	return (currentCycleId() + 1) * RESET_INTERVAL
end

local function xpNeeded(level)
	return math.floor(100 * (1.1 ^ (level - 1)))
end

local function giveXP(player, amount)
	local xp = player:FindFirstChild("XP")
	local leaderstats = player:FindFirstChild("leaderstats")
	local level = leaderstats and leaderstats:FindFirstChild("Level")
	if not xp or not level then return end

	xp.Value += amount

	while xp.Value >= xpNeeded(level.Value) do
		xp.Value -= xpNeeded(level.Value)
		level.Value += 1
	end
end

local function generateRewards()
	local rng = Random.new(currentCycleId())
	local rewards = {}

	for i, milestone in ipairs(milestones) do
		local power = i / #milestones

		local cash = math.floor((700 + power * 10500) * rng:NextNumber(0.9, 1.35))
		local xp = math.floor((180 + power * 2600) * rng:NextNumber(0.9, 1.35))
		local rolls = 0

		if i >= 3 then
			rolls = rng:NextInteger(1, math.max(1, math.floor(power * 8)))
		end

		rewards[i] = {
			Index = i,
			TimeRequired = milestone.Seconds,
			TimeLabel = milestone.Label,
			Cash = cash,
			XP = xp,
			Rolls = rolls,
		}
	end

	rewards[#milestones] = {
		Index = #milestones,
		TimeRequired = milestones[#milestones].Seconds,
		TimeLabel = milestones[#milestones].Label,
		Cash = 20000,
		XP = 5000,
		Rolls = 17,
		Final = true,
	}

	return rewards
end

local function newData()
	return {
		CycleId = currentCycleId(),
		Playtime = 0,
		Claimed = {},
	}
end

local function loadPlayer(player)
	local data

	local success, result = pcall(function()
		return PassStore:GetAsync(player.UserId)
	end)

	if success and result then
		data = result
	end

	if not data or data.CycleId ~= currentCycleId() then
		data = newData()
	end

	data.Playtime = data.Playtime or 0
	data.Claimed = data.Claimed or {}

	playerData[player] = data
	lastTick[player] = os.clock()
end

local function updatePlaytime(player)
	local data = playerData[player]
	if not data then return end

	if data.CycleId ~= currentCycleId() then
		data = newData()
		playerData[player] = data
	end

	local now = os.clock()
	local last = lastTick[player] or now
	data.Playtime += math.max(0, now - last)
	lastTick[player] = now
end

local function savePlayer(player)
	local data = playerData[player]
	if not data then return end

	pcall(function()
		PassStore:SetAsync(player.UserId, data)
	end)
end

local function getPublicData(player)
	updatePlaytime(player)

	local data = playerData[player]

	return {
		Playtime = math.floor(data.Playtime),
		Claimed = data.Claimed,
		Rewards = generateRewards(),
		CycleEndTime = cycleEndTime(),
		Now = os.time(),
	}
end

local function claimReward(player, index)
	updatePlaytime(player)

	local data = playerData[player]
	local rewards = generateRewards()
	local reward = rewards[index]

	if not reward then
		return {Success = false, Message = "Reward does not exist."}
	end

	local key = tostring(index)

	if data.Claimed[key] then
		return {Success = false, Message = "Already claimed."}
	end

	if data.Playtime < reward.TimeRequired then
		return {Success = false, Message = "Not enough playtime."}
	end

	data.Claimed[key] = true

	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")

	if cash then
		cash.Value += reward.Cash
	end

	giveXP(player, reward.XP)

	if reward.Rolls > 0 then
		AddRollCreditsEvent:Fire(player, reward.Rolls)
	end

	savePlayer(player)

	return {
		Success = true,
		Reward = reward,
		Data = getPublicData(player),
	}
end

Players.PlayerAdded:Connect(loadPlayer)

Players.PlayerRemoving:Connect(function(player)
	updatePlaytime(player)
	savePlayer(player)
	playerData[player] = nil
	lastTick[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(30)
		for _, player in ipairs(Players:GetPlayers()) do
			updatePlaytime(player)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(90)
		for _, player in ipairs(Players:GetPlayers()) do
			savePlayer(player)
		end
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		updatePlaytime(player)
		savePlayer(player)
	end
end)

PlaytimePassFunction.OnServerInvoke = function(player, action, index)
	if not playerData[player] then
		loadPlayer(player)
	end

	if action == "Get" then
		return getPublicData(player)
	elseif action == "Claim" then
		return claimReward(player, index)
	end

	return {Success = false, Message = "Unknown action."}
end
