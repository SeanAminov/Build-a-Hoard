--!strict
-- Visual hoard album: select a large item tile, then sell from one focused detail card.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Stage1Config"))
local Resources = require(Shared:WaitForChild("ResourceDefinitions"))
local UiPresentation = require(Shared:WaitForChild("UiPresentation"))
local UiArt = require(script.Parent:WaitForChild("UiArt"))

local IndexController = {}
IndexController.__index = IndexController

local SKY_LIGHT = Color3.fromRGB(213, 245, 255)
local CREAM = Color3.fromRGB(255, 249, 222)
local PALE = Color3.fromRGB(246, 252, 255)
local INK = Color3.fromRGB(22, 56, 91)
local ORANGE = Color3.fromRGB(242, 111, 48)
local GREEN = Color3.fromRGB(104, 211, 67)
local CORAL = Color3.fromRGB(238, 84, 72)
local MUTED = Color3.fromRGB(183, 201, 215)
local SECONDARY = Color3.fromRGB(60, 83, 106)

local function decorate(object: GuiObject, radius: number, thickness: number?, color: Color3?): UIStroke
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = object
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color or INK
	stroke.Thickness = thickness or 3
	stroke.Parent = object
	if object.BackgroundTransparency < 1 then
		local shine = Instance.new("UIGradient")
		shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(222, 237, 245))
		shine.Rotation = 90
		shine.Parent = object
	end
	return stroke
end

local function constrainText(object: TextLabel | TextButton, minimum: number, maximum: number)
	object.TextScaled = true
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minimum
	constraint.MaxTextSize = maximum
	constraint.Parent = object
end

local function label(parent: Instance, name: string, value: string, position: UDim2, size: UDim2, minimum: number, maximum: number): TextLabel
	local result = Instance.new("TextLabel")
	result.Name = name
	result.BackgroundTransparency = 1
	result.Position = position
	result.Size = size
	result.Text = value
	result.Font = Enum.Font.FredokaOne
	result.TextColor3 = INK
	result.TextStrokeTransparency = 1
	result.TextWrapped = true
	result.Parent = parent
	constrainText(result, minimum, maximum)
	return result
end

local function button(parent: Instance, name: string, value: string, position: UDim2, size: UDim2): TextButton
	local result = Instance.new("TextButton")
	result.Name = name
	result.Position = position
	result.Size = size
	result.BackgroundColor3 = ORANGE
	result.BorderSizePixel = 0
	result.AutoButtonColor = false
	result.Text = value
	result.Font = Enum.Font.FredokaOne
	result.TextColor3 = INK
	result.Parent = parent
	decorate(result, 14, 3)
	constrainText(result, 14, 24)
	return result
end

local function artHolder(parent: Instance, name: string, position: UDim2, size: UDim2): Frame
	local result = Instance.new("Frame")
	result.Name = name
	result.Position = position
	result.Size = size
	result.BackgroundColor3 = SKY_LIGHT
	result.BorderSizePixel = 0
	result.ClipsDescendants = true
	result.Parent = parent
	decorate(result, 16, 2, Color3.fromRGB(60, 143, 190))
	return result
end

local function stat(parent: Instance, name: string, title: string, position: UDim2, color: Color3): TextLabel
	local card = Instance.new("Frame")
	card.Name = name .. "Card"
	card.Position = position
	card.Size = UDim2.new(1, 0, 0, 72)
	card.BackgroundColor3 = color
	card.BorderSizePixel = 0
	card.Parent = parent
	decorate(card, 13, 2, Color3.fromRGB(89, 125, 151))
	local heading = label(card, "Heading", title, UDim2.fromOffset(12, 5), UDim2.new(1, -24, 0, 23), 10, 15)
	heading.TextXAlignment = Enum.TextXAlignment.Left
	local value = label(card, "Value", "0", UDim2.fromOffset(12, 28), UDim2.new(1, -24, 0, 36), 13, 24)
	value.TextXAlignment = Enum.TextXAlignment.Left
	return value
end

