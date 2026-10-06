--!strict
--[[
	Pure Stage 0 state transitions. HoardService supplies trusted player context and owns the live
	state; tests use synthetic context to exercise these exact rules without Play mode.
]]

local Stage0Config = require(script.Parent:WaitForChild("Stage0Config"))

export type ItemRow = { itemId: string, resourceId: string }
export type LitterState = {
	litterId: string,
	resourceId: string,
	position: Vector3,
	yaw: number,
	generation: number,
	available: boolean,
	respawnAt: number?,
}
export type State = {
	revision: number,
	carry: { ItemRow },
	hoardCounts: { [string]: number },
	pileItems: { ItemRow },
	litter: { [string]: LitterState },
	litterOrder: { string },
	lastSuccessfulPickupTime: number?,
}
export type PickupRequest = {
	itemId: string,
	now: number,
	rootPosition: Vector3,
	alive: boolean,
	isOwner: boolean,
}
export type DepositContext = { rootPosition: Vector3, alive: boolean, isOwner: boolean }

local HoardRules = {}

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function currentItemId(litter: LitterState): string
	return string.format("%s:%d", litter.litterId, litter.generation)
end

local function itemRow(litter: LitterState): ItemRow
	return { itemId = currentItemId(litter), resourceId = litter.resourceId }
end

local function findLitterForItem(state: State, itemId: string): LitterState?
	local separator = string.find(itemId, ":", 1, true)
	if separator == nil then return nil end
	return state.litter[string.sub(itemId, 1, separator - 1)]
end

function HoardRules.newState(seed: number?): State
	local state: State = {
		revision = 0,
		carry = {},
		hoardCounts = { Wood = 0, ScrapMetal = 0 },
		pileItems = {},
		litter = {},
		litterOrder = {},
		lastSuccessfulPickupTime = nil,
	}
	for _, definition in ipairs(Stage0Config.generateLitter(seed or Stage0Config.litterSeedBase)) do
		state.litter[definition.litterId] = {
			litterId = definition.litterId,
			resourceId = definition.resourceId,
			position = definition.position,
			yaw = definition.yaw,
			generation = 1,
			available = true,
			respawnAt = nil,
		}
		table.insert(state.litterOrder, definition.litterId)
	end
	return state
end

function HoardRules.pickUp(state: State, request: PickupRequest): (boolean, string)
	if type(request) ~= "table" or type(request.itemId) ~= "string" or #request.itemId > 64 then
		return false, "MALFORMED_ITEM"
	end
	if type(request.now) ~= "number" or not finite(request.now) or typeof(request.rootPosition) ~= "Vector3" then
		return false, "INVALID_CONTEXT"
	end
	if not request.isOwner then return false, "NOT_OWNER" end
	if not request.alive then return false, "NOT_ALIVE" end
	local litter = findLitterForItem(state, request.itemId)
	if litter == nil or not litter.available or currentItemId(litter) ~= request.itemId then
		return false, "ITEM_UNAVAILABLE"
	end
	if (request.rootPosition - litter.position).Magnitude > Stage0Config.pickupRange then
		return false, "TOO_FAR"
	end
	if #state.carry >= Stage0Config.carryCapacity then return false, "CARRY_FULL" end
	if state.lastSuccessfulPickupTime ~= nil and request.now - state.lastSuccessfulPickupTime < Stage0Config.successfulPickupInterval then
		return false, "TOO_FAST"
	end

	litter.available = false
	litter.respawnAt = request.now + Stage0Config.respawnTime
	table.insert(state.carry, itemRow(litter))
	state.lastSuccessfulPickupTime = request.now
	state.revision += 1
	return true, "PICKED_UP"
end

function HoardRules.respawnDue(state: State, now: number): { ItemRow }
	assert(type(now) == "number" and finite(now), "now must be finite")
	local respawned: { ItemRow } = {}
	for _, litterId in ipairs(state.litterOrder) do
		local litter = state.litter[litterId]
		if not litter.available and litter.respawnAt ~= nil and now >= litter.respawnAt then
			litter.generation += 1
			litter.available = true
			litter.respawnAt = nil
			table.insert(respawned, itemRow(litter))
		end
	end
	return respawned
end

local function insideDepositZone(point: Vector3): boolean
	local localPoint = point - Stage0Config.depositZonePosition
	local half = Stage0Config.depositZoneSize / 2
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

function HoardRules.deposit(state: State, context: DepositContext): (boolean, string, number)
	if type(context) ~= "table" or typeof(context.rootPosition) ~= "Vector3" then
		return false, "INVALID_CONTEXT", 0
	end
	if not context.isOwner then return false, "NOT_OWNER", 0 end
	if not context.alive then return false, "NOT_ALIVE", 0 end
	if not insideDepositZone(context.rootPosition) then return false, "OUTSIDE_ZONE", 0 end
	if #state.carry == 0 then return false, "EMPTY", 0 end

	local deposited = #state.carry
	for _, item in ipairs(state.carry) do
		state.hoardCounts[item.resourceId] = (state.hoardCounts[item.resourceId] or 0) + 1
		if #state.pileItems < Stage0Config.visiblePileCap then
			table.insert(state.pileItems, { itemId = item.itemId, resourceId = item.resourceId })
		end
	end
	table.clear(state.carry)
	state.revision += 1
	return true, "DEPOSITED", deposited
end

function HoardRules.loseCarry(state: State): (boolean, string, number)
	if #state.carry == 0 then return false, "EMPTY", 0 end
	local lost = #state.carry
	table.clear(state.carry)
	state.revision += 1
	return true, "CARRY_LOST", lost
end

function HoardRules.snapshot(state: State): { [string]: any }
	local carry: { ItemRow } = {}
	for _, item in ipairs(state.carry) do
		table.insert(carry, { itemId = item.itemId, resourceId = item.resourceId })
	end
	local pileItems: { ItemRow } = {}
	for _, item in ipairs(state.pileItems) do
		table.insert(pileItems, { itemId = item.itemId, resourceId = item.resourceId })
	end
	local hoardCounts = { Wood = state.hoardCounts.Wood or 0, ScrapMetal = state.hoardCounts.ScrapMetal or 0 }
	return {
		revision = state.revision,
		carry = carry,
		hoardCounts = hoardCounts,
		hoardTotal = hoardCounts.Wood + hoardCounts.ScrapMetal,
		pileItems = pileItems,
		capacity = Stage0Config.carryCapacity,
	}
end

function HoardRules.currentItemId(state: State, litterId: string): string?
	local litter = state.litter[litterId]
	if litter == nil or not litter.available then return nil end
	return currentItemId(litter)
end

return table.freeze(HoardRules)
