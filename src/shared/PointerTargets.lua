--!strict
--[[
	Pure target selection for the tutorial pointers.

	The arrow has to answer two questions every tenth of a second: what does this player still need,
	and which loose object is the closest one of those. `TutorialRules` answers the first; this
	answers the second. Both are pure functions of data the server already sent, so they live here
	rather than inside the renderer, where they could only be tested by playing the game.
]]

local PointerTargets = {}

export type Candidate = { id: string, resourceId: string, position: Vector3 }

-- Closest wanted candidate. Ties break on the lowest id, matching PickupController, so the arrow and
-- the pickup prompt can never disagree about which object is "the" nearest one.
function PointerTargets.nearest(candidates: { Candidate }, wanted: { [string]: boolean }, from: Vector3): Candidate?
	local best: Candidate? = nil
	local bestDistance = math.huge
	for _, candidate in ipairs(candidates) do
		if wanted[candidate.resourceId] then
			local distance = (from - candidate.position).Magnitude
			if distance < bestDistance or (distance == bestDistance and best ~= nil and candidate.id < (best :: Candidate).id) then
				best = candidate
				bestDistance = distance
			end
		end
	end
	return best
end

return table.freeze(PointerTargets)
