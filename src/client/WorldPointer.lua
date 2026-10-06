--!strict
-- Small world-space chevrons aim at the target; no camera-facing texture mapping.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Assets = require(script.Parent:WaitForChild("WorldArtAssets"))

local WorldPointer = {}
WorldPointer.__index = WorldPointer

local CREAM = Color3.fromRGB(255, 249, 222)
local INK = Color3.fromRGB(22, 56, 91)

-- PROTOTYPE PRESENTATION values.
local ARROW_SPACING = 1.8
local MAX_ARROWS = 32
local POPUP_HEIGHT = 4.2
local BADGE_HEIGHT = 2.8
local VIEW_DISTANCE = 320
-- The bubble art keeps its tail in the lower fifth, so text sits inside the body only.
local function setBubbleText(label: TextLabel, value: string)
	label.Text = value
	local width = label:GetAttribute("BodyWidth") :: number
	local maximum = label:GetAttribute("MaximumTextSize") :: number
	local measured = TextService:GetTextSize(value, maximum, label.Font, Vector2.new(width, 1000))
	local oneLine = TextService:GetTextSize("Ag", maximum, label.Font, Vector2.new(width, 1000))
	local wrapped = measured.Y > oneLine.Y * 1.4
	label.Position = UDim2.fromScale(0.18, if wrapped then 0.20 else 0.16)
	label.Size = UDim2.fromScale(0.64, if wrapped then 0.44 else 0.48)
end

