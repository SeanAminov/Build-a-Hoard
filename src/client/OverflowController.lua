--!strict
--[[
	MAKE ROOM! — the overflow chooser.

	Every carried object starts on SELL and the player promotes the ones that still fit. The screen
	is deliberately modal: it carries no dismissal control, because the server keeps the overflow
	pending until the player either resolves it or walks out of the DepositZone.

	WHY A TOKEN AND NOT `revision`. Passive income moves the general revision about once per second.
	Rebuilding the cards whenever that changed erased the player's choices mid-decision. The server
	now stamps each overflow event with `overflowToken`, so unrelated snapshots may refresh labels
	while the cards, the scroll position and every KEEP/SELL choice survive untouched.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Resources = require(Shared:WaitForChild("ResourceDefinitions"))
local UiArt = require(script.Parent:WaitForChild("UiArt"))

local OverflowController = {}
OverflowController.__index = OverflowController

local SKY_LIGHT = Color3.fromRGB(213, 245, 255)
local CREAM = Color3.fromRGB(255, 249, 222)
local PALE = Color3.fromRGB(246, 252, 255)
local INK = Color3.fromRGB(22, 56, 91)
local ORANGE = Color3.fromRGB(242, 111, 48)
local GREEN = Color3.fromRGB(104, 211, 67)
local GREEN_DEEP = Color3.fromRGB(63, 148, 47)
local CORAL = Color3.fromRGB(238, 84, 72)
local MUTED = Color3.fromRGB(183, 201, 215)
local SECONDARY = Color3.fromRGB(60, 83, 106)

-- PROTOTYPE PRESENTATION values fixed by the Stage 3 v2 handoff.
local DIM_TRANSPARENCY = 0.32
local MAX_CONTENT_WIDTH = 1180
local HEADER_HEIGHT, HEADER_HEIGHT_COMPACT = 96, 78
local FOOTER_HEIGHT, FOOTER_HEIGHT_COMPACT = 104, 92
local CARD_HEIGHT, CARD_HEIGHT_COMPACT = 150, 126
local ART_SIZE, ART_SIZE_COMPACT = 72, 56
local COMPACT_VIEWPORT_HEIGHT = 550
local LIMIT_NOTICE_SECONDS = 1.6

local function decorate(object: GuiObject, radius: number, thickness: number?, color: Color3?): UIStroke
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = object
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color or INK
	stroke.Thickness = thickness or 3
	stroke.Parent = object
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

local function artHolder(parent: Instance, name: string, position: UDim2, size: UDim2): Frame
	local result = Instance.new("Frame")
	result.Name = name
	result.Position = position
	result.Size = size
	result.BackgroundColor3 = SKY_LIGHT
	result.BorderSizePixel = 0
	result.ClipsDescendants = true
	result.Parent = parent
	decorate(result, 14, 2, Color3.fromRGB(60, 143, 190))
	return result
end

function OverflowController.new(actionRemote: RemoteEvent): any
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("OverflowGui")
	if old then old:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "OverflowGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Enabled = false
	gui.Parent = playerGui

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = DIM_TRANSPARENCY
	dim.BorderSizePixel = 0
	dim.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(1, -8, 1, -8)
	panel.BackgroundColor3 = CREAM
	panel.BorderSizePixel = 0
	panel.Parent = dim
	decorate(panel, 22, 4)
	local widthLimit = Instance.new("UISizeConstraint")
	widthLimit.MaxSize = Vector2.new(MAX_CONTENT_WIDTH, math.huge)
	widthLimit.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	header.Parent = panel
	local title = label(header, "Title", "MAKE ROOM!", UDim2.fromOffset(22, 8), UDim2.new(0.5, 0, 0, 44), 20, 40)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local subtitle = label(header, "Subtitle", "Choose what goes into your hoard. Everything else sells.", UDim2.fromOffset(24, 52), UDim2.new(0.5, 0, 0, 30), 11, 19)
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextColor3 = SECONDARY

	local badge = Instance.new("Frame")
	badge.Name = "StorageBadge"
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, -18, 0, 12)
	badge.Size = UDim2.fromOffset(268, 66)
	badge.BackgroundColor3 = SKY_LIGHT
	badge.BorderSizePixel = 0
	badge.Parent = header
	decorate(badge, 16, 3, Color3.fromRGB(60, 143, 190))
	local hoardCount = label(badge, "HoardCount", "HOARD 0 / 0", UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 32), 14, 26)
	local spacesLeft = label(badge, "SpacesLeft", "0 SPACES LEFT", UDim2.fromOffset(12, 36), UDim2.new(1, -24, 0, 24), 10, 18)
	spacesLeft.TextColor3 = SECONDARY

	local shelf = Instance.new("ScrollingFrame")
	shelf.Name = "ItemShelf"
	shelf.Position = UDim2.fromOffset(12, HEADER_HEIGHT)
	shelf.Size = UDim2.new(1, -24, 1, -(HEADER_HEIGHT + FOOTER_HEIGHT))
	shelf.BackgroundColor3 = PALE
	shelf.BackgroundTransparency = 0.35
	shelf.BorderSizePixel = 0
	shelf.CanvasSize = UDim2.new()
	shelf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	shelf.ScrollingDirection = Enum.ScrollingDirection.Y
	shelf.ScrollBarThickness = 6
	shelf.Parent = panel
	decorate(shelf, 18, 2, MUTED)
	local shelfPadding = Instance.new("UIPadding")
	shelfPadding.PaddingTop = UDim.new(0, 8)
	shelfPadding.PaddingBottom = UDim.new(0, 8)
	shelfPadding.PaddingLeft = UDim.new(0, 8)
	shelfPadding.PaddingRight = UDim.new(0, 8)
	shelfPadding.Parent = shelf
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.25, -8, 0, CARD_HEIGHT)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = shelf

	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.new(0, 12, 1, -10)
	footer.Size = UDim2.new(1, -24, 0, FOOTER_HEIGHT - 18)
	footer.BackgroundColor3 = PALE
	footer.BorderSizePixel = 0
	footer.Parent = panel
	decorate(footer, 16, 3, MUTED)
	local keepSummary = label(footer, "KeepSummary", "KEEP 0 / 0", UDim2.fromOffset(16, 8), UDim2.new(0.45, 0, 0, 34), 14, 26)
	keepSummary.TextXAlignment = Enum.TextXAlignment.Left
	local sellSummary = label(footer, "SellSummary", "SELL 0 • +$0", UDim2.fromOffset(16, 44), UDim2.new(0.45, 0, 0, 28), 12, 22)
	sellSummary.TextXAlignment = Enum.TextXAlignment.Left
	sellSummary.TextColor3 = SECONDARY

	local confirm = Instance.new("TextButton")
	confirm.Name = "Confirm"
	confirm.AnchorPoint = Vector2.new(1, 0.5)
	confirm.Position = UDim2.new(1, -14, 0.5, 0)
	confirm.Size = UDim2.fromOffset(300, 64)
	confirm.BackgroundColor3 = ORANGE
	confirm.AutoButtonColor = false
	confirm.Text = "SELL ALL 0"
	confirm.Font = Enum.Font.FredokaOne
	confirm.TextColor3 = INK
	confirm.Parent = footer
	decorate(confirm, 14, 3)
	constrainText(confirm, 14, 25)

	local self: any = setmetatable({
		actionRemote = actionRemote,
		gui = gui, dim = dim, panel = panel, header = header, badge = badge, shelf = shelf, grid = grid, footer = footer,
		title = title, subtitle = subtitle, hoardCount = hoardCount, spacesLeft = spacesLeft,
		keepSummary = keepSummary, sellSummary = sellSummary, confirm = confirm,
		cards = {}, order = {}, selected = {},
		latest = nil, openToken = nil, working = false, compact = false, noticeNonce = 0,
	}, OverflowController)

	confirm.Activated:Connect(function() self:submit() end)
	shelf:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:layoutShelf() end)
	if Workspace.CurrentCamera then
		self.viewportConnection = Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() self:layout() end)
	end
	self:layout()
	return self
