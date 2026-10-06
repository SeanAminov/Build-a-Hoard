--!strict
-- Presentation derives geometry from authoritative snapshots and never mutates gameplay state.

local ResourceDefinitions = require(script.Parent:WaitForChild("ResourceDefinitions"))
local Config = require(script.Parent:WaitForChild("Stage1Config"))

local PresentationLayout = {}

function PresentationLayout.carryOffset(slotIndex: number, headSizeY: number): Vector3
	assert(slotIndex % 1 == 0 and slotIndex >= 1 and slotIndex <= Config.stage3CarryCapacity, "invalid carry slot")
	assert(type(headSizeY) == "number" and headSizeY > 0, "headSizeY must be positive")
	local offset = Config.carryOffsets[slotIndex]
	return Vector3.new(offset.X, offset.Y + headSizeY / 2, offset.Z)
end

function PresentationLayout.pileTransform(slotIndex: number, resourceId: string): CFrame
	assert(slotIndex % 1 == 0 and slotIndex >= 1 and slotIndex <= Config.visiblePileCap, "invalid pile slot")
	local definition = ResourceDefinitions.get(resourceId)
	assert(definition ~= nil, "unknown resourceId: " .. tostring(resourceId))
	local k = slotIndex - 1
	local column = k % 8
	local row = math.floor(k / 8) % 6
	local layer = math.floor(k / 48)
	local position = Vector3.new((column - 3.5) * 3, layer * 1.2 + definition.size.Y / 2, (row - 2.5) * 3)
	return CFrame.new(position) * CFrame.Angles(0, math.rad(Config.pileYaws[column + 1]), 0)
end

function PresentationLayout.visibleCount(total: number): number
	assert(type(total) == "number" and total >= 0 and total % 1 == 0, "total must be a nonnegative integer")
	return math.min(total, Config.visiblePileCap)
end

function PresentationLayout.shouldApplySnapshot(currentSessionId: number?, currentRevision: number?, incomingSessionId: number, incomingRevision: number): boolean
	assert(type(incomingSessionId) == "number" and incomingSessionId >= 1 and incomingSessionId % 1 == 0, "invalid incoming session")
	assert(type(incomingRevision) == "number" and incomingRevision >= 0 and incomingRevision % 1 == 0, "invalid incoming revision")
	if currentSessionId == nil or currentRevision == nil then return true end
	if incomingSessionId ~= currentSessionId then return incomingSessionId > currentSessionId end
	return incomingRevision >= currentRevision
end

return table.freeze(PresentationLayout)
