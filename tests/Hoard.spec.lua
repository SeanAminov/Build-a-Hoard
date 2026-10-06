--!strict
-- Edit-mode regression suite. Copy to src/shared/_Spec.lua, run StudioHarness, then remove the copy.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local lines: { string } = {}
	local passed, failed = 0, 0
	local function log(value: string) table.insert(lines, value) end
	local function check(name: string, ok: boolean, detail: string?)
		if ok then passed += 1; log("PASS  " .. name) else failed += 1; log("FAIL  " .. name .. (if detail then "  (" .. detail .. ")" else "")) end
	end
	local function near(a: number, b: number, tolerance: number?): boolean return math.abs(a - b) <= (tolerance or 1e-5) end
	local function sameVector(a: Vector3, b: Vector3): boolean return near(a.X, b.X) and near(a.Y, b.Y) and near(a.Z, b.Z) end
	local function throws(callback: () -> ()): boolean return not pcall(callback) end

	log("\n[1] source contract")
	do
		local GameInfo = require(Shared:WaitForChild("GameInfo"))
		check("working title is valid", GameInfo.validate() == true and GameInfo.NAME == "Build a Hoard")
		check("Stage 5 is current", GameInfo.STAGE == "STAGE_5")
		local strict, unsafe, moveCloser = true, false, false
		local sourceCount = 0
		for _, root in ipairs({ Shared, game:GetService("ServerScriptService"):WaitForChild("Server"), game:GetService("StarterPlayer").StarterPlayerScripts:WaitForChild("Client") }) do
			for _, source in ipairs(root:GetDescendants()) do
				if source:IsA("LuaSourceContainer") and source.Name ~= "_Spec" then
					sourceCount += 1
					if string.find(source.Source, "--!strict", 1, true) ~= 1 then strict = false end
					if string.find(source.Source, "loadstring", 1, true) or string.find(source.Source, "HttpGet", 1, true) or string.find(source.Source, "MarketplaceService", 1, true) then unsafe = true end
					if string.find(source.Source, "Move closer", 1, true) then moveCloser = true end
				end
			end
		end
		check("all shipping sources use strict Luau", strict and sourceCount >= 22, tostring(sourceCount))
		check("source has no dynamic loader or monetization", not unsafe)
		check("pickup never shows Move closer", not moveCloser)
		local serverSource = game:GetService("ServerScriptService").Server.HoardService.Source
		for _, action in ipairs({ "READY", "PICK_UP", "PICK_UP_SPECIAL", "CRAFT", "SELL", "TRACK", "RESOLVE_OVERFLOW", "VIEW_COLLECTION_BIN", "OPEN_COLLECTION_BIN", "RESOLVE_COLLECTION_BIN", "CANCEL_COLLECTION_BIN" }) do check("server whitelists " .. action, string.find(serverSource, 'action == "' .. action .. '"', 1, true) ~= nil) end
		check("production saving uses UpdateAsync", string.find(game:GetService("ServerScriptService").Server.DataStoreAdapter.Source, "UpdateAsync", 1, true) ~= nil)
		check("plot assignment places an existing character at its assigned spawn", string.find(serverSource, "player.Character:PivotTo", 1, true) ~= nil)
	end

	log("\n[2] definitions and prototype balance")
	do
		local Resources = require(Shared:WaitForChild("ResourceDefinitions"))
		local Recipes = require(Shared:WaitForChild("RecipeDefinitions"))
		local Config = require(Shared:WaitForChild("Stage1Config"))
		local Stage4 = require(Shared:WaitForChild("Stage4Config"))
		local Stage5 = require(Shared:WaitForChild("Stage5Config"))
		local SpecialItems = require(Shared:WaitForChild("SpecialItemDefinitions"))
		check("four resources validate", Resources.validate() == true)
		check("twelve recipes validate", Recipes.validate(nil, 12) == true)
		check("one protected special item validates", SpecialItems.validate(nil, 1) == true and SpecialItems.get("BasicGem") ~= nil)
		check("Stage 1 config validates", Config.validate() == true)
		check("Stage 4 timers and spawn validate", Stage4.validate() == true and Stage4.firstGemDelay == 300 and Stage4.gemRespawnTime == 300 and Stage4.gemPickupRange == 8 and sameVector(Stage4.gemPosition, Vector3.new(0, 3.25, 0)))
		check("Stage 5 station timing validates", Stage5.validate() == true and Stage5.dataVersion == 6 and Stage5.afkRewardInterval == 60 and Stage5.collectionBinInterval == 900 and Stage5.collectionBinCapacity == 12 and Stage5.collectionBinInterval * Stage5.collectionBinCapacity == 10800 and Stage5.stationSurfaceClearance == 0.08)
		local expected = {
			Wood = { Vector3.new(2, 1, 1), Color3.fromRGB(124, 92, 70), 5, 0.15, Enum.PartType.Block },
			Stone = { Vector3.new(1.6, 1.6, 1.6), Color3.fromRGB(112, 112, 118), 8, 0.15, Enum.PartType.Ball },
			ScrapMetal = { Vector3.new(1.5, 0.5, 1.5), Color3.fromRGB(125, 145, 160), 15, 0.3, Enum.PartType.Block },
			OldCan = { Vector3.new(1.5, 1, 1), Color3.fromRGB(190, 105, 55), 25, 0.45, Enum.PartType.Cylinder },
		}
		for index, resourceId in ipairs(Config.resourceOrder) do
			local row = Resources.get(resourceId); local wanted = expected[resourceId]
			check(resourceId .. " exact data", row ~= nil and row.order == index and sameVector(row.size, wanted[1] :: Vector3) and row.color == wanted[2] and row.sellValue == wanted[3] and row.passivePerSecond == wanted[4] and row.shape == wanted[5])
		end
		check("unknown resource returns nil", Resources.get("Unknown") == nil)
		check("missing resource rows fail", throws(function() Resources.validate({ Wood = Resources.get("Wood") } :: any) end))
		check("duplicate recipe order fails", throws(function()
			local candidate: any = {}
			for key, row in pairs(Recipes.rows) do candidate[key] = table.clone(row); candidate[key].resources = table.clone(row.resources); if row.specialItems then candidate[key].specialItems = table.clone(row.specialItems) end end
			candidate.TrailBoots.order = 1
			Recipes.validate(candidate, 3)
		end))
		check("core capacities are exact", Config.startingCarryCapacity == 5 and Config.beginnerCarryCapacity == 8 and Config.upgradedCarryCapacity == 10 and Config.startingStorageCapacity == 60 and Config.upgradedStorageCapacity == 70)
		check("Stage 3 upgrade facts are exact", Config.stage3CarryCapacity == 12 and Config.stage3StorageCapacity == 120 and Config.stage3WalkSpeed == 23.2)
		check("movement and ranges are exact", Config.startingWalkSpeed == 20 and Config.upgradedWalkSpeed == 21.6 and Config.promptRange == 6 and Config.pickupRange == 7 and Config.workbenchRange == 8)
		check("save and income timing are exact", Config.passiveTickSeconds == 1 and Config.autosaveSeconds == 60 and Config.respawnTime == 8)
		for _, recipe in ipairs(Recipes.ordered()) do
			check(recipe.id .. " ordered data", recipe.order >= 1 and recipe.coinCost > 0 and recipe.resultValue > 0)
		end
	end

	log("\n[3] shared litter")
	do
		local Config = require(Shared:WaitForChild("Stage1Config"))
		local first = Config.generateLitter(Config.litterSeedBase)
		local repeatRows = Config.generateLitter(Config.litterSeedBase)
		local changedRows = Config.generateLitter(Config.litterSeedBase + 1)
		check("generated litter validates", Config.validateLitter(first) == true)
		local counts: { [string]: number } = {}; local minSpacing = math.huge; local longest, run = 0, 0; local previous = ""; local repeatMatches, changed = true, false; local yaws: { [string]: boolean } = {}
		for index, row in ipairs(first) do
			counts[row.resourceId] = (counts[row.resourceId] or 0) + 1
			if row.resourceId == previous then run += 1 else previous, run = row.resourceId, 1 end
			longest = math.max(longest, run); yaws[string.format("%.1f", row.yaw)] = true
			for prior = 1, index - 1 do minSpacing = math.min(minSpacing, (Vector2.new(row.position.X, row.position.Z) - Vector2.new(first[prior].position.X, first[prior].position.Z)).Magnitude) end
			if row.resourceId ~= repeatRows[index].resourceId or not sameVector(row.position, repeatRows[index].position) or row.yaw ~= repeatRows[index].yaw then repeatMatches = false end
			if row.resourceId ~= changedRows[index].resourceId or not sameVector(row.position, changedRows[index].position) or row.yaw ~= changedRows[index].yaw then changed = true end
		end
		for _, resourceId in ipairs(Config.resourceOrder) do check(resourceId .. " has exactly 18 litter", counts[resourceId] == 18) end
		check("litter is spaced at least six studs", minSpacing >= 6)
		check("litter has no type run over two", longest <= 2)
		local yawCount = 0; for _ in pairs(yaws) do yawCount += 1 end
		check("litter yaw is varied", yawCount >= 60)
		check("same seed repeats", repeatMatches)
		check("different seed changes", changed)
		check("25 consecutive seeds validate", pcall(function() for seed = Config.litterSeedBase, Config.litterSeedBase + 24 do Config.generateLitter(seed) end end))
	end

	log("\n[4] authoritative multiplayer progression")
	do
		local Config = require(Shared:WaitForChild("Stage1Config"))
		local Rules = require(Shared:WaitForChild("ProgressionRules"))
		local function pickup(world: any, state: any, litterId: string, now: number, owner: boolean?, alive: boolean?, offset: Vector3?): (boolean, string)
			return Rules.pickUp(world, state, { itemId = Rules.currentItemId(world, litterId) or litterId .. ":1", now = now, rootPosition = world.litter[litterId].position + (offset or Vector3.zero), isOwner = if owner == nil then true else owner, alive = if alive == nil then true else alive })
		end
		local world = Rules.newWorld(Config.litterSeedBase)
		local one, two = Rules.newPlayerState(), Rules.newPlayerState()
		local ok = pickup(world, one, "Litter01", 0)
		check("first player collects shared litter", ok and #one.carry == 1 and #two.carry == 0)
		local duplicate, duplicateReason = pickup(world, two, "Litter01", 1)
		check("second player cannot duplicate shared pickup", not duplicate and duplicateReason == "ITEM_UNAVAILABLE" and #two.carry == 0)
		check("shared litter respawns at eight seconds", #Rules.respawnDue(world, 7.999) == 0 and #Rules.respawnDue(world, 8) == 1 and Rules.currentItemId(world, "Litter01") == "Litter01:2")
		local far, farReason = pickup(Rules.newWorld(Config.litterSeedBase), Rules.newPlayerState(), "Litter01", 0, true, true, Vector3.new(7.001, 0, 0))
		check("pickup rejects beyond tolerance", not far and farReason == "TOO_FAR")
		local guest, guestReason = pickup(Rules.newWorld(Config.litterSeedBase), Rules.newPlayerState(), "Litter01", 0, false)
		check("pickup rejects non-owner", not guest and guestReason == "NOT_OWNER")
		local dead, deadReason = pickup(Rules.newWorld(Config.litterSeedBase), Rules.newPlayerState(), "Litter01", 0, true, false)
		check("pickup rejects dead player", not dead and deadReason == "NOT_ALIVE")
		local pacedWorld, paced = Rules.newWorld(Config.litterSeedBase), Rules.newPlayerState(); pickup(pacedWorld, paced, "Litter01", 0)
		local tooFast, paceReason = pickup(pacedWorld, paced, "Litter02", 0.1)
		check("pickup cadence is enforced", not tooFast and paceReason == "TOO_FAST")
		local atBoundary = pickup(pacedWorld, paced, "Litter02", 0.15)
		check("pickup cadence boundary succeeds", atBoundary)
		local fullWorld, fullCarry = Rules.newWorld(Config.litterSeedBase), Rules.newPlayerState()
		for index = 1, 5 do table.insert(fullCarry.carry, { itemId = "full" .. index, resourceId = "Wood" }) end
		local fullAccepted, fullReason = pickup(fullWorld, fullCarry, "Litter01", 0)
		check("full carry leaves litter untouched", not fullAccepted and fullReason == "CARRY_FULL" and fullWorld.litter.Litter01.available and #fullCarry.carry == 5)

		local depositState = Rules.newPlayerState()
		table.insert(depositState.carry, { itemId = "a", resourceId = "Wood" }); table.insert(depositState.carry, { itemId = "b", resourceId = "OldCan" })
		local deposited, depositReason, count, rate = Rules.deposit(depositState, true, true, true)
		check("deposit transfers exact full carry", deposited and depositReason == "DEPOSITED" and count == 2 and rate == 0.6 and #depositState.carry == 0 and #depositState.storedItems == 2)
		check("deposit token increments once", depositState.depositToken == 1 and depositState.lastDepositCount == 2)
		local rejected = Rules.deposit(depositState, true, true, true)
		check("empty deposit is idempotent", not rejected and depositState.depositToken == 1)
		local exactFit = Rules.newPlayerState(); for index = 1, 59 do table.insert(exactFit.storedItems, { itemId = "fit" .. index, resourceId = "Stone" }) end; table.insert(exactFit.carry, { itemId = "last", resourceId = "OldCan" })
		check("deposit accepts an exact storage fit", Rules.deposit(exactFit, true, true, true) and #exactFit.storedItems == 60 and #exactFit.carry == 0)

		-- The collecting step refuses a second spare, so the tutorial cannot strand a new player.
		local spareState = Rules.newPlayerState()
		for _, resourceId in ipairs({ "Wood", "Wood", "Stone", "ScrapMetal" }) do
			table.insert(spareState.carry, { itemId = resourceId .. #spareState.carry, resourceId = resourceId })
		end
		local stoneLitter, canLitter = nil, nil
		for _, litterId in ipairs(world.litterOrder) do
			local row = world.litter[litterId]
			if row.available and row.resourceId == "Stone" and stoneLitter == nil then stoneLitter = litterId end
			if row.available and row.resourceId == "OldCan" and canLitter == nil then canLitter = litterId end
		end
		local spareBlocked, spareReason = pickup(world, spareState, stoneLitter :: any, 400)
		check("a second spare is refused at the source", not spareBlocked and spareReason == "TUTORIAL_SPARE_LIMIT" and #spareState.carry == 4)
		check("a missing kind is still collectable", (pickup(world, spareState, canLitter :: any, 500)) and #spareState.carry == 5)

		local overflow = Rules.newPlayerState()
		for index = 1, 57 do table.insert(overflow.storedItems, { itemId = "stored" .. index, resourceId = "Wood" }) end
		local carryTypes = { "Wood", "Stone", "ScrapMetal", "OldCan", "Wood" }
		for index, resourceId in ipairs(carryTypes) do table.insert(overflow.carry, { itemId = "carry" .. index, resourceId = resourceId }) end
		local overOk, overReason = Rules.deposit(overflow, true, true, true)
		check("overflow transfers nothing", not overOk and overReason == "OVERFLOW" and #overflow.storedItems == 57 and #overflow.carry == 5 and overflow.pendingOverflow)
		local tooMany, tooManyReason = Rules.resolveOverflow(overflow, { "carry1", "carry2", "carry3", "carry4" })
		check("overflow rejects more keeps than free slots", not tooMany and tooManyReason == "TOO_MANY_KEPT" and #overflow.storedItems == 57 and #overflow.carry == 5)
		local duplicateKeep, duplicateKeepReason = Rules.resolveOverflow(overflow, { "carry2", "carry2" })
		check("overflow rejects duplicate selection ids", not duplicateKeep and duplicateKeepReason == "MALFORMED_SELECTION" and #overflow.carry == 5)
		local resolved, resolveReason, kept, sold = Rules.resolveOverflow(overflow, { "carry2", "carry4", "carry5" })
		check("overflow keeps any selected three", resolved and resolveReason == "OVERFLOW_RESOLVED" and kept == 3 and sold == 2 and #overflow.storedItems == 60 and #overflow.carry == 0)
		check("overflow sells exact unselected value", overflow.coins == 20)
		local replay, replayReason = Rules.resolveOverflow(overflow, {})
		check("overflow cannot replay", not replay and replayReason == "NO_OVERFLOW")

		-- Stage 3 v2: one overflow event owns one token, so unrelated snapshots cannot reset the chooser.
		local SaleValues = require(Shared:WaitForChild("ResourceDefinitions"))
		local token = Rules.newPlayerState()
		check("a new state carries no overflow token", token.overflowToken == 0 and not token.pendingOverflow)
		for index = 1, 57 do table.insert(token.storedItems, { itemId = "stored" .. index, resourceId = "Wood" }) end
		for index, resourceId in ipairs(carryTypes) do table.insert(token.carry, { itemId = "carry" .. index, resourceId = resourceId }) end
		Rules.deposit(token, true, true, true)
		check("the first overflowing deposit stamps token one", token.pendingOverflow and token.overflowToken == 1)
		local pendingRevision = token.revision
		Rules.deposit(token, true, true, true)
		check("repeating the deposit keeps one overflow event", token.overflowToken == 1 and token.pendingOverflow and token.revision == pendingRevision)
		local earned = Rules.tickIncome(token, 1)
		check("income moves revision and Coins but never the token", earned > 0 and token.coins == earned and token.revision > pendingRevision and token.overflowToken == 1 and token.pendingOverflow)
		local refused, refusedReason = Rules.resolveOverflow(token, { "carry1", "carry2", "carry3", "carry4" })
		check("a refused selection leaves the event untouched", not refused and refusedReason == "TOO_MANY_KEPT" and token.overflowToken == 1 and token.pendingOverflow and #token.carry == 5)
		check("private snapshots expose the token and saves never do", Rules.snapshot(token).overflowToken == 1 and Rules.serialize(token).overflowToken == nil)
		Rules.cancelOverflow(token)
		check("leaving the zone cancels without changing the token", not token.pendingOverflow and token.overflowToken == 1)
		Rules.deposit(token, true, true, true)
		check("the next overflowing entry increments exactly once", token.pendingOverflow and token.overflowToken == 2)
		local settled, settledReason, settledKept, settledSold = Rules.resolveOverflow(token, { "carry1", "carry3", "carry5" })
		local expectedSale = SaleValues.get("Stone").sellValue + SaleValues.get("OldCan").sellValue
		check("resolution clears pending without a new token", settled and settledReason == "OVERFLOW_RESOLVED" and settledKept == 3 and settledSold == 2 and not token.pendingOverflow and token.overflowToken == 2)
		check("resolution applies the exact deposit and sale", #token.storedItems == 60 and #token.carry == 0 and math.abs(token.coins - (earned + expectedSale)) < 0.001)
		check("a resolved overflow cannot replay", not (Rules.resolveOverflow(token, {})))

		local sellState = Rules.newPlayerState()
		for index = 1, 3 do table.insert(sellState.storedItems, { itemId = "wood" .. index, resourceId = "Wood" }) end
		local soldOne, _, valueOne = Rules.sell(sellState, "Wood", 1)
		local soldAll, _, valueAll = Rules.sellAll(sellState, "Wood")
		check("Sell 1 and Sell All use exact values", soldOne and soldAll and valueOne == 5 and valueAll == 10 and sellState.coins == 15 and #sellState.storedItems == 0)
		local income = Rules.newPlayerState(); table.insert(income.storedItems, { itemId = "w", resourceId = "Wood" }); table.insert(income.storedItems, { itemId = "c", resourceId = "OldCan" })
		check("passive tick is exact and rounded", Rules.passivePerSecond(income) == 0.6 and Rules.tickIncome(income, 3) == 1.8 and income.coins == 1.8)

		local Recipes = require(Shared:WaitForChild("RecipeDefinitions"))
		for _, recipe in ipairs(Recipes.ordered()) do
			local noCoins = Rules.newPlayerState(); if recipe.requires then noCoins.crafted[recipe.requires] = true end; if recipe.categoryRequires then noCoins.crafted[recipe.categoryRequires] = true end
			for resourceId, amount in pairs(recipe.resources) do for index = 1, amount do table.insert(noCoins.storedItems, { itemId = "noCoins" .. resourceId .. index, resourceId = resourceId }) end end
			for itemId, amount in pairs(recipe.specialItems or {}) do noCoins.specialItems[itemId] = amount end
			local noCoinsBefore = #noCoins.storedItems; local noCoinCraft, noCoinReason = Rules.craft(noCoins, recipe.id)
			check(recipe.id .. " rejects missing Coins atomically", not noCoinCraft and noCoinReason == "NOT_ENOUGH_COINS" and #noCoins.storedItems == noCoinsBefore)
			local noItems = Rules.newPlayerState(); noItems.coins = recipe.coinCost; if recipe.requires then noItems.crafted[recipe.requires] = true end; if recipe.categoryRequires then noItems.crafted[recipe.categoryRequires] = true end
			local noItemCraft, noItemReason = Rules.craft(noItems, recipe.id)
			check(recipe.id .. " rejects missing items atomically", not noItemCraft and noItemReason == "NOT_ENOUGH_RESOURCES" and noItems.coins == recipe.coinCost)
			local state = Rules.newPlayerState(); state.coins = recipe.coinCost
			if recipe.requires then state.crafted[recipe.requires] = true end
			if recipe.categoryRequires then state.crafted[recipe.categoryRequires] = true end
			for resourceId, amount in pairs(recipe.resources) do for index = 1, amount do table.insert(state.storedItems, { itemId = resourceId .. index, resourceId = resourceId }) end end
			for itemId, amount in pairs(recipe.specialItems or {}) do state.specialItems[itemId] = amount end
			local before = #state.storedItems; local crafted, reason = Rules.craft(state, recipe.id)
			check(recipe.id .. " crafts atomically", crafted and reason == "CRAFTED" and state.crafted[recipe.id] and #state.storedItems < before and state.coins == 0)
			local replayCraft, replayCraftReason = Rules.craft(state, recipe.id)
			check(recipe.id .. " cannot repeat", not replayCraft and replayCraftReason == "ALREADY_CRAFTED")
		end
		local carryUpgrade = Rules.newPlayerState(); carryUpgrade.crafted.CarryRack = true
		local storageUpgrade = Rules.newPlayerState(); storageUpgrade.crafted.HoardCrate = true
		local speedUpgrade = Rules.newPlayerState(); speedUpgrade.crafted.TrailBoots = true
		check("upgrade facts derive from crafted flags", Rules.carryCapacity(carryUpgrade) == 10 and Rules.storageCapacity(storageUpgrade) == 70 and Rules.walkSpeed(speedUpgrade) == 21.6)
		local stage3 = Rules.newPlayerState(); stage3.crafted.CarryRack = true; stage3.crafted.TrailBoots = true; stage3.crafted.HoardCrate = true; stage3.crafted.BiggerPlot = true; stage3.crafted.WorkshopLevel2 = true; stage3.crafted.ReinforcedCarryRack = true; stage3.crafted.TrailBoots2 = true; stage3.crafted.StorageShelves = true; stage3.expansionLevel = 1
		check("Stage 3 upgrades derive exact maximum facts", Rules.carryCapacity(stage3) == 12 and Rules.storageCapacity(stage3) == 120 and Rules.walkSpeed(stage3) == 23.2 and Rules.workshopTier(stage3) == 2)
		local locked = Rules.newPlayerState(); locked.crafted.CarryRack = true; locked.coins = 1000; for index = 1, 15 do table.insert(locked.storedItems, { itemId = "lockedWood" .. index, resourceId = "Wood" }) end; for index = 1, 10 do table.insert(locked.storedItems, { itemId = "lockedScrap" .. index, resourceId = "ScrapMetal" }) end; for index = 1, 4 do table.insert(locked.storedItems, { itemId = "lockedCan" .. index, resourceId = "OldCan" }) end
		local categoryCraft, categoryReason = Rules.craft(locked, "ReinforcedCarryRack")
		check("Workshop II category blocks advanced crafting", not categoryCraft and categoryReason == "MISSING_CATEGORY")
		local deathState = Rules.newPlayerState(); table.insert(deathState.storedItems, { itemId = "safe", resourceId = "Stone" }); table.insert(deathState.carry, { itemId = "lost", resourceId = "Wood" })
		Rules.loseCarry(deathState)
		check("death loses carry and preserves storage", #deathState.carry == 0 and #deathState.storedItems == 1)

		local gemWorld = Rules.newWorld(Config.litterSeedBase, 100)
		check("Basic Gem waits five minutes", not Rules.spawnBasicGemDue(gemWorld, 399.999) and Rules.spawnBasicGemDue(gemWorld, 400) and not Rules.spawnBasicGemDue(gemWorld, 999))
		local winner, loser = Rules.newPlayerState(), Rules.newPlayerState()
		local gemId = Rules.currentBasicGemId(gemWorld)
		local farClaim, farReason = Rules.claimBasicGem(gemWorld, loser, { itemId = gemId, now = 401, rootPosition = Vector3.new(9, 3.25, 0), alive = true, isOwner = true })
		check("Basic Gem rejects an over-range claim atomically", not farClaim and farReason == "TOO_FAR" and gemWorld.basicGemActive and loser.specialItems.BasicGem == 0)
		local won = Rules.claimBasicGem(gemWorld, winner, { itemId = gemId, now = 401, rootPosition = Vector3.new(0, 3.25, 0), alive = true, isOwner = true })
		local lost, lostReason = Rules.claimBasicGem(gemWorld, loser, { itemId = gemId, now = 401, rootPosition = Vector3.new(0, 3.25, 0), alive = true, isOwner = true })
		check("one server-wide Basic Gem generation has exactly one winner", won and not lost and lostReason == "ITEM_UNAVAILABLE" and winner.specialItems.BasicGem == 1 and loser.specialItems.BasicGem == 0 and gemWorld.basicGemNextSpawnAt == 701)
		check("the next server-wide Basic Gem waits another five minutes", not Rules.spawnBasicGemDue(gemWorld, 700.999) and Rules.spawnBasicGemDue(gemWorld, 701) and Rules.currentBasicGemId(gemWorld) == "BasicGem:2")
		Rules.loseCarry(winner)
		check("protected Basic Gem survives death/reset", winner.specialItems.BasicGem == 1)
		local portal = Recipes.get("PortalKey")
		check("Portal Key exact prototype recipe", portal ~= nil and portal.coinCost == 2000 and portal.categoryRequires == "WorkshopLevel2" and portal.specialItems.BasicGem == 1 and portal.resources.Wood == 25 and portal.resources.Stone == 20 and portal.resources.ScrapMetal == 18 and portal.resources.OldCan == 10)
		local missingGem = Rules.newPlayerState(); missingGem.crafted.WorkshopLevel2 = true; missingGem.crafted.BiggerPlot = true; missingGem.crafted.HoardCrate = true; missingGem.coins = 2000
		for resourceId, amount in pairs(portal.resources) do for index = 1, amount do table.insert(missingGem.storedItems, { itemId = "portal" .. resourceId .. index, resourceId = resourceId }) end end
		local gemCraft, gemReason = Rules.craft(missingGem, "PortalKey")
		check("Portal Key requires a Basic Gem atomically", not gemCraft and gemReason == "NOT_ENOUGH_SPECIAL_ITEMS" and missingGem.coins == 2000 and #missingGem.storedItems == 73)

		local afkRecipe, binRecipe = Recipes.get("AFKSorter"), Recipes.get("CollectionBin")
		check("station recipes have exact prototype costs and Buildings membership", afkRecipe ~= nil and afkRecipe.workbenchTab == "BUILDINGS" and afkRecipe.coinCost == 1 and afkRecipe.resources.Wood == 1 and afkRecipe.resources.Stone == 1 and afkRecipe.resources.ScrapMetal == 1 and afkRecipe.resources.OldCan == 1 and binRecipe ~= nil and binRecipe.workbenchTab == "BUILDINGS" and binRecipe.coinCost == 25 and binRecipe.resources.Wood == 2 and binRecipe.resources.Stone == 1 and binRecipe.resources.ScrapMetal == 1 and binRecipe.resources.OldCan == 1)
		local satchelRecipe = Recipes.get("ScavengerSatchel")
		local binItems, satchelItems = 0, 0
		for _, amount in pairs(binRecipe.resources) do binItems += amount end
		for _, amount in pairs(satchelRecipe.resources) do satchelItems += amount end
		check("Collection Bin fits one starter trip and costs less than Satchel", binItems == 5 and binItems < satchelItems and binRecipe.coinCost < satchelRecipe.coinCost)
		local afk = Rules.newPlayerState(); afk.crafted.AFKSorter = true
		local entered, enteredEvent = Rules.tickAfk(afk, true, 100)
		local _, earlyEvent = Rules.tickAfk(afk, true, 159)
		local rewarded, rewardEvent, rewardId = Rules.tickAfk(afk, true, 160)
		check("standing AFK starts once and rewards at exactly sixty seconds", entered and enteredEvent == "AFK_STARTED" and earlyEvent == nil and rewarded and rewardEvent == "AFK_STORED" and rewardId == "Wood" and #afk.storedItems == 1 and afk.afkInteracted)
		for index = 2, 60 do table.insert(afk.storedItems, { itemId = "afkFull" .. index, resourceId = "Wood" }) end
		local soldAfk, soldEvent, soldId, soldValue = Rules.tickAfk(afk, true, 220)
		check("full Hoard auto-sells only the newly generated AFK item", soldAfk and soldEvent == "AFK_SOLD" and soldId == "Stone" and soldValue == 8 and afk.coins == 8 and #afk.storedItems == 60)
		local stopped, stoppedEvent = Rules.tickAfk(afk, false, 221)
		check("leaving AFK stops the timer without a catch-up reward", stopped and stoppedEvent == "AFK_STOPPED" and not afk.afkActive and afk.afkNextRewardAt == nil)
		local paused = Rules.newPlayerState(); paused.crafted.AFKSorter = true
		Rules.tickAfk(paused, true, 0); Rules.tickAfk(paused, true, 40)
		Rules.tickAfk(paused, false, 40); Rules.tickAfk(paused, false, 400)
		check("leaving the pad preserves forty seconds and no off-pad time", paused.afkProgressSeconds == 40 and Rules.snapshot(paused).afkRemainingSeconds == 20)
		Rules.tickAfk(paused, true, 400); Rules.tickAfk(paused, true, 420)
		check("forty seconds plus resumed twenty awards exactly once", #paused.storedItems == 1 and paused.afkProgressSeconds == 0)
		Rules.tickAfk(paused, true, 479)
		for index = 1, 20 do Rules.tickAfk(paused, false, 479 + index); Rules.tickAfk(paused, true, 479 + index) end
		check("repeated exit/reentry at fifty-nine seconds cannot generate items", #paused.storedItems == 1 and paused.afkProgressSeconds == 59)
		Rules.tickAfk(paused, true, 500); Rules.tickAfk(paused, true, 500)
		check("one additional standing second awards once, duplicate timestamp never twice", #paused.storedItems == 2 and paused.afkProgressSeconds == 0)
		Rules.tickAfk(paused, true, 510); paused.pendingOverflow = true; Rules.tickAfk(paused, true, 600)
		check("carried overflow pauses partial progress", paused.afkProgressSeconds == 10 and not paused.afkActive)
		paused.pendingOverflow = false; Rules.tickAfk(paused, true, 700); Rules.tickAfk(paused, true, 750)
		check("overflow resumes without a catch-up or lost progress", #paused.storedItems == 3 and paused.afkProgressSeconds == 0)
		Rules.tickAfk(paused, true, 780); Rules.tickAfk(paused, true, 10000)
		check("one delayed maintenance sample grants at most one and retains valid remainder", #paused.storedItems == 4 and paused.afkProgressSeconds == 30)
		check("death/reset clears only session AFK timing", Rules.resetAfkProgress(paused) and paused.afkProgressSeconds == 0 and paused.afkLastSampleAt == nil and not paused.afkActive and #paused.storedItems == 4)
		Rules.tickAfk(paused, true, 10001); Rules.tickAfk(paused, true, 10041)
		local rejoined = Rules.normalize(Rules.serialize(paused))
		check("partial AFK seconds are never saved or carried across rejoin", rejoined.afkProgressSeconds == 0 and rejoined.afkLastSampleAt == nil and not rejoined.afkActive and #rejoined.storedItems == 4)

		local viewedBin = Rules.newPlayerState(); viewedBin.crafted.CollectionBin = true
		local viewed, viewReason = Rules.viewCollectionBin(viewedBin)
		local viewedRevision = viewedBin.revision
		Rules.viewCollectionBin(viewedBin)
		check("viewing an empty Collection Bin dismisses its hint once without moving items", viewed and viewReason == "BIN_VIEWED" and viewedBin.collectionBinInteracted and viewedBin.revision == viewedRevision and Rules.collectionBinTotal(viewedBin) == 0)
		local bin = Rules.newPlayerState(); bin.crafted.CollectionBin = true; bin.collectionBinLastAt = 1000
		check("Collection Bin produces eleven items before three hours", Rules.reconcileCollectionBin(bin, 11799) == 11 and Rules.collectionBinTotal(bin) == 11)
		check("Collection Bin reaches twelve items at exactly three hours", Rules.reconcileCollectionBin(bin, 11800) == 1 and Rules.collectionBinTotal(bin) == 12 and bin.collectionBinCounts.Wood == 3 and bin.collectionBinCounts.Stone == 3 and bin.collectionBinCounts.ScrapMetal == 3 and bin.collectionBinCounts.OldCan == 3)
		local claimed, claimReason, claimedCount = Rules.openCollectionBin(bin)
		check("Collection Bin auto-claims atomically when everything fits", claimed and claimReason == "BIN_CLAIMED" and claimedCount == 12 and #bin.storedItems == 12 and Rules.collectionBinTotal(bin) == 0 and bin.collectionBinInteracted)
		local noBacklog = Rules.newPlayerState(); noBacklog.crafted.CollectionBin = true; noBacklog.collectionBinLastAt = 1000
		Rules.reconcileCollectionBin(noBacklog, 12400); Rules.openCollectionBin(noBacklog)
		check("full offline Collection Bin discards time beyond capacity", Rules.reconcileCollectionBin(noBacklog, 12900) == 0 and Rules.reconcileCollectionBin(noBacklog, 13300) == 1)

		local choice = Rules.newPlayerState(); choice.crafted.CollectionBin = true
		for index = 1, 59 do table.insert(choice.storedItems, { itemId = "choiceStored" .. index, resourceId = "Wood" }) end
		choice.collectionBinCounts.Wood = 2; choice.collectionBinCounts.Stone = 1
		local opened, openReason = Rules.openCollectionBin(choice)
		local choiceToken = choice.collectionBinToken
		check("overflowing Collection Bin snapshots the whole batch without moving items", not opened and openReason == "BIN_OVERFLOW" and choice.collectionBinPending and choice.collectionBinBatchCounts.Wood == 2 and choice.collectionBinBatchCounts.Stone == 1 and #choice.storedItems == 59)
		choice.collectionBinCounts.OldCan = 1
		local resolvedBin, resolvedReason, binStored, binSold, binValue = Rules.resolveCollectionBin(choice, { token = choiceToken, storeCounts = { Wood = 1 }, sellCounts = { Stone = 1 } })
		check("Collection Bin stores, sells and leaves exact selected quantities", resolvedBin and resolvedReason == "BIN_RESOLVED" and binStored == 1 and binSold == 1 and binValue == 8 and #choice.storedItems == 60 and choice.coins == 8 and choice.collectionBinCounts.Wood == 1 and choice.collectionBinCounts.Stone == 0 and choice.collectionBinCounts.OldCan == 1 and not choice.collectionBinPending)
		local cancel = Rules.newPlayerState(); cancel.crafted.CollectionBin = true; cancel.collectionBinCounts.ScrapMetal = 2
		for index = 1, 60 do table.insert(cancel.storedItems, { itemId = "cancel" .. index, resourceId = "Wood" }) end
		Rules.openCollectionBin(cancel); local beforeCancel = Rules.collectionBinTotal(cancel)
		check("stale Collection Bin cancellation cannot close a newer choice", not Rules.cancelCollectionBin(cancel, cancel.collectionBinToken - 1) and cancel.collectionBinPending)
		check("closing Collection Bin preserves every item", Rules.cancelCollectionBin(cancel, cancel.collectionBinToken) and Rules.collectionBinTotal(cancel) == beforeCancel and not cancel.collectionBinPending)
	end

	log("\n[5] persistence, assignment and presentation")
	do
		local Rules = require(Shared:WaitForChild("ProgressionRules"))
		local MemoryStore = require(Shared:WaitForChild("MemoryStore"))
		local saved = { version = 1, coins = 42.27, inventoryCounts = { Wood = 99, Stone = 99, Unknown = 999 }, crafted = { CarryRack = true, Hacked = true }, capacity = 9999, walkSpeed = 9999 }
		local normalized = Rules.normalize(saved)
		check("normalization rounds Coins and trims to derived capacity", normalized.coins == 42.3 and #normalized.storedItems == 60)
		check("normalization ignores injected facts", Rules.carryCapacity(normalized) == 10 and Rules.storageCapacity(normalized) == 60 and Rules.walkSpeed(normalized) == 20 and normalized.crafted.Hacked == nil)
		local roundTrip = Rules.normalize(Rules.serialize(normalized))
		check("legacy saves migrate and round-trip through version 5", roundTrip.coins == normalized.coins and #roundTrip.storedItems == #normalized.storedItems and roundTrip.crafted.CarryRack == true and roundTrip.expansionLevel == 0 and Rules.serialize(normalized).version == 6 and normalized.tutorialStep == 5 and roundTrip.specialItems.BasicGem == 0)
		local gemSave = Rules.normalize({ version = 4, specialItemCounts = { BasicGem = 3 }, crafted = {}, inventoryCounts = {}, tutorialStep = 5, trackedRecipeIds = {} })
		check("version 4 protected items round-trip", gemSave.specialItems.BasicGem == 3 and Rules.serialize(gemSave).specialItemCounts.BasicGem == 3 and Rules.snapshot(gemSave).specialItemCounts.BasicGem == 3)
		local stationSave = Rules.newPlayerState(); stationSave.crafted.CollectionBin = true; stationSave.collectionBinCounts.Wood = 3; stationSave.collectionBinLastAt = 12345; stationSave.collectionBinCursor = 3; stationSave.collectionBinInteracted = true; stationSave.crafted.AFKSorter = true; stationSave.afkRewardCursor = 2; stationSave.afkInteracted = true
		local stationRoundTrip = Rules.normalize(Rules.serialize(stationSave))
		check("version 5 station progress round-trips without pending UI state", stationRoundTrip.collectionBinCounts.Wood == 3 and stationRoundTrip.collectionBinLastAt == 12345 and stationRoundTrip.collectionBinCursor == 3 and stationRoundTrip.collectionBinInteracted and stationRoundTrip.afkRewardCursor == 2 and stationRoundTrip.afkInteracted and not stationRoundTrip.collectionBinPending and stationRoundTrip.afkNextRewardAt == nil)
		local offline = Rules.normalize({ version = 5, coins = 10, inventoryCounts = { Wood = 10 } })
		check("legacy saves get no invented offline interval", Rules.creditOfflineIncome(offline, 1000) == 0 and offline.coins == 10)
		check("offline pays saved passive rate for elapsed seconds", Rules.creditOfflineIncome(offline, 1060) == 90 and offline.coins == 100)
		check("offline interval cannot be claimed twice", Rules.creditOfflineIncome(offline, 1060) == 0)
		check("offline income caps at three hours", Rules.creditOfflineIncome(offline, 100000) == 16200)
		check("future timestamps never grant negative income", Rules.creditOfflineIncome(offline, 90000) == 0)
		local offlineRoundTrip = Rules.normalize(Rules.serialize(offline, 100100))
		check("offline timestamp persists across release", offlineRoundTrip.offlineIncomeAt == 100100)
		local emptyOffline = Rules.newPlayerState()
		emptyOffline.offlineIncomeAt = 1000
		check("empty hoard earns no offline coins", Rules.creditOfflineIncome(emptyOffline, 2000) == 0)
		local malformed = Rules.normalize({ coins = 0 / 0, inventoryCounts = { Wood = -4.8, Stone = "a" }, crafted = "x" })
		check("malformed save clamps safely", malformed.coins == 0 and #malformed.storedItems == 0)
		local injectedStage3 = Rules.normalize({ version = 2, crafted = { ReinforcedCarryRack = true, TrailBoots2 = true, StorageShelves = true } })
		check("normalization removes Stage 3 upgrades without their chains", Rules.workshopTier(injectedStage3) == 1 and Rules.carryCapacity(injectedStage3) == 5 and Rules.walkSpeed(injectedStage3) == 20 and Rules.storageCapacity(injectedStage3) == 60)
		local memory = MemoryStore.new(); local original = { nested = { count = 4 } }; memory:save("a", original); original.nested.count = 9
		local loaded = memory:load("a"); loaded.nested.count = 20
		check("memory store copies writes and reads", (memory:load("a") :: any).nested.count == 4 and memory:load("b") == nil)
		local owners: { [number]: number } = {}
		for id = 1, 4 do check("plot assignment chooses " .. id, Rules.assignLowest(owners, 100 + id) == id) end
		check("fifth player receives no plot", Rules.assignLowest(owners, 999) == nil)
		check("plot release returns the exact vacancy", Rules.releasePlot(owners, 102) == 2 and Rules.assignLowest(owners, 999) == 2)
		local Layout = require(Shared:WaitForChild("PresentationLayout"))
		check("twelve carry offsets are valid", pcall(function() for index = 1, 12 do Layout.carryOffset(index, 2) end end))
		check("thirteenth carry offset fails", throws(function() Layout.carryOffset(13, 2) end))
		check("pile view caps at 120", Layout.visibleCount(1000) == 120)
		check("snapshot ordering rejects stale revision", Layout.shouldApplySnapshot(nil, nil, 1, 0) and not Layout.shouldApplySnapshot(1, 5, 1, 4) and Layout.shouldApplySnapshot(1, 5, 1, 6))
		local Resources = require(Shared:WaitForChild("ResourceDefinitions")); local inside = true
		for index = 1, 120 do
			local resourceId = ({ "Wood", "Stone", "ScrapMetal", "OldCan" })[(index - 1) % 4 + 1]
			local definition = Resources.get(resourceId); local transform = Layout.pileTransform(index, resourceId)
			if math.abs(transform.Position.X) + definition.size.Magnitude / 2 > 32 or math.abs(transform.Position.Z) + definition.size.Magnitude / 2 > 32 then inside = false end
		end
		check("120 pile placeholders fit the 64-stud plot", inside)
	end

	log("\n[6] Stage 2 hoard identity")
	do
		local Config = require(Shared:WaitForChild("Stage1Config"))
		local Stage2Config = require(Shared:WaitForChild("Stage2Config"))
		local Recipes = require(Shared:WaitForChild("RecipeDefinitions"))
		local Rules = require(Shared:WaitForChild("ProgressionRules"))
		local PublicState = require(Shared:WaitForChild("PublicState"))
		check("Stage 2 config validates exact expansion", Stage2Config.validate() == true and Stage2Config.dataVersion == 3 and Stage2Config.baseGroundSize == 64 and Stage2Config.expandedGroundSize == 64 and Stage2Config.expansionDuration == 0.5)
		local recipe = Recipes.get("BiggerPlot")
		check("Bigger Plot exact recipe", recipe ~= nil and recipe.coinCost == 800 and recipe.requires == "HoardCrate" and recipe.resources.Wood == 20 and recipe.resources.Stone == 15 and recipe.resources.ScrapMetal == 12 and recipe.resources.OldCan == 5 and recipe.resultKind == "PLOT_EXPANSION" and recipe.resultValue == 1)
		local blocked = Rules.newPlayerState(); blocked.coins = 800
		for resourceId, amount in pairs(recipe.resources) do for index = 1, amount do table.insert(blocked.storedItems, { itemId = resourceId .. index, resourceId = resourceId }) end end
		local blockedTotal = #blocked.storedItems; local blockedCraft, blockedReason = Rules.craft(blocked, "BiggerPlot")
		check("Bigger Plot requires Hoard Crate atomically", not blockedCraft and blockedReason == "MISSING_DEPENDENCY" and #blocked.storedItems == blockedTotal and blocked.coins == 800 and blocked.expansionLevel == 0)
		for missingId, _ in pairs(recipe.resources) do
			local missing = Rules.newPlayerState(); missing.coins = 800; missing.crafted.HoardCrate = true
			for resourceId, amount in pairs(recipe.resources) do for index = 1, amount - (if resourceId == missingId then 1 else 0) do table.insert(missing.storedItems, { itemId = resourceId .. index, resourceId = resourceId }) end end
			local before = #missing.storedItems; local missingCraft, missingReason = Rules.craft(missing, "BiggerPlot")
			check("Bigger Plot rejects missing " .. missingId, not missingCraft and missingReason == "NOT_ENOUGH_RESOURCES" and #missing.storedItems == before and missing.coins == 800 and missing.expansionLevel == 0)
		end
		blocked.crafted.HoardCrate = true; local expanded, expandedReason = Rules.craft(blocked, "BiggerPlot")
		check("Bigger Plot deducts exact requirements", expanded and expandedReason == "CRAFTED" and #blocked.storedItems == 0 and blocked.coins == 0 and blocked.expansionLevel == 1 and Rules.storageCapacity(blocked) == 100)
		local expandedReplay, expandedReplayReason = Rules.craft(blocked, "BiggerPlot")
		check("Bigger Plot cannot repeat", not expandedReplay and expandedReplayReason == "ALREADY_CRAFTED")
		local migrated = Rules.normalize({ version = 1, expansionLevel = 1, crafted = { HoardCrate = true, BiggerPlot = true } })
		local hostile = Rules.normalize({ version = 2, expansionLevel = 1, crafted = { BiggerPlot = true } })
		local valid = Rules.normalize({ version = 2, expansionLevel = 1, crafted = { HoardCrate = true, BiggerPlot = true } })
		check("version 1 always migrates to expansion zero", migrated.expansionLevel == 0 and migrated.crafted.BiggerPlot == nil)
		check("expansion without Hoard Crate is removed", hostile.expansionLevel == 0 and hostile.crafted.BiggerPlot == nil and Rules.storageCapacity(hostile) == 60)
		check("valid version 2 expansion round-trips", valid.expansionLevel == 1 and valid.crafted.HoardCrate and valid.crafted.BiggerPlot and Rules.normalize(Rules.serialize(valid)).expansionLevel == 1)
		local ids = {}; for index = 1, 140 do table.insert(ids, Config.resourceOrder[(index - 1) % 4 + 1]) end
		local input = { [2] = { ownerUserId = 12, displayName = "Builder", expansionLevel = 1, hoardTotal = 140, storageCapacity = 100, passivePerSecond = 17.5, pileResourceIds = ids, coins = 999999, carry = { "private" } } }
		local packet = PublicState.build(7, input); local row = packet.plots[1]
		check("public summary is ordered and bounded", packet.worldRevision == 7 and #packet.plots == 1 and row.plotId == 2 and #row.pileResourceIds == 120)
		local approved = { plotId = true, ownerUserId = true, displayName = true, expansionLevel = true, hoardTotal = true, storageCapacity = true, passivePerSecond = true, pileResourceIds = true }
		local fieldsSafe = true; for key in pairs(row) do if not approved[key] then fieldsSafe = false end end
		check("public summary contains approved fields only", fieldsSafe and row.coins == nil and row.carry == nil)
		row.pileResourceIds[1] = "Changed"; row.hoardTotal = -1
		check("public summary cannot mutate its source", ids[1] ~= "Changed" and input[2].hoardTotal == 140)
		check("public revision ordering rejects stale packets", PublicState.nextRevision(7) == 8 and PublicState.shouldApply(nil, 0) and PublicState.shouldApply(8, 8) and not PublicState.shouldApply(8, 7))
		local readyState = Rules.newPlayerState(); local readyRevision = readyState.revision; Rules.snapshot(readyState); Rules.snapshot(readyState)
		check("snapshot or READY-style refresh cannot create a deposit token", readyState.depositToken == 0 and readyState.revision == readyRevision)
		local footprintsClear = true
		for first = 1, 4 do for second = first + 1, 4 do if (Config.plots[first].center - Config.plots[second].center).Magnitude < Stage2Config.expandedGroundSize then footprintsClear = false end end end
		check("all expanded 80-stud plot footprints remain separate", footprintsClear)
		local UiPresentation = require(Shared:WaitForChild("UiPresentation"))
		check("Carry Rack shows its concrete gain", UiPresentation.benefitText(Recipes.get("CarryRack")) == "+2 BACKPACK SPACE")
		check("Trail Boots shows its concrete gain", UiPresentation.benefitText(Recipes.get("TrailBoots")) == "+8% WALK SPEED")
		check("Hoard Crate shows its concrete gain", UiPresentation.benefitText(Recipes.get("HoardCrate")) == "+10 HOARD SPACE")
		check("Bigger Plot shows both concrete gains", UiPresentation.benefitText(Recipes.get("BiggerPlot")) == "+30 HOARD SPACE")
		check("Workshop II shows its category unlock", UiPresentation.benefitText(Recipes.get("WorkshopLevel2")) == "UNLOCK WORKSHOP II")
		check("Stage 3 upgrades show incremental gains", UiPresentation.benefitText(Recipes.get("ReinforcedCarryRack")) == "+2 BACKPACK SPACE" and UiPresentation.benefitText(Recipes.get("TrailBoots2")) == "+7% WALK SPEED" and UiPresentation.benefitText(Recipes.get("StorageShelves")) == "+20 HOARD SPACE")
		check("Portal Key shows its concrete unlock", UiPresentation.benefitText(Recipes.get("PortalKey")) == "UNLOCK ZONE 2 PORTAL")
		check("passive income has precise plus-per-second copy", UiPresentation.formatRate(0) == "+$0.00/sec" and UiPresentation.formatRate(1.2) == "+$1.20/sec")
		local clientSource = game:GetService("StarterPlayer").StarterPlayerScripts.Client
		check("workbench contains Buildings, Upgrades and Inventory tabs", string.find(clientSource.WorkbenchController.Source, "BUILDINGS", 1, true) ~= nil and string.find(clientSource.WorkbenchController.Source, "UPGRADES", 1, true) ~= nil and string.find(clientSource.WorkbenchController.Source, "INVENTORY", 1, true) ~= nil)
		check("workbench uses a visual selected recipe and progress rows", string.find(clientSource.WorkbenchController.Source, "SelectedRecipe", 1, true) ~= nil and string.find(clientSource.WorkbenchController.Source, "ProgressFill", 1, true) ~= nil and string.find(clientSource.WorkbenchController.Source, "OWNED / NEEDED", 1, true) ~= nil)
		check("workbench no longer exposes generic Result copy", string.find(clientSource.WorkbenchController.Source, "Result:", 1, true) == nil)
		check("inventory uses a selected item popup and quantity controls", string.find(clientSource.IndexController.Source, "SelectedItemPopup", 1, true) ~= nil and string.find(clientSource.IndexController.Source, "Decrease", 1, true) ~= nil and string.find(clientSource.IndexController.Source, "Increase", 1, true) ~= nil)
		check("HUD includes passive income below Coins", string.find(clientSource.HudController.Source, "PassiveIncomeLabel", 1, true) ~= nil and string.find(clientSource.HudController.Source, "PASSIVE", 1, true) ~= nil)
		local artSource = clientSource.UiArt.Source
		check("procedural UI art covers all four resources", string.find(artSource, 'resourceId == "Wood"', 1, true) ~= nil and string.find(artSource, 'resourceId == "Stone"', 1, true) ~= nil and string.find(artSource, 'resourceId == "ScrapMetal"', 1, true) ~= nil and string.find(artSource, 'resourceId == "OldCan"', 1, true) ~= nil)
		local manifest = {}
		for key, value in string.gmatch(clientSource.UiImageAssets.Source, '(%w+)%s*=%s*"([^"]*)"') do manifest[key] = value end
		local iconIds = table.clone(Config.resourceOrder)
		table.insert(iconIds, "BasicGem")
		for _, row in ipairs(Recipes.ordered()) do table.insert(iconIds, row.id) end
		local manifestCount, iconsUploaded = 0, true
		for _ in pairs(manifest) do manifestCount += 1 end
		for _, id in ipairs(iconIds) do if manifest[id] == nil then iconsUploaded = false end end
		for _, id in ipairs(iconIds) do if string.match(manifest[id] or "", "^rbxassetid://%d+$") == nil then iconsUploaded = false end end
		check("every resource and recipe has one icon manifest entry; approved icons are uploaded", iconsUploaded and manifestCount == #iconIds, tostring(manifestCount))

		-- The collecting step: five objects, one of every kind plus a single spare.
		local Pointers = require(Shared:WaitForChild("PointerTargets"))
		local Tutorial = require(Shared:WaitForChild("TutorialRules"))
		local fresh = Tutorial.progress(Config.resourceOrder, {}, {}, {})
		check("collecting starts wanting five objects and all four kinds", fresh.remaining == 5 and fresh.missingTypes == 4 and fresh.active and not fresh.done)
		local partial = Tutorial.progress(Config.resourceOrder, { { itemId = "a", resourceId = "Wood" } }, { Stone = 2, ScrapMetal = 0 }, {})
		check("carried and stored items both count as held", partial.missingTypes == 2 and partial.wanted.ScrapMetal == true and partial.wanted.OldCan == true and partial.wanted.Wood == nil and partial.remaining == 2)
		local spareWanted = Tutorial.progress(Config.resourceOrder, { { itemId = "b", resourceId = "OldCan" } }, { Wood = 1, Stone = 1, ScrapMetal = 1 }, {})
		check("with every kind held, any resource will do as the spare", spareWanted.missingTypes == 0 and spareWanted.remaining == 1 and spareWanted.wanted.Wood == true and spareWanted.wanted.OldCan == true and not spareWanted.done)
		local finished = Tutorial.progress(Config.resourceOrder, {}, { Wood = 2, Stone = 1, ScrapMetal = 1, OldCan = 1 }, {})
		check("five objects covering every kind ends the collecting step", finished.done and not finished.active and next(finished.wanted) == nil)
		local doubled = Tutorial.progress(Config.resourceOrder, {}, { Wood = 2, Stone = 1 }, {})
		check("a held kind is refused once a spare exists", Tutorial.blocksPickup(doubled, "Stone"))
		check("a missing kind is never refused", not Tutorial.blocksPickup(doubled, "OldCan"))
		check("the first spare is allowed", not Tutorial.blocksPickup(Tutorial.progress(Config.resourceOrder, {}, { Wood = 1, Stone = 1 }, {}), "Wood"))
		check("a player who has crafted is never restricted", not Tutorial.blocksPickup(Tutorial.progress(Config.resourceOrder, {}, { Wood = 2, Stone = 1 }, { CarryRack = true }), "Stone"))
		local candidates = {
			{ id = "Litter05", resourceId = "Wood", position = Vector3.new(30, 0, 0) },
			{ id = "Litter02", resourceId = "Stone", position = Vector3.new(4, 0, 0) },
			{ id = "Litter09", resourceId = "Wood", position = Vector3.new(10, 0, 0) },
			{ id = "Litter01", resourceId = "Wood", position = Vector3.new(10, 0, 0) },
		}
		local nearestWood = Pointers.nearest(candidates, { Wood = true }, Vector3.zero)
		check("the arrow skips resources the player already holds", nearestWood ~= nil and nearestWood.resourceId == "Wood")
		check("equal distances break on the lowest id, as the pickup prompt does", nearestWood ~= nil and nearestWood.id == "Litter01")
		check("nothing worth pointing at returns nothing", Pointers.nearest(candidates, { OldCan = true }, Vector3.zero) == nil)
		local onboarding = Rules.newPlayerState()
		for _, resourceId in ipairs({ "Wood", "Wood", "Stone", "ScrapMetal", "OldCan" }) do table.insert(onboarding.storedItems, { itemId = "tutorial" .. tostring(#onboarding.storedItems + 1), resourceId = resourceId }) end
		check("five deposited tutorial items advance to guided sell", Rules.tutorialStep(onboarding) == 2 and Rules.snapshot(onboarding).tutorialDuplicateResourceId == "Wood")
		local wrongSell, wrongReason = Rules.sell(onboarding, "Stone", 1)
		check("tutorial only permits the single duplicate sale", not wrongSell and wrongReason == "TUTORIAL_SELL_ONE")
		local sold = Rules.sell(onboarding, "Wood", 1)
		check("selling one duplicate advances to AFK Sorter building", sold and Rules.tutorialStep(onboarding) == 3)
		local wrongTutorialCraft, wrongTutorialReason = Rules.craft(onboarding, "ScavengerSatchel")
		check("tutorial blocks other recipes before AFK Sorter", not wrongTutorialCraft and wrongTutorialReason == "TUTORIAL_CRAFT_AFK_SORTER")
		local crafted = Rules.craft(onboarding, "AFKSorter", 1000)
		check("AFK Sorter advances tutorial without changing carry", crafted and Rules.tutorialStep(onboarding) == 4 and Rules.carryCapacity(onboarding) == 5)
		local wrongTrack, wrongTrackReason = Rules.track(onboarding, "CarryRack", "ADD")
		check("tutorial requires tracking Collection Bin specifically", not wrongTrack and wrongTrackReason == "TUTORIAL_TRACK_COLLECTION_BIN")
		local tracked = Rules.track(onboarding, "CollectionBin", "ADD")
		check("tracking Collection Bin completes onboarding", tracked and Rules.tutorialStep(onboarding) == 5 and onboarding.trackedRecipeIds[1] == "CollectionBin")
		Rules.track(onboarding, "TrailBoots", "ADD"); Rules.track(onboarding, "HoardCrate", "ADD")
		local fourth, fourthReason = Rules.track(onboarding, "BiggerPlot", "ADD")
		check("tracking is capped at three", not fourth and fourthReason == "TRACKING_FULL" and #onboarding.trackedRecipeIds == 3)
		local focused = Rules.track(onboarding, "HoardCrate", "FOCUS")
		local removed = Rules.track(onboarding, "TrailBoots", "REMOVE")
		check("tracked goals focus and remove in server order", focused and removed and onboarding.trackedRecipeIds[1] == "HoardCrate" and #onboarding.trackedRecipeIds == 2)
		local trackedCraft = Rules.newPlayerState(); trackedCraft.tutorialStep = 5; trackedCraft.coins = 50; trackedCraft.trackedRecipeIds = { "ScavengerSatchel" }
		for index = 1, 3 do table.insert(trackedCraft.storedItems, { itemId = "trackedWood" .. index, resourceId = "Wood" }) end
		for index = 1, 2 do table.insert(trackedCraft.storedItems, { itemId = "trackedScrap" .. index, resourceId = "ScrapMetal" }) end
		table.insert(trackedCraft.storedItems, { itemId = "trackedCan", resourceId = "OldCan" })
		check("crafting removes its tracked recipe", Rules.craft(trackedCraft, "ScavengerSatchel") and #trackedCraft.trackedRecipeIds == 0)
		local migratedV2 = Rules.normalize({ version = 2, crafted = { CarryRack = true }, inventoryCounts = {} })
		check("version 2 saves gain satchel and skip onboarding", migratedV2.crafted.ScavengerSatchel == true and migratedV2.tutorialStep == 5)
		check("deposit effect uses exact marker colors", string.find(clientSource.DepositEffects.Source, "markerPulseColor", 1, true) ~= nil)
	end

	log("\n[7] live Edit geometry")
	do
		local Config = require(Shared:WaitForChild("Stage1Config"))
		local Workspace = game:GetService("Workspace")
		local hoard = Workspace:FindFirstChild("Hoard"); local field = if hoard then hoard:FindFirstChild("Field") else nil
		local paths = if hoard then hoard:FindFirstChild("Paths") else nil; local plots = if hoard then hoard:FindFirstChild("Plots") else nil
		check("Hoard hierarchy exists", hoard ~= nil and hoard:IsA("Model") and field ~= nil and paths ~= nil and plots ~= nil)
		check("field and bounds have exact scale", field ~= nil and sameVector((field.Ground :: BasePart).Size, Vector3.new(132, 1, 108)) and sameVector((field.LitterBounds :: BasePart).Size, Vector3.new(120, 0.2, 96)))
		check("old single Path is removed", hoard ~= nil and hoard:FindFirstChild("Path") == nil)
		for plotId = 1, 4 do
			local plot = if plots then plots:FindFirstChild(string.format("Plot%d", plotId)) else nil
			local path = if paths then paths:FindFirstChild(string.format("Path%d", plotId)) else nil
			local plotCFrame = Config.plotCFrame(plotId)
			local function localPosition(name: string): Vector3 return plotCFrame:PointToObjectSpace(((plot :: Model):FindFirstChild(name) :: BasePart).Position) end
			check(string.format("Plot%d exact attributes", plotId), plot ~= nil and plot:IsA("Model") and plot:GetAttribute("PlotId") == plotId and plot:GetAttribute("OwnerUserId") == 0 and plot:GetAttribute("ExpansionLevel") == 0 and plot:GetAttribute("StorageCapacity") == 60)
			check(string.format("Plot%d exact ground", plotId), plot ~= nil and sameVector(((plot :: Model).Ground :: BasePart).Size, Vector3.new(64, 1, 64)) and sameVector(localPosition("Ground"), Vector3.new(0, -0.5, 0)))
			check(string.format("Plot%d has expansion presentation hooks", plotId), plot ~= nil and (plot :: Model).Ground:GetAttribute("BaseSize") == 64 and (plot :: Model).Ground:GetAttribute("ExpandedSize") == 64)
			check(string.format("Plot%d exact deposit", plotId), plot ~= nil and sameVector(((plot :: Model).DepositZone :: BasePart).Size, Vector3.new(20, 6, 12)) and sameVector(localPosition("DepositZone"), Vector3.new(0, 3, -24)) and (plot :: Model).DepositMarker.Label.Text.Text == "DEPOSIT")
			check(string.format("Plot%d exact pile/spawn/workbench", plotId), plot ~= nil and sameVector(localPosition("PileOrigin"), Vector3.new(0, 0, -6)) and sameVector(localPosition("SpawnLocation"), Vector3.new(-18, 0.5, -18)) and sameVector(localPosition("Workbench"), Vector3.new(18, 1.5, -18)))
			check(string.format("Path%d exact local position", plotId), path ~= nil and path:IsA("BasePart") and sameVector(path.Size, Vector3.new(14, 0.18, if plotId % 2 == 1 then 24 else 22)) and sameVector(plotCFrame:PointToObjectSpace(path.Position), Vector3.new(0, -0.09, if plotId % 2 == 1 then -44 else -43)))
		end
		check("runtime folders begin empty", hoard ~= nil and hoard:FindFirstChild("Resources") ~= nil and hoard:FindFirstChild("Visuals") ~= nil and #hoard.Resources:GetChildren() == 0 and #hoard.Visuals:GetChildren() == 0)
		check("no pickup Highlight exists", Workspace:FindFirstChildWhichIsA("Highlight", true) == nil)
	end

	log(string.format("\n=== %d passed, %d failed ===", passed, failed))
	return table.concat(lines, "\n")
end