end

function OverflowController:freeSlots(): number
	local snapshot = self.latest
	return if snapshot then math.max(0, snapshot.freeSlots or 0) else 0
end

function OverflowController:keepCount(): number
	local count = 0
	for _, itemId in ipairs(self.order) do if self.selected[itemId] then count += 1 end end
	return count
end

function OverflowController:layout()
	local camera = Workspace.CurrentCamera
	local compact = camera ~= nil and camera.ViewportSize.Y < COMPACT_VIEWPORT_HEIGHT
	self.compact = compact
	local headerHeight = if compact then HEADER_HEIGHT_COMPACT else HEADER_HEIGHT
	local footerHeight = if compact then FOOTER_HEIGHT_COMPACT else FOOTER_HEIGHT
	self.header.Size = UDim2.new(1, 0, 0, headerHeight)
	self.title.Size = UDim2.new(0.5, 0, 0, if compact then 34 else 44)
	self.subtitle.Position = UDim2.fromOffset(24, if compact then 42 else 52)
	self.subtitle.Size = UDim2.new(0.5, 0, 0, if compact then 26 else 30)
	self.badge.Size = UDim2.fromOffset(if compact then 226 else 268, if compact then 54 else 66)
	self.shelf.Position = UDim2.fromOffset(12, headerHeight)
	self.shelf.Size = UDim2.new(1, -24, 1, -(headerHeight + footerHeight))
	self.footer.Size = UDim2.new(1, -24, 0, footerHeight - 18)
	self.confirm.Size = UDim2.fromOffset(if compact then 236 else 300, if compact then 52 else 64)
	self:layoutShelf()