local function bubble(parent: Instance, name: string, width: number, height: number, up: number, maximumTextSize: number): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromOffset(width, height)
	gui.StudsOffsetWorldSpace = Vector3.new(0, up, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = VIEW_DISTANCE
	gui.Parent = parent
	local card = Instance.new("ImageLabel")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.ScaleType = Enum.ScaleType.Stretch
	card.Parent = gui
	if Assets.TutorialBubble ~= "" then
		card.Image = Assets.TutorialBubble
	else
		-- Until the art is uploaded, a plain card keeps the words readable.
		card.BackgroundTransparency = 0
		card.BackgroundColor3 = CREAM
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = card
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = INK
		stroke.Thickness = 3
		stroke.Parent = card
	end
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	-- The four screws and orange side tabs are decoration, not usable text space. Keep copy in the
	-- cream centre so long resource names and two-line instructions never collide with the frame.
	label.Position = UDim2.fromScale(0.18, 0.16)
	label.Size = UDim2.fromScale(0.64, 0.48)
	label:SetAttribute("BodyWidth", width * 0.64)
	label:SetAttribute("MaximumTextSize", maximumTextSize)
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = INK
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = ""
	label.Parent = card
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 10
	limit.MaxTextSize = maximumTextSize
	limit.Parent = label
	return gui, label
end

function WorldPointer.new(): any
	local self = setmetatable({
		character = nil, origin = nil, destination = nil, beam = nil,
		popup = nil, popupLabel = nil, badge = nil, badgeLabel = nil, target = nil,
	}, WorldPointer)
	self.frameConnection = RunService.RenderStepped:Connect(function() self:updateArrows() end)
	return self
end

function WorldPointer:setCharacter(character: Model?)
	self:releaseOrigin()
	self.character = character
end

function WorldPointer:releaseOrigin()
	self:clearTarget()
	if self.popup ~= nil then self.popup:Destroy() end
	if self.origin ~= nil then self.origin:Destroy() end
	self.popup = nil
	self.popupLabel = nil
	self.origin = nil
end

--[[
	Resolve the root part lazily, every time it is needed.

	CharacterAdded fires before the character's parts have replicated, so looking HumanoidRootPart up
	once at that moment usually finds nothing, and a pointer built that way would stay silently dead
	for the whole life of the character. CarryRenderer resolves its Head the same way, on demand.
]]
function WorldPointer:ensureOrigin(): Attachment?
	local character = self.character
	if character == nil or character.Parent == nil then
		if self.origin ~= nil then self:releaseOrigin() end
		return nil
	end
	local existing = self.origin
	if existing ~= nil and existing.Parent ~= nil and existing:IsDescendantOf(character) then return existing end
	if existing ~= nil then self:releaseOrigin() end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then return nil end
	local origin = Instance.new("Attachment")
	origin.Name = "TutorialPointerOrigin"
	origin.Position = Vector3.new(0, 1, 0)
	origin.Parent = root
	self.origin = origin
	local popup, popupLabel = bubble(origin, "TutorialPopup", 280, 140, POPUP_HEIGHT, 25)
	popup.Enabled = false
	self.popup = popup
	self.popupLabel = popupLabel
	return origin
end

function WorldPointer:clearTarget()
	if self.beam ~= nil then self.beam:Destroy(); self.beam = nil end
	if self.badge ~= nil then self.badge:Destroy(); self.badge = nil end
	if self.destination ~= nil then self.destination:Destroy(); self.destination = nil end
	self.badgeLabel = nil
	self.target = nil
end

function WorldPointer:pointTo(target: BasePart, color: Color3, targetText: string, instruction: string)
	local origin = self:ensureOrigin()
	if origin == nil or target.Parent == nil then return end
	if self.target ~= target then
		self:clearTarget()
		local destination = Instance.new("Attachment")
		destination.Name = "TutorialPointerTarget"
		destination.Position = Vector3.new(0, 1.5, 0)
		destination.Parent = target
		local beam = Instance.new("Folder")
		beam.Name = "TutorialTrail"
		beam.Parent = origin
		local badge, badgeLabel = bubble(destination, "TutorialTargetBadge", 160, 80, BADGE_HEIGHT, 19)
		self.beam = beam
		self.destination = destination
		self.badge = badge
		self.badgeLabel = badgeLabel
		self.target = target
	end
	-- World-space chevrons keep their direction as the camera moves.
	self:updateArrows()
	if self.badgeLabel ~= nil then setBubbleText(self.badgeLabel, targetText) end
	if self.popupLabel ~= nil then setBubbleText(self.popupLabel, instruction) end
	if self.popup ~= nil then self.popup.Enabled = true end
end

function WorldPointer:updateArrows()
	if not self.beam or not self.origin or not self.destination then return end
	local start = self.origin.WorldPosition - Vector3.new(0, 3.4, 0)
	local goal = Vector3.new(self.destination.WorldPosition.X, start.Y, self.destination.WorldPosition.Z)
	local delta = goal - start
	if delta.Magnitude < 1 then self.beam:ClearAllChildren(); return end
	local direction = delta.Unit
	local count = math.min(MAX_ARROWS, math.max(0, math.floor((delta.Magnitude - 1) / ARROW_SPACING)))
	for _, child in self.beam:GetChildren() do if (tonumber(child.Name) or 0) > count then child:Destroy() end end
	for index = 1, count do
		local arrow = self.beam:FindFirstChild(tostring(index))
		if not arrow then
			arrow = Instance.new("Model"); arrow.Name = tostring(index)
			for _, side in ipairs({-1, 1}) do
				local tip = Vector3.new(0, 0, -.3)
				local tail = Vector3.new(side * .32, 0, .3)
				local part = Instance.new("Part"); part.Name = "Arm"
				part.Size = Vector3.new(.13, .065, (tip-tail).Magnitude)
				part.CFrame = CFrame.lookAt((tip+tail)/2, tip)
				part.Anchored = true; part.CanCollide = false; part.CanTouch = false; part.CanQuery = false
				part.Color = Color3.new(1,1,1); part.Material = Enum.Material.SmoothPlastic
				part.TopSurface = Enum.SurfaceType.Smooth; part.BottomSurface = Enum.SurfaceType.Smooth
				part.Parent = arrow
			end
			arrow.WorldPivot = CFrame.new()
			arrow.Parent = self.beam
		end
		local position = start + direction * (index * ARROW_SPACING)
		arrow:PivotTo(CFrame.lookAt(position, position + direction))
	end
end

function WorldPointer:hide()
	self:clearTarget()
	if self.popup ~= nil then self.popup.Enabled = false end
end

function WorldPointer:destroy()
	if self.frameConnection then self.frameConnection:Disconnect() end
	self:releaseOrigin()
	self.character = nil
end

return WorldPointer
