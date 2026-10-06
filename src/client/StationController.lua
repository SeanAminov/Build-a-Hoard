--!strict
-- Local prompts and owner-only station status signs for runtime plot buildings.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Stage5Config"))

local StationController = {}
StationController.__index = StationController

local INK = Color3.fromRGB(22, 56, 91)
local CREAM = Color3.fromRGB(255, 249, 222)
local SKY = Color3.fromRGB(82, 194, 238)
local GREEN = Color3.fromRGB(104, 211, 67)
local ORANGE = Color3.fromRGB(242, 145, 42)

local function makeSign(name: string): (BillboardGui, TextLabel, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = name; gui.Size = UDim2.fromOffset(230, 78); gui.StudsOffset = Vector3.new(0, 0, 0); gui.AlwaysOnTop = true; gui.Enabled = false
	local frame = Instance.new("Frame"); frame.Size = UDim2.fromScale(1, 1); frame.BackgroundColor3 = CREAM; frame.BorderSizePixel = 0; frame.Parent = gui
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 18); corner.Parent = frame
	local stroke = Instance.new("UIStroke"); stroke.Color = INK; stroke.Thickness = 3; stroke.Parent = frame
	local accent = Instance.new("Frame"); accent.Name = "Accent"; accent.Size = UDim2.new(0, 12, 1, -12); accent.Position = UDim2.fromOffset(6, 6); accent.BackgroundColor3 = SKY; accent.BorderSizePixel = 0; accent.Parent = frame
	local ac = Instance.new("UICorner"); ac.CornerRadius = UDim.new(1, 0); ac.Parent = accent
	local title = Instance.new("TextLabel"); title.Name = "Title"; title.Position = UDim2.fromOffset(24, 7); title.Size = UDim2.new(1, -32, 0, 36); title.BackgroundTransparency = 1; title.TextColor3 = INK; title.Font = Enum.Font.FredokaOne; title.TextScaled = true; title.Parent = frame
	local tc = Instance.new("UITextSizeConstraint"); tc.MinTextSize = 12; tc.MaxTextSize = 24; tc.Parent = title
	local detail = Instance.new("TextLabel"); detail.Name = "Detail"; detail.Position = UDim2.fromOffset(24, 42); detail.Size = UDim2.new(1, -32, 0, 25); detail.BackgroundTransparency = 1; detail.TextColor3 = Color3.fromRGB(46, 133, 68); detail.Font = Enum.Font.FredokaOne; detail.TextScaled = true; detail.Parent = frame
	local dc = Instance.new("UITextSizeConstraint"); dc.MinTextSize = 10; dc.MaxTextSize = 16; dc.Parent = detail
	return gui, title, detail
end

function StationController.new(actionRemote: RemoteEvent, openCollectionBin: (() -> ())?): any
	local afkSign, afkTitle, afkDetail = makeSign("AFKStatus")
	local binSign, binTitle, binDetail = makeSign("BinStatus")
	binSign.Size = UDim2.fromOffset(174, 48)
	binTitle.Position = UDim2.fromOffset(20, 7); binTitle.Size = UDim2.new(1, -28, 1, -14)
	binDetail.Visible = false
	local self: any = setmetatable({
		actionRemote = actionRemote, openCollectionBin = openCollectionBin, snapshot = nil, prompt = nil, promptConnection = nil,
		afkSign = afkSign, afkTitle = afkTitle, afkDetail = afkDetail,
		binSign = binSign, binTitle = binTitle, binDetail = binDetail,
		receivedAt = os.clock(), running = true,
	}, StationController)
	task.spawn(function() while self.running do self:updateSigns(); task.wait(1) end end)
	return self
end

function StationController:plot(): Model?
	local snapshot = self.snapshot
	local hoard = Workspace:FindFirstChild("Hoard")
	local plots = if hoard then hoard:FindFirstChild("Plots") else nil
	local plot = if plots and snapshot and snapshot.plotId then plots:FindFirstChild(string.format("Plot%d", snapshot.plotId)) else nil
	return if plot and plot:IsA("Model") then plot else nil
