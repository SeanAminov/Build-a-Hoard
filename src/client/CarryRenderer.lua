--!strict
-- The exaggerated overhead stack is a local view of the latest server carry snapshot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PresentationLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PresentationLayout"))
local ResourceDefinitions = require(ReplicatedStorage.Shared:WaitForChild("ResourceDefinitions"))
local ResourceVisuals = require(ReplicatedStorage.Shared:WaitForChild("ResourceVisuals"))

local CarryRenderer = {}
CarryRenderer.__index = CarryRenderer

function CarryRenderer.new(): any
	return setmetatable({ character = nil, latest = nil }, CarryRenderer)
end

function CarryRenderer:setCharacter(character: Model?)
	self.character = character
	if self.latest ~= nil then self:render(self.latest) end
end

function CarryRenderer:render(snapshot: any)
	self.latest = snapshot
	local character = self.character
	if character == nil or character.Parent == nil then return end
	local existing = character:FindFirstChild("CarryStack")
	if existing ~= nil then existing:Destroy() end
	local head = character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then return end
	local folder = Instance.new("Folder")
	folder.Name = "CarryStack"
	folder.Parent = character
	for index, item in ipairs(snapshot.carry or {}) do
		local definition = ResourceDefinitions.get(item.resourceId)
		if definition ~= nil then
			local part = Instance.new("Part")
			part.Name = string.format("Slot%d", index)
			part.Size = definition.size
			part.Massless = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = true
			part.CFrame = head.CFrame * CFrame.new(PresentationLayout.carryOffset(index, head.Size.Y))
			part:SetAttribute("ResourceId", item.resourceId)
			part:SetAttribute("ItemId", item.itemId)
			part.Parent = folder
			ResourceVisuals.decorate(part, item.resourceId)
			local weld = Instance.new("WeldConstraint")
			weld.Name = "HeadWeld"
			weld.Part0 = head
			weld.Part1 = part
			weld.Parent = part
		end
	end
end

return CarryRenderer
