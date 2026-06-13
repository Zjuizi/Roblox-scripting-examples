local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local Debris = game:GetService("Debris")

local EmoteInventoryStore = DataStoreService:GetDataStore("EmoteInventory_v1")

local EmoteEvent = ReplicatedStorage:FindFirstChild("EmoteEvent") or Instance.new("RemoteEvent")
EmoteEvent.Name = "EmoteEvent"
EmoteEvent.Parent = ReplicatedStorage

local EmoteBoxFunction = ReplicatedStorage:FindFirstChild("EmoteBoxFunction") or Instance.new("RemoteFunction")
EmoteBoxFunction.Name = "EmoteBoxFunction"
EmoteBoxFunction.Parent = ReplicatedStorage

local BOX_PRICE = 2000

local DEFAULT_EMOTES = {
	"Laugh",
	"Relief",
	"Cheer",
	"Dance to Fit In",
}

local BOX_EMOTES = {
	"Bird Brain",
	"Groovyn",
	"COOL Backflips",
	"The Honored One",
	"Parrot's Moves",
	"Aero Step",
	"Take the L",
	"Car Shearer",
	"Random Moves",
	"Rainbows and Sunshines",
	"Whoa, Whoa, Whoa...",
	"Penguin Walk",
}

local EMOTES = {
	Laugh = {AnimationId = "rbxassetid://1234567890", SoundId = "rbxassetid://9118823108"},
	Relief = {AnimationId = "rbxassetid://1234567890", SoundId = "rbxassetid://9118823108"},
	Cheer = {AnimationId = "rbxassetid://1234567890", SoundId = "rbxassetid://9118823108"},
	["Dance to Fit In"] = {AnimationId = "rbxassetid://1234567890", SoundId = "rbxassetid://9118823108"},

	["Bird Brain"] = {AnimationId = "rbxassetid://1234567890", SoundId = "rbxassetid://9118823108"},
	Groovyn = {AnimationId = "rbxassetid://1234567890", SoundId = "rbxassetid://9118823108"},
	["COOL Backflips"] = {AnimationId = "rbxassetid://1234567890", SoundId = "rbxassetid://9118823108"},
	["The Honored One"] = {AnimationId = "rbxassetid://1234567890", SoundId = "rbxassetid://9118823108"},
	["Parrot's Moves"] = {AnimationId = "rbxassetid://1234567890", SoundId = "rbxassetid://9118823108"},
	["Aero Step"] = {AnimationId = "rbxassetid://1234567890", SoundId = "rbxassetid://9118823108"},
	["Take the L"] = {AnimationId = "rbxassetid://1234567890", SoundId = "rbxassetid://9118823108"},
	["Car Shearer"] = {AnimationId = "rbxassetid://1234567890", SoundId = "rbxassetid://9118823108"},
	["Random Moves"] = {AnimationId = "rbxassetid://1234567890", SoundId = "rbxassetid://9118823108"},
	["Rainbows and Sunshines"] = {AnimationId = "rbxassetid://1234567890", SoundId = "rbxassetid://9118823108", SlowMove = true},
	["Whoa, Whoa, Whoa..."] = {AnimationId = "rbxassetid://1234567890", SoundId = "rbxassetid://9118823108"},
	["Penguin Walk"] = {AnimationId = "rbxassetid://1234567890", SoundId = "rbxassetid://9118823108", SlowMove = true},
}

local activeEmotes = {}
local ownedEmotes = {}

local function defaultInventory()
	local inv = {}

	for _, name in ipairs(DEFAULT_EMOTES) do
		inv[name] = true
	end

	return inv
end

local function inventoryToList(inv)
	local list = {}

	for name, owned in pairs(inv) do
		if owned then
			table.insert(list, name)
		end
	end

	table.sort(list)
	return list
end

local function loadInventory(player)
	local inv

	local success, result = pcall(function()
		return EmoteInventoryStore:GetAsync(player.UserId)
	end)

	if success and typeof(result) == "table" then
		inv = result
	else
		inv = defaultInventory()
	end

	for _, name in ipairs(DEFAULT_EMOTES) do
		inv[name] = true
	end

	ownedEmotes[player] = inv
