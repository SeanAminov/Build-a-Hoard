--!strict
-- Four blockers leave one deliberate hole around the next tutorial control.

local RunService = game:GetService("RunService")

local Overlay = {}
Overlay.__index = Overlay

function Overlay.new(parent: Instance): any
	local root = Instance.new("Frame")
	root.Name = "TutorialFocus"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.ZIndex = 90
	root.Visible = false
	root.Parent = parent
	local blockers = {}
	for index = 1, 4 do
		local blocker = Instance.new("TextButton")
		blocker.Name = "Blocker" .. index
		blocker.Text = ""
		blocker.AutoButtonColor = false
		blocker.BackgroundColor3 = Color3.new(0, 0, 0)
		blocker.BackgroundTransparency = 0.45
		blocker.BorderSizePixel = 0
		blocker.ZIndex = 90
		blocker.Parent = root
		table.insert(blockers, blocker)
	end
	local focus = Instance.new("Frame")
	focus.Name = "FocusOutline"
	focus.BackgroundTransparency = 1
	focus.ZIndex = 91
	focus.Parent = root
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(82, 194, 238)
	stroke.Thickness = 3
	stroke.Parent = focus
	local message = Instance.new("TextLabel")
	message.Name = "Instruction"
	message.AnchorPoint = Vector2.new(0.5, 1)
	message.BackgroundColor3 = Color3.fromRGB(255, 249, 222)
	message.TextColor3 = Color3.fromRGB(22, 56, 91)
	message.Font = Enum.Font.FredokaOne
	message.TextScaled = true
	message.TextWrapped = true
	message.ZIndex = 92
	message.Parent = root
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 14); corner.Parent = message
	local textLimit = Instance.new("UITextSizeConstraint"); textLimit.MinTextSize = 14; textLimit.MaxTextSize = 24; textLimit.Parent = message
	local self: any = setmetatable({ root = root, blockers = blockers, focus = focus, message = message, target = nil }, Overlay)
	self.connection = RunService.RenderStepped:Connect(function() self:update() end)
	return self
end

function Overlay:setTarget(target: GuiObject?, instruction: string?)
	self.target = target
	self.message.Text = instruction or ""
	self.root.Visible = target ~= nil
	self:update()
end

function Overlay:update()
	local target = self.target
	if target == nil or not target.Visible or target.Parent == nil then self.root.Visible = false; return end
	self.root.Visible = true
	local parentPos = self.root.AbsolutePosition
	local p, s = target.AbsolutePosition - parentPos, target.AbsoluteSize
	local pad = 7
	local x, y = math.max(0, p.X - pad), math.max(0, p.Y - pad)
	local w, h = s.X + pad * 2, s.Y + pad * 2
	local total = self.root.AbsoluteSize
	self.blockers[1].Position = UDim2.fromOffset(0, 0); self.blockers[1].Size = UDim2.fromOffset(total.X, y)
	self.blockers[2].Position = UDim2.fromOffset(0, y); self.blockers[2].Size = UDim2.fromOffset(x, h)
	self.blockers[3].Position = UDim2.fromOffset(x + w, y); self.blockers[3].Size = UDim2.fromOffset(math.max(0, total.X - x - w), h)
	self.blockers[4].Position = UDim2.fromOffset(0, y + h); self.blockers[4].Size = UDim2.fromOffset(total.X, math.max(0, total.Y - y - h))
	self.focus.Position = UDim2.fromOffset(x, y); self.focus.Size = UDim2.fromOffset(w, h)
	self.message.Position = UDim2.fromOffset(math.clamp(x + w / 2, 145, math.max(145, total.X - 145)), math.max(76, y - 12))
	self.message.Size = UDim2.fromOffset(280, 58)
end

function Overlay:destroy()
	if self.connection then self.connection:Disconnect() end
	self.root:Destroy()
end

return Overlay