function IndexController.new(parent: Instance, actionRemote: RemoteEvent): any
	local root = Instance.new("Frame")
	root.Name = "InventoryPanel"
	root.Position = UDim2.fromOffset(8, 72)
	root.Size = UDim2.new(1, -16, 1, -80)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.Parent = parent
	local left = Instance.new("Frame")
	left.Name = "ItemShelf"
	left.Size = UDim2.new(0.58, -7, 1, 0)
	left.BackgroundTransparency = 1
	left.Parent = root
	local shelfTitle = label(left, "ShelfTitle", "YOUR ITEMS", UDim2.fromOffset(4, 0), UDim2.new(1, -8, 0, 42), 15, 28)
	shelfTitle.TextXAlignment = Enum.TextXAlignment.Left
	local gridFrame = Instance.new("ScrollingFrame")
	gridFrame.Name = "ItemGrid"
	gridFrame.Position = UDim2.fromOffset(0, 44)
	gridFrame.Size = UDim2.new(1, 0, 1, -104)
	gridFrame.BackgroundTransparency = 1
	gridFrame.BorderSizePixel = 0
	gridFrame.ScrollBarThickness = 6
	gridFrame.ScrollBarImageColor3 = INK
	gridFrame.CanvasSize = UDim2.fromOffset(0, 0)
	gridFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	gridFrame.Parent = left
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = gridFrame
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.25, -8, 0, 154)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = gridFrame
	local function resizeGrid()
		local width = gridFrame.AbsoluteSize.X
		local columns = if width >= 720 then 4 elseif width >= 500 then 3 else 2
		local cellOffset = if columns == 4 then -8 elseif columns == 3 then -7 else -5
		local compact = gridFrame.AbsoluteSize.Y < 410
		grid.CellSize = UDim2.new(1 / columns, cellOffset, 0, if compact then 132 else 154)
		gridFrame.CanvasSize = UDim2.fromOffset(0, grid.AbsoluteContentSize.Y + 8)
	end
	gridFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeGrid)
	grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizeGrid)
	resizeGrid()
	local summary = label(left, "InventorySummary", "Storage 0/60  •  +$0.00/sec", UDim2.new(0, 0, 1, -49), UDim2.new(1, 0, 0, 45), 13, 20)
	summary.BackgroundTransparency = 0
	summary.BackgroundColor3 = CREAM
	decorate(summary, 13, 2)

	local detail = Instance.new("Frame")
	detail.Name = "SelectedItemPopup"
	detail.Position = UDim2.new(0.58, 7, 0, 0)
	detail.Size = UDim2.new(0.42, -7, 1, 0)
	detail.BackgroundColor3 = CREAM
	detail.BorderSizePixel = 0
	detail.ClipsDescendants = true
	detail.Parent = root
	local detailStroke = decorate(detail, 18, 3)
	local detailScale = Instance.new("UIScale")
	detailScale.Scale = 1
	detailScale.Parent = detail
	local detailTitle = label(detail, "ItemTitle", "WOOD", UDim2.new(0, 18, 0, 10), UDim2.new(1, -36, 0, 56), 18, 34)
	local hero = artHolder(detail, "HeroArt", UDim2.new(0.03, 0, 0, 74), UDim2.new(0.50, -10, 0, 250))
	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.Position = UDim2.new(0.55, 0, 0, 74)
	stats.Size = UDim2.new(0.42, 0, 0, 250)
	stats.BackgroundTransparency = 1
	stats.Parent = detail
	local ownedValue = stat(stats, "Owned", "OWNED", UDim2.fromOffset(0, 0), Color3.fromRGB(255, 239, 195))
	local sellValue = stat(stats, "SellValue", "SELL VALUE", UDim2.fromOffset(0, 88), Color3.fromRGB(221, 255, 202))
	local incomeValue = stat(stats, "Income", "PASSIVE INCOME", UDim2.fromOffset(0, 176), Color3.fromRGB(212, 246, 255))
	local quantityTitle = label(detail, "QuantityTitle", "SELECT AMOUNT TO SELL", UDim2.new(0.08, 0, 0, 334), UDim2.new(0.84, 0, 0, 30), 11, 18)
	local minus = button(detail, "Decrease", "−", UDim2.new(0.5, -122, 0, 369), UDim2.fromOffset(66, 58))
	local quantityValue = label(detail, "Quantity", "1", UDim2.new(0.5, -48, 0, 369), UDim2.fromOffset(96, 58), 18, 30)
	quantityValue.BackgroundTransparency = 0
	quantityValue.BackgroundColor3 = PALE
	decorate(quantityValue, 13, 3)
	local plus = button(detail, "Increase", "+", UDim2.new(0.5, 56, 0, 369), UDim2.fromOffset(66, 58))
	local sellSelected = button(detail, "SellSelected", "SELL 1", UDim2.new(0.04, 0, 0, 441), UDim2.new(0.45, -5, 0, 68))
	local sellAll = button(detail, "SellAll", "SELL ALL", UDim2.new(0.51, 5, 0, 441), UDim2.new(0.45, -5, 0, 68))
	sellAll.BackgroundColor3 = CORAL
	local note = label(detail, "IncomeNote", "Your hoard keeps earning while you explore.", UDim2.new(0.05, 0, 0, 520), UDim2.new(0.9, 0, 0, 38), 11, 17)
	note.BackgroundTransparency = 0
	note.BackgroundColor3 = Color3.fromRGB(226, 255, 210)
	decorate(note, 12, 2, Color3.fromRGB(90, 167, 80))

	local cards: { [string]: any } = {}
	local self: any = setmetatable({
		root = root, left = left, gridFrame = gridFrame, stats = stats, cards = cards, summary = summary, detail = detail, detailStroke = detailStroke,
		detailScale = detailScale, detailTitle = detailTitle, hero = hero, ownedValue = ownedValue,
		sellValue = sellValue, incomeValue = incomeValue, minus = minus, plus = plus,
		quantityValue = quantityValue, sellSelected = sellSelected, sellAll = sellAll,
		selectedResourceId = "Wood", quantity = 0, currentSnapshot = {}, actionRemote = actionRemote,
	}, IndexController)

	for index, resourceId in ipairs(Config.resourceOrder) do
		local definition = Resources.get(resourceId) :: Resources.ResourceDefinition
		local card = Instance.new("TextButton")
		card.Name = resourceId .. "Card"
		card.LayoutOrder = index
		card.BackgroundColor3 = PALE
		card.BorderSizePixel = 0
		card.AutoButtonColor = false
		card.Text = ""
		card.Parent = gridFrame
		local cardStroke = decorate(card, 18, 3)
		local icon = artHolder(card, "Art", UDim2.new(0.16, 0, 0.05, 0), UDim2.new(0.68, 0, 0.56, 0))
		UiArt.resource(icon, resourceId)
		local name = label(card, "ItemName", definition.displayName, UDim2.new(0.06, 0, 0.65, 0), UDim2.new(0.64, 0, 0.25, 0), 11, 20)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local count = label(card, "OwnedBadge", "×0", UDim2.new(0.72, 0, 0.69, 0), UDim2.new(0.22, 0, 0.18, 0), 11, 20)
		count.BackgroundTransparency = 0
		count.BackgroundColor3 = INK
		count.TextColor3 = Color3.new(1, 1, 1)
		decorate(count, 10, 1, INK)
		card.Activated:Connect(function() self:select(resourceId) end)
		cards[resourceId] = { button = card, stroke = cardStroke, count = count }
	end

	minus.Activated:Connect(function()
		if self.quantity > 1 then self.quantity -= 1; self:renderSelected() end
	end)
	plus.Activated:Connect(function()
		local counts = self.currentSnapshot.hoardCounts or {}
		local owned = counts[self.selectedResourceId] or 0
		if self.quantity < owned then self.quantity += 1; self:renderSelected() end
	end)
	sellSelected.Activated:Connect(function()
		if self.quantity > 0 then self.actionRemote:FireServer("SELL", { resourceId = self.selectedResourceId, amount = self.quantity }) end
	end)
	sellAll.Activated:Connect(function()
		local counts = self.currentSnapshot.hoardCounts or {}
		if (counts[self.selectedResourceId] or 0) > 0 then self.actionRemote:FireServer("SELL", { resourceId = self.selectedResourceId, amount = "ALL" }) end
	end)
	self:select("Wood")
	detail:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:layoutDetail() end)
	self:layoutDetail()
	return self