end

local function saveInventory(player)
	local inv = ownedEmotes[player]
	if not inv then return end

	pcall(function()
		EmoteInventoryStore:SetAsync(player.UserId, inv)
	end)
end

local function playerOwnsEmote(player, emoteName)
	local inv = ownedEmotes[player]
	return inv and inv[emoteName] == true
end

local function stopEmote(player)
	local data = activeEmotes[player]
	if not data then return end

	if data.MoveConnection then
		data.MoveConnection:Disconnect()
	end

	if data.Track then
		data.Track:Stop()
		data.Track:Destroy()
	end

	if data.Sound then
		data.Sound:Stop()
		data.Sound:Destroy()
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.WalkSpeed = 30 
		humanoid.JumpPower = data.OldJumpPower or 50
		humanoid.AutoRotate = data.OldAutoRotate
	end

	activeEmotes[player] = nil
end

local function startEmote(player, emoteName)
	local info = EMOTES[emoteName]
	if not info then return end
	if not playerOwnsEmote(player, emoteName) then return end

	stopEmote(player)

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not hrp or humanoid.Health <= 0 then return end

	local oldWalkSpeed = humanoid.WalkSpeed
	local oldJumpPower = humanoid.JumpPower
	local oldAutoRotate = humanoid.AutoRotate

	if info.SlowMove then
		humanoid.WalkSpeed = 5
	else
		humanoid.WalkSpeed = 0
	end

	humanoid.JumpPower = 0
	humanoid.AutoRotate = true

	local anim = Instance.new("Animation")
	anim.AnimationId = info.AnimationId

	local track = humanoid:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play()

	local sound = Instance.new("Sound")
	sound.Name = emoteName .. "EmoteSound"
	sound.SoundId = info.SoundId
	sound.Volume = 1
	sound.Looped = true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 60
	sound.Parent = hrp
	sound:Play()

	local moveConnection
	if info.SlowMove then
		moveConnection = game:GetService("RunService").Heartbeat:Connect(function()
			if not activeEmotes[player] then return end
			if not hrp.Parent or not humanoid.Parent then return end

			local look = hrp.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)

			if flat.Magnitude > 0.05 then
				humanoid:Move(flat.Unit, false)
			end
		end)
	end

	Debris:AddItem(anim, 2)

	activeEmotes[player] = {
		Track = track,
		Sound = sound,
		MoveConnection = moveConnection,
		OldWalkSpeed = 30,
		OldJumpPower = 50,
		OldAutoRotate = oldAutoRotate,
	}
end

EmoteEvent.OnServerEvent:Connect(function(player, action, emoteName)
	if action == "Start" then
		startEmote(player, emoteName)
	elseif action == "Stop" then
		stopEmote(player)
	end
end)

EmoteBoxFunction.OnServerInvoke = function(player, action)
	if not ownedEmotes[player] then
		loadInventory(player)
	end

	if action == "GetInventory" then
		return {
			Success = true,
			Owned = inventoryToList(ownedEmotes[player]),
		}
	end

	if action == "BuyBox" then
		local leaderstats = player:FindFirstChild("leaderstats")
		local cash = leaderstats and leaderstats:FindFirstChild("Cash")

		if not cash or cash.Value < BOX_PRICE then
			return {
				Success = false,
				Message = "You need 2,000 Cash.",
				Owned = inventoryToList(ownedEmotes[player]),
			}
		end

		cash.Value -= BOX_PRICE

		local wonEmote = BOX_EMOTES[math.random(1, #BOX_EMOTES)]
		ownedEmotes[player][wonEmote] = true

		saveInventory(player)

		return {
			Success = true,
			Emote = wonEmote,
			Owned = inventoryToList(ownedEmotes[player]),
		}
	end

	return {Success = false, Message = "Unknown action."}
end

Players.PlayerAdded:Connect(function(player)
	loadInventory(player)

	player.CharacterAdded:Connect(function()
		stopEmote(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	stopEmote(player)
	saveInventory(player)
	ownedEmotes[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveInventory(player)
	end
end)
