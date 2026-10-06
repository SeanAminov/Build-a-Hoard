--!strict
-- Bounds remote work before handlers inspect payloads or construct response snapshots.
local Limiter = {}
local BURST, PER_SECOND = 20, 10
function Limiter.allow(buckets: {[any]: any}, key: any, now: number): boolean
	local row = buckets[key]
	if not row then row = { tokens = BURST, at = now }; buckets[key] = row end
	row.tokens = math.min(BURST, row.tokens + math.max(0, now - row.at) * PER_SECOND)
	row.at = now
	if row.tokens < 1 then return false end
	row.tokens -= 1
	return true
end
return table.freeze(Limiter)