end

function IndexController:layout(compact: boolean)
	self.root.Position = UDim2.fromOffset(8, if compact then 66 else 72)
	self.root.Size = UDim2.new(1, -16, 1, if compact then -72 else -80)
	self:layoutDetail()
end

function IndexController:layoutDetail()
	local height = self.detail.AbsoluteSize.Y
	if height <= 0 then return end
	local short = height < 420
	local titleHeight = if short then 32 else 48
	local buttonHeight = if short then 44 else 56
	local controlsY = height - buttonHeight * 2 - 24
	local artTop = titleHeight + 12
	local artHeight = math.clamp(controlsY - artTop - 36, 40, if short then 150 else 240)
	self.detailTitle.Position = UDim2.fromOffset(12, 4)
	self.detailTitle.Size = UDim2.new(1, -24, 0, titleHeight)
	self.hero.Position = UDim2.new(0.03, 0, 0, artTop)
	self.hero.Size = UDim2.new(0.48, -8, 0, artHeight)
	self.stats.Position = UDim2.new(0.53, 0, 0, artTop)
	self.stats.Size = UDim2.new(0.44, 0, 0, artHeight)
	for index, name in ipairs({"OwnedCard", "SellValueCard", "IncomeCard"}) do
		local card = self.stats:FindFirstChild(name)
		card.Position = UDim2.new(0, 0, (index - 1) / 3, 2)
		card.Size = UDim2.new(1, 0, 1 / 3, -5)
		card.Heading.Position = UDim2.new(0, 8, 0.04, 0)
		card.Heading.Size = UDim2.new(1, -16, 0.34, 0)
		card.Value.Position = UDim2.new(0, 8, 0.40, 0)
		card.Value.Size = UDim2.new(1, -16, 0.55, 0)
	end
	self.detail.QuantityTitle.Position = UDim2.new(0.04, 0, 0, controlsY - 30)
	self.detail.QuantityTitle.Size = UDim2.new(0.92, 0, 0, 24)
	for _, control in ipairs({self.minus, self.quantityValue, self.plus}) do
		control.Position = UDim2.new(control.Position.X.Scale, control.Position.X.Offset, 0, controlsY)
		control.Size = UDim2.new(control.Size.X.Scale, control.Size.X.Offset, 0, buttonHeight)
	end
	for _, control in ipairs({self.sellSelected, self.sellAll}) do
		control.Position = UDim2.new(control.Position.X.Scale, control.Position.X.Offset, 1, -buttonHeight - 10)
		control.Size = UDim2.new(control.Size.X.Scale, control.Size.X.Offset, 0, buttonHeight)
	end
	self.detail.IncomeNote.Visible = false
