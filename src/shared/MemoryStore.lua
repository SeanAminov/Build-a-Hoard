--!strict
-- Process-local persistence used in Studio and tests. Copies prevent callers from sharing state.

local MemoryStore = {}
MemoryStore.__index = MemoryStore

local function deepCopy(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[deepCopy(key)] = deepCopy(child) end
	return result
end

function MemoryStore.new(): any return setmetatable({ values = {} }, MemoryStore) end
function MemoryStore:load(key: string): any return deepCopy(self.values[key]) end
function MemoryStore:save(key: string, value: any): boolean self.values[key] = deepCopy(value); return true end

return table.freeze(MemoryStore)
