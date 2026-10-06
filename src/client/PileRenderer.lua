--!strict
-- Renders every occupied plot from the bounded public snapshot; private inventory never enters this view.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Stage1Config"))
local Stage2Config = require(Shared:WaitForChild("Stage2Config"))
local Layout = require(Shared:WaitForChild("PresentationLayout"))
local PublicState = require(Shared:WaitForChild("PublicState"))
local Resources = require(Shared:WaitForChild("ResourceDefinitions"))
local ResourceVisuals = require(Shared:WaitForChild("ResourceVisuals"))

local PileRenderer = {}; PileRenderer.__index = PileRenderer

local function worldFolders(plotId: number): (Folder?, BasePart?, BasePart?)
	local hoard = Workspace:FindFirstChild("Hoard"); local visuals = if hoard then hoard:FindFirstChild("Visuals") else nil; local plots = if hoard then hoard:FindFirstChild("Plots") else nil; local plot = if plots then plots:FindFirstChild(string.format("Plot%d", plotId)) else nil
	local origin = if plot then plot:FindFirstChild("PileOrigin") else nil; local ground = if plot then plot:FindFirstChild("Ground") else nil
	if visuals == nil or not visuals:IsA("Folder") or origin == nil or not origin:IsA("BasePart") or ground == nil or not ground:IsA("BasePart") then return nil, nil, nil end
	local plotFolder = visuals:FindFirstChild(string.format("Plot%d", plotId)) or Instance.new("Folder"); plotFolder.Name = string.format("Plot%d", plotId); plotFolder.Parent = visuals
	local pile = plotFolder:FindFirstChild("Pile") or Instance.new("Folder"); pile.Name = "Pile"; pile.Parent = plotFolder
	return pile :: Folder, origin, ground
end

local function ownerLabel(pile: Folder, origin: BasePart): TextLabel
	local billboard = pile.Parent:FindFirstChild("OwnerLabel") or Instance.new("BillboardGui")
	billboard.Name = "OwnerLabel"; (billboard :: BillboardGui).Adornee = origin; (billboard :: BillboardGui).AlwaysOnTop = true; (billboard :: BillboardGui).MaxDistance = 100; (billboard :: BillboardGui).StudsOffset = Vector3.new(0, 7, 0); (billboard :: BillboardGui).Size = UDim2.fromOffset(240, 58); billboard.Parent = pile.Parent
	local text = billboard:FindFirstChild("Text") or Instance.new("TextLabel"); text.Name = "Text"; (text :: TextLabel).Size = UDim2.fromScale(1, 1); (text :: TextLabel).BackgroundColor3 = Color3.fromRGB(255, 236, 194); (text :: TextLabel).BackgroundTransparency = 0.1; (text :: TextLabel).TextColor3 = Color3.fromRGB(82, 43, 28); (text :: TextLabel).Font = Enum.Font.FredokaOne; (text :: TextLabel).TextSize = 16; (text :: TextLabel).TextWrapped = true; text.Parent = billboard
	if text:FindFirstChildOfClass("UICorner") == nil then local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 10); corner.Parent = text end
	return text :: TextLabel
end

function PileRenderer.new(): any return setmetatable({ revision = nil, previousCounts = {}, activeTweens = {} }, PileRenderer) end

function PileRenderer:_removeObject(object: Instance)
	local tween = self.activeTweens[object]
	if tween then tween:Cancel(); self.activeTweens[object] = nil end
	object:Destroy()
end

function PileRenderer:renderPublic(packet: any)
	if type(packet) ~= "table" or type(packet.worldRevision) ~= "number" or not PublicState.shouldApply(self.revision, packet.worldRevision) then return end
	self.revision = packet.worldRevision
	local occupied: { [number]: boolean } = {}
	for _, row in ipairs(packet.plots or {}) do
		if type(row.plotId) == "number" and row.plotId >= 1 and row.plotId <= 4 then
			occupied[row.plotId] = true
			local pile, origin, ground = worldFolders(row.plotId)
			if pile and origin and ground then
				local targetSize = if row.expansionLevel == 1 then Stage2Config.expandedGroundSize else Stage2Config.baseGroundSize
				if not (ground.Size == Vector3.new(targetSize, 1, targetSize)) then TweenService:Create(ground, TweenInfo.new(Stage2Config.expansionDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(targetSize, 1, targetSize) }):Play() end
				ownerLabel(pile, origin).Text = string.format("%s\nHoard %d/%d  •  +$%.1f/sec", tostring(row.displayName), row.hoardTotal or 0, row.storageCapacity or 0, row.passivePerSecond or 0)
				local ids = row.pileResourceIds or {}; local count = math.min(#ids, Config.visiblePileCap); local previousCount = self.previousCounts[row.plotId] or 0
				for _, child in ipairs(pile:GetChildren()) do local index = tonumber(string.match(child.Name, "^Item(%d+)$")); if index == nil or index > count then self:_removeObject(child) end end
				for index = 1, count do
					local resourceId = ids[index]; local definition = Resources.get(resourceId)
					if definition then
						local name = string.format("Item%03d", index); local object = pile:FindFirstChild(name)
						if object and (not object:IsA("Part") or object:GetAttribute("ResourceId") ~= resourceId) then self:_removeObject(object); object = nil end
						local isNew = object == nil
						if object == nil then object = Instance.new("Part"); object.Name = name; object.Anchored = true; object.CanCollide = false; object.CanTouch = false; object.CanQuery = false; object:SetAttribute("ResourceId", resourceId); object.Parent = pile end
						local typed = object :: Part
						typed.Size = definition.size
						local target = origin.CFrame * Layout.pileTransform(index, resourceId)
						if isNew and index > previousCount then
							typed.CFrame = target + Vector3.new(0, Config.depositDropHeight, 0)
							ResourceVisuals.decorate(typed, resourceId)
							local tween = TweenService:Create(typed, TweenInfo.new(Config.depositDropDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = target }); self.activeTweens[typed] = tween; tween.Completed:Connect(function() if self.activeTweens[typed] == tween then self.activeTweens[typed] = nil end end); tween:Play()
						elseif self.activeTweens[typed] == nil then
							typed.CFrame = target
							if isNew then ResourceVisuals.decorate(typed, resourceId) end
						end
					end
				end
				self.previousCounts[row.plotId] = count
			end
		end
	end
	local hoard = Workspace:FindFirstChild("Hoard"); local visuals = if hoard then hoard:FindFirstChild("Visuals") else nil
	for plotId = 1, 4 do
		if not occupied[plotId] then
			local folder = if visuals then visuals:FindFirstChild(string.format("Plot%d", plotId)) else nil
			if folder then
				local pile = folder:FindFirstChild("Pile")
				if pile then for _, object in ipairs(pile:GetChildren()) do self:_removeObject(object) end end
				folder:Destroy()
			end
			local plots = if hoard then hoard:FindFirstChild("Plots") else nil; local plot = if plots then plots:FindFirstChild(string.format("Plot%d", plotId)) else nil; local ground = if plot then plot:FindFirstChild("Ground") else nil
			if ground and ground:IsA("BasePart") then ground.Size = Vector3.new(Stage2Config.baseGroundSize, 1, Stage2Config.baseGroundSize) end
			self.previousCounts[plotId] = 0
		end
	end
end

function PileRenderer:destroy()
	for _, tween in pairs(self.activeTweens) do tween:Cancel() end
	local hoard = Workspace:FindFirstChild("Hoard"); local visuals = if hoard then hoard:FindFirstChild("Visuals") else nil; if visuals then visuals:ClearAllChildren() end
	table.clear(self.activeTweens)
end

return PileRenderer
