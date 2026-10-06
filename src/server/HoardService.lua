--!strict
-- Owns the four-player Stage 2 world. Clients receive snapshots and can only request validated intents.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Stage1Config"))
local Stage2Config = require(Shared:WaitForChild("Stage2Config"))
local Stage4Config = require(Shared:WaitForChild("Stage4Config"))
local Stage5Config = require(Shared:WaitForChild("Stage5Config"))
local ProgressionRules = require(Shared:WaitForChild("ProgressionRules"))
local PublicState = require(Shared:WaitForChild("PublicState"))
local ResourceDefinitions = require(Shared:WaitForChild("ResourceDefinitions"))
local ResourceVisuals = require(Shared:WaitForChild("ResourceVisuals"))
local DataStoreAdapter = require(script.Parent:WaitForChild("DataStoreAdapter"))
local StationWorld = require(script.Parent:WaitForChild("StationWorld"))
local BasicGemWorldArt = require(script.Parent:WaitForChild("BasicGemWorldArt"))

local CourtyardWorld = require(script.Parent:WaitForChild("CourtyardWorld"))
local ActionLimiter = require(script.Parent:WaitForChild("ActionLimiter"))
local actionBuckets: {[Player]: any} = {}

local HoardService = {}

local world = ProgressionRules.newWorld(Config.litterSeedBase + 1, os.clock())
local states: { [Player]: ProgressionRules.PlayerState } = {}
local plotIds: { [Player]: number } = {}
local owners: { [number]: number } = {}
local sessionIds: { [Player]: number } = {}
local deathConnections: { [Player]: RBXScriptConnection } = {}
local readyTimes: { [Player]: number } = {}
local actionRemote: RemoteEvent
local stateRemote: RemoteEvent
local publicStateRemote: RemoteEvent
local resourcesFolder: Folder
local specialDropsFolder: Folder
local plotsFolder: Folder
local adapter = DataStoreAdapter.new()
local started = false
local publicRevision = 0
local publicDirty = true
local lastPublicBroadcast = 0

local feedbackByReason: { [string]: string } = {
	CARRY_FULL = "Carry full — return to your plot",
	ITEM_UNAVAILABLE = "Item unavailable",
	MALFORMED_ITEM = "Item unavailable",
	TUTORIAL_SPARE_LIMIT = "One spare is enough — find a kind you are missing",
	TOO_MANY_KEPT = "Choose fewer items to keep",
	NOT_ENOUGH_ITEMS = "Not enough items",
	NOT_ENOUGH_COINS = "Not enough Coins",
	NOT_ENOUGH_RESOURCES = "Missing resources",
	NOT_ENOUGH_SPECIAL_ITEMS = "Find a Basic Gem first",
	ALREADY_CRAFTED = "Already crafted",
	MISSING_DEPENDENCY = "Required upgrade missing",
	MISSING_CATEGORY = "Upgrade your workshop first",
	TRACKING_FULL = "You can track up to 3 upgrades",
	ALREADY_TRACKED = "Already tracked",
	NOT_TRACKED = "Upgrade is not tracked",
	TUTORIAL_SELL_ONE = "Sell exactly one spare item",
	TUTORIAL_CRAFT_AFK_SORTER = "Build the AFK Sorter first",
	TUTORIAL_TRACK_COLLECTION_BIN = "Track the Collection Bin first",
	TUTORIAL_TRACK_LOCKED = "Finish the tutorial step first",
	BIN_EMPTY = "Collection Bin is empty",
	BIN_LOCKED = "Build the Collection Bin first",
	BIN_STORAGE_CHANGED = "Hoard space changed — adjust what you store",
	BIN_ITEMS_CHANGED = "Bin contents changed — review your choices",
	EMPTY_BIN_SELECTION = "Choose something to store or sell",
	STALE_BIN_SELECTION = "That collection choice expired",
}

