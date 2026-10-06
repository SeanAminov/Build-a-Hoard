--!strict
-- Derives the bounded, non-private plot view that every client is allowed to render.

local Config = require(script.Parent:WaitForChild("Stage1Config"))

local PublicState = {}

function PublicState.nextRevision(current: number): number
	assert(type(current) == "number" and current >= 0 and current % 1 == 0, "current revision must be a nonnegative integer")
	return current + 1
end

function PublicState.build(worldRevision: number, rowsByPlot: { [number]: any }): any
	assert(type(worldRevision) == "number" and worldRevision >= 0 and worldRevision % 1 == 0, "worldRevision must be a nonnegative integer")
	local plots = {}
	for plotId = 1, 4 do
		local source = rowsByPlot[plotId]
		if source ~= nil then
			local items = {}
			for index = 1, math.min(#source.pileResourceIds, Config.visiblePileCap) do
				local resourceId = source.pileResourceIds[index]
				if type(resourceId) == "string" then table.insert(items, resourceId) end
			end
			table.insert(plots, {
				plotId = plotId,
				ownerUserId = source.ownerUserId,
				displayName = source.displayName,
				expansionLevel = source.expansionLevel,
				hoardTotal = source.hoardTotal,
				storageCapacity = source.storageCapacity,
				passivePerSecond = source.passivePerSecond,
				pileResourceIds = items,
			})
		end
	end
	return { worldRevision = worldRevision, plots = plots }
end

function PublicState.shouldApply(currentRevision: number?, incomingRevision: number): boolean
	assert(type(incomingRevision) == "number" and incomingRevision >= 0 and incomingRevision % 1 == 0, "incoming revision must be a nonnegative integer")
	return currentRevision == nil or incomingRevision >= currentRevision
end

return table.freeze(PublicState)