end

function OverflowController:layoutShelf()
	local width = self.shelf.AbsoluteSize.X
	local columns = if width >= 760 then 4 elseif width >= 520 then 3 else 2
	local cellOffset = if columns == 4 then -8 elseif columns == 3 then -7 else -5
	local compact = self.compact
	local cardHeight = if compact then CARD_HEIGHT_COMPACT else CARD_HEIGHT
	local artSize = if compact then ART_SIZE_COMPACT else ART_SIZE
	self.grid.CellSize = UDim2.new(1 / columns, cellOffset, 0, cardHeight)
	for _, card in pairs(self.cards) do
		card.art.Position = UDim2.fromOffset(12, 12)
		card.art.Size = UDim2.fromOffset(artSize, artSize)
		card.name.Position = UDim2.new(0, artSize + 24, 0, 12)
		card.name.Size = UDim2.new(1, -(artSize + 38), 0, if compact then 24 else 28)
		card.value.Position = UDim2.new(0, artSize + 24, 0, if compact then 38 else 44)
		card.value.Size = UDim2.new(1, -(artSize + 38), 0, if compact then 20 else 24)
		card.check.Size = UDim2.fromOffset(if compact then 24 else 28, if compact then 24 else 28)
		card.pill.Position = UDim2.new(0, 12, 1, if compact then -40 else -46)
		card.pill.Size = UDim2.new(1, -24, 0, if compact then 30 else 34)
	end
end

function OverflowController:createCard(index: number, item: any, definition: any)
	local card = Instance.new("TextButton")
	card.Name = item.itemId
	card.LayoutOrder = index
	card.BackgroundColor3 = PALE
	card.BorderSizePixel = 0
	card.AutoButtonColor = false
	card.Text = ""
	card.Parent = self.shelf
	local stroke = decorate(card, 16, 3, CORAL)
	local art = artHolder(card, "Art", UDim2.fromOffset(12, 12), UDim2.fromOffset(ART_SIZE, ART_SIZE))
	UiArt.resource(art, item.resourceId)
	local name = label(card, "ItemName", string.upper(definition.displayName), UDim2.new(0, 96, 0, 12), UDim2.new(1, -110, 0, 28), 10, 20)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local value = label(card, "ItemValue", string.format("$%d", definition.sellValue), UDim2.new(0, 96, 0, 44), UDim2.new(1, -110, 0, 24), 10, 18)
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextColor3 = SECONDARY
	local check = label(card, "KeepCheck", "✓", UDim2.new(1, -40, 0, 10), UDim2.fromOffset(28, 28), 12, 22)
	check.BackgroundTransparency = 0
	check.BackgroundColor3 = GREEN
	check.TextColor3 = Color3.new(1, 1, 1)
	check.Visible = false
	decorate(check, 14, 2, GREEN_DEEP)
	local pill = label(card, "StatePill", "SELL", UDim2.new(0, 12, 1, -46), UDim2.new(1, -24, 0, 34), 12, 22)
	pill.BackgroundTransparency = 0
	pill.BackgroundColor3 = ORANGE
	decorate(pill, 12, 2, CORAL)

	self.cards[item.itemId] = {
		button = card, stroke = stroke, art = art, name = name, value = value, check = check, pill = pill,
		resourceId = item.resourceId, sellValue = definition.sellValue,
	}
	self.selected[item.itemId] = false
	table.insert(self.order, item.itemId)
	card.Activated:Connect(function() self:toggle(item.itemId) end)
	self:paintCard(item.itemId)
end

function OverflowController:paintCard(itemId: string)
	local card = self.cards[itemId]
	if card == nil then return end
	local keep = self.selected[itemId] == true
	card.pill.Text = if keep then "KEEP" else string.format("SELL +$%d", card.sellValue)
	card.pill.BackgroundColor3 = if keep then GREEN else ORANGE
	card.stroke.Color = if keep then GREEN_DEEP else CORAL
	card.check.Visible = keep
end