local function plotFor(player: Player): Model?
	local plotId = plotIds[player]
	local plot = if plotId then plotsFolder:FindFirstChild(string.format("Plot%d", plotId)) else nil
	return if plot and plot:IsA("Model") then plot else nil
end

local function playerContext(player: Player): (Vector3?, boolean)
	local character = player.Character
	if character == nil then return nil, false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") or humanoid.Health <= 0 then return nil, false end
	return root.Position, true
end

local function privatePacket(player: Player, feedback: string?): any
	local state = states[player]
	if state == nil then
		return { sessionId = math.max(sessionIds[player] or 1, 1), revision = 0, status = "WAITING", feedback = feedback or "Server full", carry = {}, pileItems = {}, hoardCounts = {}, specialItemCounts = { BasicGem = 0 }, hoardTotal = 0, coins = 0, capacity = Config.startingCarryCapacity, storageCapacity = Config.startingStorageCapacity, passivePerSecond = 0, crafted = {}, pendingOverflow = false }
	end
	local packet = ProgressionRules.snapshot(state)
	packet.serverNow = os.time()
	packet.sessionId = sessionIds[player]
	packet.plotId = plotIds[player]
	packet.status = "OWNER"
	packet.feedback = feedback
	return packet
end

local function send(player: Player, feedback: string?)
	if player.Parent == Players then stateRemote:FireClient(player, privatePacket(player, feedback)) end
end

