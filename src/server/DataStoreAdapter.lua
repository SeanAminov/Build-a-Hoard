--!strict
-- Keeps Studio usable before publishing and prevents two live servers from writing one profile.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MemoryStore = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MemoryStore"))

local DataStoreAdapter = {}
DataStoreAdapter.__index = DataStoreAdapter

local SAVE_VERSION = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Stage5Config")).dataVersion
local Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionRules"))
local PROFILE_FORMAT = 1
local LEASE_SECONDS = 180

local function keyFor(userId: number): string
	return string.format("player_%d", userId)
end

local function unpackProfile(value: any): (any, string?, number)
	if type(value) == "table" and value.__buildAHoardProfile == PROFILE_FORMAT then
		return value.data, if type(value.sessionId) == "string" then value.sessionId else nil,
			if type(value.sessionTouchedAt) == "number" then value.sessionTouchedAt else 0
	end
	-- Saves written before profile leases are valid and migrate on the next successful write.
	return value, nil, 0
end

-- Older servers must not downgrade saves from a newer release during rollouts or rollbacks.
local function readableProfile(value: any): boolean
	if value == nil then return true end
	if type(value) ~= "table" then return false end
	if value.__buildAHoardProfile ~= nil and value.__buildAHoardProfile ~= PROFILE_FORMAT then return false end
	local data = unpackProfile(value)
	if data == nil then return value.__buildAHoardProfile == PROFILE_FORMAT end
	if type(data) ~= "table" then return false end
	local version = data.version
	return version == nil or (type(version) == "number" and version % 1 == 0 and version >= 1 and version <= SAVE_VERSION)
end

local function packProfile(data: any, sessionId: string?, touchedAt: number): any
	return {
		__buildAHoardProfile = PROFILE_FORMAT,
		data = data,
		sessionId = sessionId,
		sessionTouchedAt = touchedAt,
	}
end

function DataStoreAdapter.new(forceMemory: boolean?): any
	local useMemory = forceMemory == true or RunService:IsStudio() or game.PlaceId == 0
	local backing = if useMemory then MemoryStore.new() else DataStoreService:GetDataStore("BuildAHoard_Player_v1")
	local jobId = if type(game.JobId) == "string" and game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false)
	return setmetatable({
		useMemory = useMemory,
		backing = backing,
		sessionId = jobId,
		loaded = {},
		saving = {},
		saveSequence = {},
		savedSequence = {},
	}, DataStoreAdapter)
end

function DataStoreAdapter:load(userId: number): (boolean, any, string?)
	local key = keyFor(userId)
	self.loaded[userId] = nil
	if self.useMemory then
		self.loaded[userId] = true
		return true, self.backing:load(key), nil
	end

	for attempt = 1, 3 do
		local now = os.time()
		local blocked = false
		local incompatible = false
		local ok, updated = pcall(function()
			return self.backing:UpdateAsync(key, function(current: any)
				if not readableProfile(current) then incompatible = true; return nil end
				local data, owner, touchedAt = unpackProfile(current)
				if owner ~= nil and owner ~= self.sessionId and now - touchedAt < LEASE_SECONDS then
					blocked = true
					return nil
				end
				-- A retry from this same acquisition must not grant the interval again.
				if owner ~= self.sessionId then
					local state = Rules.normalize(data)
					Rules.creditOfflineIncome(state, now)
					data = Rules.serialize(state, now)
				end
				return packProfile(data, self.sessionId, now)
			end)
		end)
		if ok then
			if incompatible then return false, nil, "INCOMPATIBLE_SAVE" end
			if blocked or updated == nil then return false, nil, "SESSION_ACTIVE" end
			local data, owner = unpackProfile(updated)
			if owner == self.sessionId then
				self.loaded[userId] = true
				return true, data, nil
			end
			return false, nil, "SESSION_ACTIVE"
		end
		if attempt < 3 then task.wait(attempt) end
	end
	return false, nil, "LOAD_FAILED"
end

function DataStoreAdapter:_commit(userId: number, value: any, release: boolean): boolean
	-- Never replace unknown saved progress with a fresh state after loading failed or ownership changed.
	if not self.loaded[userId] then return false end
	local sequence = (self.saveSequence[userId] or 0) + 1
	self.saveSequence[userId] = sequence
	while self.saving[userId] do task.wait() end
	if not self.loaded[userId] then return false end
	if sequence < (self.savedSequence[userId] or 0) then return true end
	self.saving[userId] = true
	local key = keyFor(userId)

	if self.useMemory then
		local ok = self.backing:save(key, value)
		if ok then
			self.savedSequence[userId] = sequence
			if release then self.loaded[userId] = nil end
		end
		self.saving[userId] = nil
		return ok
	end

	for attempt = 1, 3 do
		local now = os.time()
		local ownsProfile = true
		local ok, updated = pcall(function()
			return self.backing:UpdateAsync(key, function(current: any)
				if not readableProfile(current) then ownsProfile = false; return nil end
				local _, owner = unpackProfile(current)
				if owner ~= self.sessionId then
					ownsProfile = false
					return nil
				end
				return packProfile(value, if release then nil else self.sessionId, now)
			end)
		end)
		if ok then
			local _, owner = unpackProfile(updated)
			local expectedOwner = if release then nil else self.sessionId
			if ownsProfile and updated ~= nil and owner == expectedOwner then
				self.savedSequence[userId] = sequence
				if release then self.loaded[userId] = nil end
				self.saving[userId] = nil
				return true
			end
			self.loaded[userId] = nil
			self.saving[userId] = nil
			return false
		end
		if attempt < 3 then task.wait(attempt) end
	end
	self.saving[userId] = nil
	return false
end

function DataStoreAdapter:save(userId: number, value: any): boolean
	return self:_commit(userId, value, false)
end

function DataStoreAdapter:release(userId: number, value: any): boolean
	return self:_commit(userId, value, true)
end

return DataStoreAdapter