function OverflowController:buildCards(carry: { any })
	for _, card in pairs(self.cards) do card.button:Destroy() end
	table.clear(self.cards)
	table.clear(self.selected)
	table.clear(self.order)
	for index, item in ipairs(carry) do
		local definition = Resources.get(item.resourceId)
		if definition ~= nil then self:createCard(index, item, definition) end
	end
	self:layoutShelf()
end

-- An unexpected carry change under one token reconciles by itemId, so surviving choices are kept.
function OverflowController:reconcile(carry: { any })
	local present: { [string]: boolean } = {}
	for _, item in ipairs(carry) do present[item.itemId] = true end
	for index = #self.order, 1, -1 do
		local itemId = self.order[index]
		if not present[itemId] then
			local card = self.cards[itemId]
			if card then card.button:Destroy() end
			self.cards[itemId] = nil
			self.selected[itemId] = nil
			table.remove(self.order, index)
		end
	end
	for index, item in ipairs(carry) do
		local existing = self.cards[item.itemId]
		if existing == nil then
			local definition = Resources.get(item.resourceId)
			if definition ~= nil then self:createCard(index, item, definition) end
		else
			existing.button.LayoutOrder = index
		end
	end
	self:layoutShelf()
end

function OverflowController:noticeLimit(free: number)
	self.noticeNonce += 1
	local nonce = self.noticeNonce
	self.keepSummary.Text = string.format("ONLY %d SPACES LEFT", free)
	self.keepSummary.TextColor3 = CORAL
	task.delay(LIMIT_NOTICE_SECONDS, function()
		if self.noticeNonce == nonce and self.gui.Parent ~= nil then self:updateSummary() end
	end)
end

function OverflowController:toggle(itemId: string)
	if self.working then return end
	local card = self.cards[itemId]
	if card == nil then return end
	if self.selected[itemId] then
		self.selected[itemId] = false
	else
		local free = self:freeSlots()
		if self:keepCount() >= free then self:noticeLimit(free); return end
		self.selected[itemId] = true
	end
	self:paintCard(itemId)
	self:updateSummary()
end

function OverflowController:updateSummary()
	local free = self:freeSlots()
	local keep = self:keepCount()
	local sell = #self.order - keep
	local total = 0
	for _, itemId in ipairs(self.order) do
		if not self.selected[itemId] then total += self.cards[itemId].sellValue end
	end
	self.keepSummary.Text = string.format("KEEP %d / %d", keep, free)
	self.keepSummary.TextColor3 = INK
	self.sellSummary.Text = string.format("SELL %d • +$%d", sell, total)
	if self.working then
		self.confirm.Text = "WORKING..."
	elseif free <= 0 then
		self.confirm.Text = string.format("SELL ALL %d", sell)
	else
		self.confirm.Text = string.format("DEPOSIT %d • SELL %d", keep, sell)
	end
	local active = keep <= free and not self.working
	self.confirm.Active = active
	self.confirm.AutoButtonColor = active
	self.confirm.BackgroundColor3 = if active then ORANGE else MUTED
end

function OverflowController:submit()
	if self.working then return end
	local snapshot = self.latest
	if snapshot == nil or not snapshot.pendingOverflow then return end
	local keep = {}
	for _, itemId in ipairs(self.order) do
		if self.selected[itemId] then table.insert(keep, itemId) end
	end
	if #keep > self:freeSlots() then return end
	-- One click sends one intent; the next authoritative snapshot, accepting or rejecting, frees it.
	self.working = true
	self:updateSummary()
	self.actionRemote:FireServer("RESOLVE_OVERFLOW", keep)
end

function OverflowController:render(snapshot: any)
	self.latest = snapshot
	if not snapshot.pendingOverflow then
		self.gui.Enabled = false
		self.openToken = nil
		self.working = false
		for _, card in pairs(self.cards) do card.button:Destroy() end
		table.clear(self.cards)
		table.clear(self.selected)
		table.clear(self.order)
		return
	end
	local token = snapshot.overflowToken or 0
	local carry = snapshot.carry or {}
	self.working = false
	if self.openToken ~= token then
		self.openToken = token
		self:buildCards(carry)
	else
		self:reconcile(carry)
	end
	self.hoardCount.Text = string.format("HOARD %d / %d", snapshot.hoardTotal or 0, snapshot.storageCapacity or 0)
	self.spacesLeft.Text = string.format("%d SPACES LEFT", self:freeSlots())
	self:updateSummary()
	self.gui.Enabled = true
end

function OverflowController:destroy()
	if self.viewportConnection then
		self.viewportConnection:Disconnect()
		self.viewportConnection = nil
	end
	self.gui:Destroy()
end

return OverflowController
