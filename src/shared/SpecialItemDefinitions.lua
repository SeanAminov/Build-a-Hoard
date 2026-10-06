--!strict
-- Protected collectibles live outside normal carry and Hoard capacity.

export type SpecialItemDefinition = {
	id: string,
	displayName: string,
	order: number,
}

local rows: { [string]: SpecialItemDefinition } = {
	BasicGem = { id = "BasicGem", displayName = "Basic Gem", order = 1 },
}

local function validate(candidate: { [string]: SpecialItemDefinition }, expectedCount: number?): true
	local count = 0
	local orders: { [number]: boolean } = {}
	for key, row in pairs(candidate) do
		count += 1
		assert(row.id == key and key ~= "", "special item id must match its key")
		assert(type(row.displayName) == "string" and row.displayName ~= "", "special item needs a display name")
		assert(type(row.order) == "number" and row.order > 0 and row.order % 1 == 0 and not orders[row.order], "special item order must be unique")
		orders[row.order] = true
	end
	if expectedCount ~= nil then assert(count == expectedCount, "unexpected special item count") end
	return true
end

validate(rows, 1)
for _, row in pairs(rows) do table.freeze(row) end
table.freeze(rows)

local SpecialItemDefinitions = { rows = rows }
function SpecialItemDefinitions.get(itemId: string): SpecialItemDefinition? return rows[itemId] end
function SpecialItemDefinitions.validate(candidate: { [string]: SpecialItemDefinition }?, expectedCount: number?): true return validate(candidate or rows, expectedCount or 1) end
function SpecialItemDefinitions.ordered(): { SpecialItemDefinition }
	local result = {}
	for _, row in pairs(rows) do table.insert(result, row) end
	table.sort(result, function(a, b) return a.order < b.order end)
	return result
end
return table.freeze(SpecialItemDefinitions)