local function publicPacket(): any
	local rows: { [number]: any } = {}
	for player, state in pairs(states) do
		local plotId = plotIds[player]
		if plotId ~= nil then
			local ids = {}
			for index = 1, math.min(#state.storedItems, Config.visiblePileCap) do table.insert(ids, state.storedItems[index].resourceId) end
			rows[plotId] = {
				ownerUserId = player.UserId,
				displayName = player.DisplayName,
				expansionLevel = state.expansionLevel,
				hoardTotal = #state.storedItems,
				storageCapacity = ProgressionRules.storageCapacity(state),
				passivePerSecond = ProgressionRules.passivePerSecond(state),
				pileResourceIds = ids,
			}
		end
	end
	return PublicState.build(publicRevision, rows)
end

local function sendPublic(player: Player?)
	local packet = publicPacket()
	if player then
		publicStateRemote:FireClient(player, packet)
	else
		publicStateRemote:FireAllClients(packet)
		lastPublicBroadcast = os.clock()
		publicDirty = false
	end
end

local function markPublicChanged()
	publicRevision = PublicState.nextRevision(publicRevision)
	publicDirty = true
end

local function applyCharacter(player: Player, character: Model)
	local existing = deathConnections[player]
	if existing then existing:Disconnect() end
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	local state = states[player]
	if player.Parent == Players and player.Character == character and humanoid and humanoid:IsA("Humanoid") and state ~= nil then
		humanoid.WalkSpeed = ProgressionRules.walkSpeed(state)
		deathConnections[player] = humanoid.Died:Connect(function()
			local changed = ProgressionRules.loseCarry(state)
			local afkChanged = ProgressionRules.resetAfkProgress(state)
			if changed or afkChanged then send(player, if changed then "Carry lost" else nil) end
		end)
	end
end

local function insidePart(part: BasePart, worldPosition: Vector3): boolean
	local localPosition = part.CFrame:PointToObjectSpace(worldPosition)
	local half = part.Size / 2
	return math.abs(localPosition.X) <= half.X and math.abs(localPosition.Y) <= half.Y and math.abs(localPosition.Z) <= half.Z
end

local function ownsNearbyWorkbench(player: Player): boolean
	local plot = plotFor(player)
	local rootPosition, alive = playerContext(player)
	local bench = if plot then plot:FindFirstChild("Workbench") else nil
	return alive and rootPosition ~= nil and bench ~= nil and bench:IsA("BasePart") and (rootPosition - bench.Position).Magnitude <= Config.workbenchRange
end

local function ownsNearbyStation(player: Player, stationName: string, partName: string): boolean
	local plot = plotFor(player)
	local rootPosition, alive = playerContext(player)
	local stations = if plot then plot:FindFirstChild("Stations") else nil
	local station = if stations then stations:FindFirstChild(stationName) else nil
	local part = if station then station:FindFirstChild(partName) else nil
	return alive and rootPosition ~= nil and part ~= nil and part:IsA("BasePart") and (rootPosition - part.Position).Magnitude <= Stage5Config.stationInteractionRange
end

local function createResource(row: ProgressionRules.LitterState)
	if not row.available or resourcesFolder:FindFirstChild(row.litterId) ~= nil then return end
	local definition = ResourceDefinitions.get(row.resourceId)
	if definition == nil then return end
	local part = Instance.new("Part")
	part.Name = row.litterId
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = true
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Shape = definition.shape
	part.Size = definition.size
	part.Color = definition.color
	part.CFrame = CFrame.new(row.position) * CFrame.Angles(0, math.rad(row.yaw), 0)
	part:SetAttribute("LitterId", row.litterId)
	part:SetAttribute("ResourceId", row.resourceId)
	part:SetAttribute("ItemId", ProgressionRules.currentItemId(world, row.litterId))
	part:SetAttribute("Yaw", row.yaw)
	ResourceVisuals.decorate(part, row.resourceId)
	part.Parent = resourcesFolder
end

local function renderResources()
	resourcesFolder:ClearAllChildren()
	for _, litterId in ipairs(world.litterOrder) do createResource(world.litter[litterId]) end
end

local function createBasicGem()
	if not world.basicGemActive or specialDropsFolder:FindFirstChild("BasicGem") ~= nil then return end
	local part = Instance.new("Part")
	part.Name = "BasicGem"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = 1
	part.Size = Stage4Config.gemSize
	part.Color = Color3.fromRGB(42, 221, 255)
	part.CFrame = CFrame.new(Stage4Config.gemPosition) * CFrame.Angles(math.rad(18), 0, math.rad(18))
	part:SetAttribute("SpecialItemId", "BasicGem")
	part:SetAttribute("ItemId", ProgressionRules.currentBasicGemId(world))
	part:SetAttribute("SpawnInterval", Stage4Config.gemRespawnTime)
	BasicGemWorldArt.decorate(part)
	part.Parent = specialDropsFolder
end

local function savePlayer(player: Player)
	local state = states[player]
	if state ~= nil and not adapter:save(player.UserId, ProgressionRules.serialize(state, os.time())) then warn(string.format("[Hoard] save failed for %d; live state retained", player.UserId)) end
end

local function assignPlot(player: Player): number?
	local plotId = ProgressionRules.assignLowest(owners, player.UserId)
	if plotId == nil then return nil end
	plotIds[player] = plotId
	local plot = plotsFolder:FindFirstChild(string.format("Plot%d", plotId)) :: Model
	plot:SetAttribute("OwnerUserId", player.UserId)
	plot:SetAttribute("StorageCapacity", ProgressionRules.storageCapacity(states[player]))
	plot:SetAttribute("ExpansionLevel", states[player].expansionLevel)
	local ground = plot:FindFirstChild("Ground")
	if ground and ground:IsA("BasePart") then
		local size = if states[player].expansionLevel == 1 then Stage2Config.expandedGroundSize else Stage2Config.baseGroundSize
		ground.Size = Vector3.new(size, 1, size)
	end
	local spawn = plot:FindFirstChild("SpawnLocation")
	if spawn and spawn:IsA("SpawnLocation") then
		player.RespawnLocation = spawn
		if player.Character then player.Character:PivotTo(spawn.CFrame * CFrame.new(0, 4, 0)) end
	end
	StationWorld.render(plot, states[player], player.UserId)
	markPublicChanged()
	return plotId
end

local function releasePlot(player: Player)
	local plotId = plotIds[player]
	if plotId then
		ProgressionRules.releasePlot(owners, player.UserId)
		local plot = plotsFolder:FindFirstChild(string.format("Plot%d", plotId))
		if plot then
			StationWorld.clearOwned(plot :: Model)
			plot:SetAttribute("OwnerUserId", 0); plot:SetAttribute("StorageCapacity", Config.startingStorageCapacity); plot:SetAttribute("ExpansionLevel", 0)
			local ground = plot:FindFirstChild("Ground"); if ground and ground:IsA("BasePart") then ground.Size = Vector3.new(Stage2Config.baseGroundSize, 1, Stage2Config.baseGroundSize) end
		end
	end
	plotIds[player] = nil
	markPublicChanged()
end

local function onPlayerAdded(player: Player)
	sessionIds[player] = (sessionIds[player] or 0) + 1
	player.CharacterAdded:Connect(function(character) task.defer(applyCharacter, player, character) end)
	player.CharacterRemoving:Connect(function()
		local state = states[player]
		if state ~= nil then
			local changed = ProgressionRules.loseCarry(state)
			-- Character replacement can bypass Humanoid.Died (for example LoadCharacter).
			local afkChanged = ProgressionRules.resetAfkProgress(state)
			if changed or afkChanged then send(player, if changed then "Carry lost" else nil) end
		end
	end)
	task.spawn(function()
		local ok, saved, loadReason = adapter:load(player.UserId)
		if player.Parent ~= Players then
			if ok then adapter:release(player.UserId, saved) end
			return
		end
		if not ok then
			local message = "Your saved hoard could not be loaded. Please rejoin; your saved progress has not been reset."
			if loadReason == "SESSION_ACTIVE" then
				message = "Your hoard is still open in another server. Wait a moment, then rejoin."
			elseif loadReason == "INCOMPATIBLE_SAVE" then
				message = "Your hoard needs a newer game server. Please rejoin after the update."
			end
			player:Kick(message)
			return
		end
		states[player] = ProgressionRules.normalize(saved)
		ProgressionRules.reconcileCollectionBin(states[player], os.time())
		if assignPlot(player) == nil then
			local state = states[player]
			states[player] = nil
			if state ~= nil and ok then adapter:release(player.UserId, ProgressionRules.serialize(state, os.time())) end
			send(player, "Server full")
			return
		end
		if player.Character then applyCharacter(player, player.Character) end
		send(player, if ok then nil else "Save unavailable — progress is live only")
	end)
end

local function onPlayerRemoving(player: Player)
	local state = states[player]
	-- Release ownership and stop maintenance before the save can yield.
	states[player] = nil
	releasePlot(player)
	local connection = deathConnections[player]
	if connection then connection:Disconnect() end
	deathConnections[player] = nil
	readyTimes[player] = nil
	sessionIds[player] = nil
	actionBuckets[player] = nil
	if state ~= nil then
		if not adapter:release(player.UserId, ProgressionRules.serialize(state, os.time())) then warn("[Hoard] final save unavailable for " .. player.UserId) end
	end
end

local function handleReady(player: Player)
	local now = os.clock()
	if readyTimes[player] ~= nil and now - readyTimes[player] < Config.readyInterval then return end
	readyTimes[player] = now
	send(player, if states[player] == nil then "Server full" else nil)
	sendPublic(player)
end

local function handlePickup(player: Player, itemId: any)
	local state = states[player]
	if state == nil or type(itemId) ~= "string" or #itemId > 64 then return end
	local rootPosition, alive = playerContext(player)
	local accepted, reason = ProgressionRules.pickUp(world, state, {
		itemId = itemId,
		now = os.clock(),
		rootPosition = rootPosition or Vector3.zero,
		alive = alive,
		isOwner = plotIds[player] ~= nil,
	})
	if accepted then
		local litterId = string.match(itemId, "^([^:]+):")
		local resource = if litterId then resourcesFolder:FindFirstChild(litterId) else nil
		if resource then resource:Destroy() end
		send(player)
	elseif feedbackByReason[reason] then send(player, feedbackByReason[reason]) end
end

local function handleSpecialPickup(player: Player, itemId: any)
	local state = states[player]
	if state == nil or type(itemId) ~= "string" or #itemId > 64 then return end
	local rootPosition, alive = playerContext(player)
	local accepted, reason = ProgressionRules.claimBasicGem(world, state, {
		itemId = itemId,
		now = os.clock(),
		rootPosition = rootPosition or Vector3.zero,
		alive = alive,
		isOwner = plotIds[player] ~= nil,
	})
	if accepted then
		local gem = specialDropsFolder:FindFirstChild("BasicGem")
		if gem then gem:Destroy() end
		send(player, "Basic Gem found!")
	elseif feedbackByReason[reason] then send(player, feedbackByReason[reason]) end
end

local function handleCraft(player: Player, recipeId: any)
	local state = states[player]
	if state == nil or type(recipeId) ~= "string" or #recipeId > 64 or not ownsNearbyWorkbench(player) then return end
	local accepted, reason = ProgressionRules.craft(state, recipeId, os.time())
	if accepted then
		local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then humanoid.WalkSpeed = ProgressionRules.walkSpeed(state) end
		local plot = plotFor(player)
		if plot then plot:SetAttribute("StorageCapacity", ProgressionRules.storageCapacity(state)); plot:SetAttribute("ExpansionLevel", state.expansionLevel) end
		if plot then StationWorld.render(plot, state, player.UserId) end
		if plot and recipeId == "BiggerPlot" and state.expansionLevel == 1 then
			task.delay(Stage2Config.expansionDuration, function()
				if plot.Parent and plot:GetAttribute("OwnerUserId") == player.UserId then
					local ground = plot:FindFirstChild("Ground"); if ground and ground:IsA("BasePart") then ground.Size = Vector3.new(Stage2Config.expandedGroundSize, 1, Stage2Config.expandedGroundSize) end
				end
			end)
		end
		markPublicChanged()
		send(player, "Crafted " .. recipeId)
	else send(player, feedbackByReason[reason] or "Craft failed") end
end

local function handleViewCollectionBin(player: Player)
	local state = states[player]
	if state == nil or not ownsNearbyStation(player, "CollectionBin", "InteractionPart") then return end
	ProgressionRules.reconcileCollectionBin(state, os.time())
	local accepted, reason = ProgressionRules.viewCollectionBin(state)
	if accepted then send(player) else send(player, feedbackByReason[reason] or "Collection Bin unavailable") end
end
local function handleOpenCollectionBin(player: Player)
	local state = states[player]
	if state == nil or not ownsNearbyStation(player, "CollectionBin", "InteractionPart") then return end
	ProgressionRules.reconcileCollectionBin(state, os.time())
	local accepted, reason, stored = ProgressionRules.openCollectionBin(state)
	if accepted then
		markPublicChanged()
		send(player, string.format("Collected %d items", stored))
	elseif reason == "BIN_OVERFLOW" then
		send(player)
	else
		send(player, feedbackByReason[reason] or "Collection failed")
	end
end

local function handleResolveCollectionBin(player: Player, argument: any)
	local state = states[player]
	if state == nil or not ownsNearbyStation(player, "CollectionBin", "InteractionPart") then return end
	local accepted, reason, stored, sold, value = ProgressionRules.resolveCollectionBin(state, argument)
	if accepted then
		if stored > 0 then markPublicChanged() end
		send(player, string.format("Stored %d • sold %d for $%d", stored, sold, value))
	else
		send(player, feedbackByReason[reason] or "Collection choice rejected")
	end
end

local function handleCancelCollectionBin(player: Player, argument: any)
	local state = states[player]
	local token = if type(argument) == "table" then argument.token else nil
	if state ~= nil and type(token) == "number" and ProgressionRules.cancelCollectionBin(state, token) then send(player) end
end

local function handleSell(player: Player, argument: any)
	local state = states[player]
	if state == nil or type(argument) ~= "table" or not ownsNearbyWorkbench(player) then return end
	local resourceId = argument.resourceId
	local amount = argument.amount
	if type(resourceId) ~= "string" or #resourceId > 64 then return end
	local accepted, reason, value
	if amount == "ALL" then accepted, reason, value = ProgressionRules.sellAll(state, resourceId)
	elseif type(amount) == "number" and amount > 0 and amount % 1 == 0 then accepted, reason, value = ProgressionRules.sell(state, resourceId, amount)
	else return end
	if accepted then markPublicChanged(); send(player, string.format("Sold for $%d", value)) else send(player, feedbackByReason[reason] or "Sale failed") end
end

local function handleOverflow(player: Player, keepItemIds: any)
	local state = states[player]
	if state == nil then return end
	local rootPosition, alive = playerContext(player)
	local plot = plotFor(player)
	local zone = if plot then plot:FindFirstChild("DepositZone") else nil
	if not alive or rootPosition == nil or zone == nil or not zone:IsA("BasePart") or not insidePart(zone, rootPosition) then return end
	local accepted, reason, kept, sold = ProgressionRules.resolveOverflow(state, keepItemIds)
	if accepted then markPublicChanged(); send(player, string.format("Kept %d • sold %d", kept, sold)) else send(player, feedbackByReason[reason] or "Selection rejected") end
end

local function handleTrack(player: Player, argument: any)
	local state = states[player]
	if state == nil or type(argument) ~= "table" then return end
	local recipeId, trackAction = argument.recipeId, argument.action
	if type(recipeId) ~= "string" or #recipeId > 64 or type(trackAction) ~= "string" then return end
	local accepted, reason = ProgressionRules.track(state, recipeId, trackAction)
	if accepted then send(player) else send(player, feedbackByReason[reason] or "Tracking failed") end
end

local function onAction(player: Player, action: any, argument: any)
	if player.Parent ~= Players or type(action) ~= "string" or #action > 32 then return end
	if not ActionLimiter.allow(actionBuckets, player, os.clock()) then return end
	if action == "READY" then handleReady(player)
	elseif action == "PICK_UP" then handlePickup(player, argument)
	elseif action == "PICK_UP_SPECIAL" then handleSpecialPickup(player, argument)
	elseif action == "CRAFT" then handleCraft(player, argument)
	elseif action == "SELL" then handleSell(player, argument)
	elseif action == "TRACK" then handleTrack(player, argument)
	elseif action == "RESOLVE_OVERFLOW" then handleOverflow(player, argument)
	elseif action == "VIEW_COLLECTION_BIN" then handleViewCollectionBin(player)
	elseif action == "OPEN_COLLECTION_BIN" then handleOpenCollectionBin(player)
	elseif action == "RESOLVE_COLLECTION_BIN" then handleResolveCollectionBin(player, argument)
	elseif action == "CANCEL_COLLECTION_BIN" then handleCancelCollectionBin(player, argument) end
end

local function maintenanceLoop()
	local incomeElapsed = 0
	local saveElapsed = 0
	while started do
		task.wait(Config.maintenanceInterval)
		local now = os.clock()
		for _, item in ipairs(ProgressionRules.respawnDue(world, now)) do
			local litterId = string.match(item.itemId, "^([^:]+):")
			if litterId then createResource(world.litter[litterId]) end
		end
		if ProgressionRules.spawnBasicGemDue(world, now) then createBasicGem() end
		for player, state in pairs(states) do
			local rootPosition, alive = playerContext(player)
			local plot = plotFor(player)
			local zone = if plot then plot:FindFirstChild("DepositZone") else nil
			if rootPosition and zone and zone:IsA("BasePart") then
				local isInside = insidePart(zone, rootPosition)
				if not isInside and state.pendingOverflow then ProgressionRules.cancelOverflow(state); send(player) end
				local wasPending = state.pendingOverflow
				local accepted, reason, count, passiveDelta = ProgressionRules.deposit(state, isInside, alive, true)
				if accepted then markPublicChanged(); send(player, string.format("+%d items • +$%.1f/sec", count, passiveDelta))
				elseif reason == "OVERFLOW" and not wasPending then send(player, "Choose which carried items to keep") end
			end
			local stations = if plot then plot:FindFirstChild("Stations") else nil
			local afk = if stations then stations:FindFirstChild("AFKSorter") else nil
			local afkZone = if afk then afk:FindFirstChild("AfkZone") else nil
			local standing = alive and rootPosition ~= nil and afkZone ~= nil and afkZone:IsA("BasePart") and insidePart(afkZone, rootPosition)
			local afkChanged, afkEvent = ProgressionRules.tickAfk(state, standing, os.clock())
			if afkChanged then
				if afkEvent == "AFK_STORED" then markPublicChanged() end
				send(player)
			end
			if ProgressionRules.reconcileCollectionBin(state, os.time()) > 0 then send(player) end
		end
		incomeElapsed += Config.maintenanceInterval
		saveElapsed += Config.maintenanceInterval
		if incomeElapsed + 1e-6 >= Config.passiveTickSeconds then
			incomeElapsed -= Config.passiveTickSeconds
			for player, state in pairs(states) do if ProgressionRules.tickIncome(state, 1) > 0 then send(player) end end
		end
		if saveElapsed + 1e-6 >= Config.autosaveSeconds then
			saveElapsed = 0
			for player in pairs(states) do task.spawn(savePlayer, player) end
		end
		if publicDirty and now - lastPublicBroadcast >= Stage2Config.publicCoalesceSeconds then sendPublic(nil) end
	end
end

function HoardService.start()
	if started then return end
	started = true
	local hoard = Workspace:WaitForChild("Hoard")
	CourtyardWorld.render(Workspace)
	resourcesFolder = hoard:WaitForChild("Resources") :: Folder
	specialDropsFolder = (hoard:FindFirstChild("SpecialDrops") or Instance.new("Folder")) :: Folder
	specialDropsFolder.Name = "SpecialDrops"
	specialDropsFolder.Parent = hoard
	plotsFolder = hoard:WaitForChild("Plots") :: Folder
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:IsA("Model") then StationWorld.render(plot, { crafted = {} }, 0) end
	end
	local remotes = ReplicatedStorage:FindFirstChild("HoardRemotes") or Instance.new("Folder")
	remotes.Name = "HoardRemotes"
	remotes.Parent = ReplicatedStorage
	actionRemote = (remotes:FindFirstChild("Action") or Instance.new("RemoteEvent")) :: RemoteEvent
	actionRemote.Name = "Action"
	actionRemote.Parent = remotes
	stateRemote = (remotes:FindFirstChild("State") or Instance.new("RemoteEvent")) :: RemoteEvent
	stateRemote.Name = "State"
	stateRemote.Parent = remotes
	publicStateRemote = (remotes:FindFirstChild("PublicState") or Instance.new("RemoteEvent")) :: RemoteEvent
	publicStateRemote.Name = "PublicState"
	publicStateRemote.Parent = remotes
	renderResources()
	actionRemote.OnServerEvent:Connect(onAction)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do onPlayerAdded(player) end
	game:BindToClose(function()
		for player, state in pairs(states) do
			if not adapter:release(player.UserId, ProgressionRules.serialize(state, os.time())) then
				warn("[Hoard] shutdown save unavailable for " .. player.UserId)
			end
		end
	end)
	task.spawn(maintenanceLoop)
end

return HoardService
