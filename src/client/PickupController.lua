--!strict
-- Keeps exactly one local contextual prompt on the nearest replicated eligible resource.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ResourceDefinitions = require(Shared:WaitForChild("ResourceDefinitions"))
local SpecialItemDefinitions = require(Shared:WaitForChild("SpecialItemDefinitions"))
local Config = require(Shared:WaitForChild("Stage1Config"))

local PickupController = {}
PickupController.__index = PickupController

function PickupController.new(actionRemote: RemoteEvent): any
	local self = setmetatable({ actionRemote = actionRemote, enabled = false, target = nil, connection = nil, running = true }, PickupController)
	task.spawn(function()
		while self.running do
			self:refresh()
		task.wait(Config.targetRefreshInterval)
		end
	end)
	return self
end

function PickupController:clearTarget()
	if self.connection ~= nil then self.connection:Disconnect(); self.connection = nil end
	if self.target ~= nil then
		local prompt = self.target:FindFirstChild("PickupPrompt")
		if prompt ~= nil then prompt:Destroy() end
	end
	self.target = nil
end

function PickupController:setEnabled(enabled: boolean)
	self.enabled = enabled
	if not enabled then self:clearTarget() end
end

function PickupController:refresh()
	if not self.enabled then return end
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		self:clearTarget()
		return
	end
	local hoard = Workspace:FindFirstChild("Hoard")
	local resources = if hoard then hoard:FindFirstChild("Resources") else nil
	local specialDrops = if hoard then hoard:FindFirstChild("SpecialDrops") else nil
	if resources == nil and specialDrops == nil then self:clearTarget(); return end
	local best: BasePart? = nil
	local bestDistance = math.huge
	local bestLitterId = ""
	local candidates = {}
	if resources then for _, child in ipairs(resources:GetChildren()) do table.insert(candidates, child) end end
	if specialDrops then for _, child in ipairs(specialDrops:GetChildren()) do table.insert(candidates, child) end end
	for _, child in ipairs(candidates) do
		if child:IsA("BasePart") and type(child:GetAttribute("ItemId")) == "string" then
			local distance = (root.Position - child.Position).Magnitude
			local litterId = tostring(child:GetAttribute("LitterId") or child.Name)
			if distance <= Config.promptRange and (distance < bestDistance or (distance == bestDistance and litterId < bestLitterId)) then
				best = child
				bestDistance = distance
				bestLitterId = litterId
			end
		end
	end
	if best == self.target and best ~= nil then return end
	self:clearTarget()
	if best == nil then return end
	self.target = best
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = "Pick Up"
	local resourceId = tostring(best:GetAttribute("ResourceId") or "")
	local specialItemId = tostring(best:GetAttribute("SpecialItemId") or "")
	local definition = ResourceDefinitions.get(resourceId)
	local specialDefinition = SpecialItemDefinitions.get(specialItemId)
	prompt.ObjectText = if specialDefinition then specialDefinition.displayName elseif definition then definition.displayName else "Resource"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.promptRange
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Parent = best
	self.connection = prompt.Triggered:Connect(function()
		local itemId = best:GetAttribute("ItemId")
		if type(itemId) == "string" then
			self.actionRemote:FireServer(if specialItemId ~= "" then "PICK_UP_SPECIAL" else "PICK_UP", itemId)
		end
	end)
end

function PickupController:destroy()
	self.running = false
	self:clearTarget()
end

return PickupController