end

function StationController:ensurePrompt()
	local plot = self:plot()
	local stations = if plot then plot:FindFirstChild("Stations") else nil
	local model = if stations then stations:FindFirstChild("CollectionBin") else nil
	local part = if model then model:FindFirstChild("InteractionPart") else nil
	if part == nil or not part:IsA("BasePart") then
		if self.prompt then self.prompt:Destroy(); self.prompt = nil end
		if self.promptConnection then self.promptConnection:Disconnect(); self.promptConnection = nil end
		return
	end
	if self.prompt and self.prompt.Parent == part then return end
	if self.prompt then self.prompt:Destroy() end
	if self.promptConnection then self.promptConnection:Disconnect() end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CollectionBinPrompt"; prompt.ActionText = "Open"; prompt.ObjectText = "Collection Bin"; prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0; prompt.MaxActivationDistance = Config.stationInteractionRange; prompt.RequiresLineOfSight = false; prompt.ClickablePrompt = true; prompt.Parent = part
	self.prompt = prompt
	self.promptConnection = prompt.Triggered:Connect(function()
		if self.openCollectionBin then self.openCollectionBin() end
		self.actionRemote:FireServer("VIEW_COLLECTION_BIN")
	end)
end

function StationController:attachSigns()
	local plot = self:plot()
	local stations = if plot then plot:FindFirstChild("Stations") else nil
	local afk = if stations then stations:FindFirstChild("AFKSorter") else nil
	local bin = if stations then stations:FindFirstChild("CollectionBin") else nil
	local afkAnchor = if afk then afk:FindFirstChild("IndicatorAnchor") else nil
	local binAnchor = if bin then bin:FindFirstChild("IndicatorAnchor") else nil
	self.afkSign.Parent = if afkAnchor and afkAnchor:IsA("BasePart") then afkAnchor else nil
	self.binSign.Parent = if binAnchor and binAnchor:IsA("BasePart") then binAnchor else nil
end

function StationController:updateSigns()
	local snapshot = self.snapshot
	if snapshot == nil then return end
	self:attachSigns(); self:ensurePrompt()
	-- The AFK bubble is a discovery hint while idle, then becomes a live countdown only while
	-- the owner is standing on the pad. The Collection Bin keeps only a small first-use label;
	-- its counts and timer live in the E-key menu.
	self.afkSign.Enabled = self.afkSign.Parent ~= nil and (snapshot.afkInteracted ~= true or snapshot.afkActive == true)
	if self.afkSign.Enabled then
		if snapshot.afkActive then
			self.afkTitle.Text = "SORTING JUNK"
			self.afkDetail.Text = string.format("NEXT ITEM IN %ds", math.max(0, math.ceil(snapshot.afkRemainingSeconds or 60)))
			self.afkDetail.TextColor3 = if (snapshot.hoardTotal or 0) >= (snapshot.storageCapacity or 0) then ORANGE else GREEN
		else
			self.afkTitle.Text = "AFK HERE"
			self.afkDetail.Text = "STAND ON THE PAD"
			self.afkDetail.TextColor3 = GREEN
		end
	end
	self.binSign.Enabled = self.binSign.Parent ~= nil and snapshot.collectionBinInteracted ~= true
	if self.binSign.Enabled then self.binTitle.Text = "COLLECTION BIN" end
	if self.prompt then self.prompt.Enabled = snapshot.collectionBinPending ~= true end
end

function StationController:render(snapshot: any)
	self.snapshot = snapshot; self.receivedAt = os.clock(); self:updateSigns()
end

function StationController:destroy()
	self.running = false
	if self.promptConnection then self.promptConnection:Disconnect() end
	if self.prompt then self.prompt:Destroy() end
	self.afkSign:Destroy(); self.binSign:Destroy()
end

return StationController