end

function IndexController:select(resourceId: string)
	if Resources.get(resourceId) == nil then return end
	if self.currentSnapshot.tutorialStep == 2 and self.currentSnapshot.tutorialDuplicateResourceId ~= resourceId then return end
	self.selectedResourceId = resourceId
	local counts = self.currentSnapshot.hoardCounts or {}
	self.quantity = if (counts[resourceId] or 0) > 0 then 1 else 0
	for id, card in pairs(self.cards) do
		local selected = id == resourceId
		card.button.BackgroundColor3 = if selected then Color3.fromRGB(228, 255, 218) else PALE
		card.stroke.Color = if selected then Color3.fromRGB(31, 180, 232) else INK
		card.stroke.Thickness = if selected then 5 else 3
	end
	self.hero:ClearAllChildren()
	decorate(self.hero, 16, 2, Color3.fromRGB(60, 143, 190))
	UiArt.resource(self.hero, resourceId)
	self.detailScale.Scale = 0.98
	TweenService:Create(self.detailScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	self:renderSelected()
end

function IndexController:renderSelected()
	local definition = Resources.get(self.selectedResourceId) :: Resources.ResourceDefinition
	local counts = self.currentSnapshot.hoardCounts or {}
	local owned = counts[self.selectedResourceId] or 0
	if owned <= 0 then self.quantity = 0 else self.quantity = math.clamp(self.quantity, 1, owned) end
	self.detailTitle.Text = string.upper(definition.displayName)
	self.ownedValue.Text = tostring(owned)
	self.sellValue.Text = string.format("$%d EACH", definition.sellValue)
	self.incomeValue.Text = UiPresentation.formatRate(definition.passivePerSecond) .. " EACH"
	self.quantityValue.Text = tostring(self.quantity)
	self.sellSelected.Text = if owned > 0 then string.format("SELL %d", self.quantity) else "NOTHING TO SELL"
	self.sellAll.Text = if owned > 0 then string.format("SELL ALL (%d)", owned) else "NOTHING TO SELL"
	local enabled = owned > 0
	local tutorialSell = self.currentSnapshot.tutorialStep == 2
	if tutorialSell then self.quantity = if enabled then 1 else 0; self.quantityValue.Text = tostring(self.quantity); self.sellSelected.Text = if enabled then "SELL 1" else "NOTHING TO SELL" end
	self.minus.Active = not tutorialSell and enabled and self.quantity > 1
	self.plus.Active = not tutorialSell and enabled and self.quantity < owned
	self.sellSelected.Active = enabled
	self.sellAll.Active = not tutorialSell and enabled
	self.minus.BackgroundColor3 = if self.minus.Active then ORANGE else MUTED
	self.plus.BackgroundColor3 = if self.plus.Active then ORANGE else MUTED
	self.sellSelected.BackgroundColor3 = if enabled then ORANGE else MUTED
	self.sellAll.BackgroundColor3 = if self.sellAll.Active then CORAL else MUTED
end

function IndexController:setVisible(visible: boolean)
	self.root.Visible = visible
	if visible then self:select(self.selectedResourceId) end
end

function IndexController:render(snapshot: any)
	self.currentSnapshot = snapshot
	local counts = snapshot.hoardCounts or {}
	for _, resourceId in ipairs(Config.resourceOrder) do
		self.cards[resourceId].count.Text = string.format("×%d", counts[resourceId] or 0)
	end
	self.summary.Text = string.format(
		"Storage %d/%d  •  %s",
		snapshot.hoardTotal or 0,
		snapshot.storageCapacity or Config.startingStorageCapacity,
		UiPresentation.formatRate(snapshot.passivePerSecond or 0)
	)
	self:renderSelected()
end

return IndexController
