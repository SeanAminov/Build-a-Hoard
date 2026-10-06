--!strict
-- Collection Bin overview and server-authoritative overflow chooser.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Stage1Config"))
local Resources = require(Shared:WaitForChild("ResourceDefinitions"))
local UiArt = require(script.Parent:WaitForChild("UiArt"))

local CollectionBinController = {}
CollectionBinController.__index = CollectionBinController

local INK = Color3.fromRGB(22, 56, 91)
local SKY = Color3.fromRGB(82, 194, 238)
local CREAM = Color3.fromRGB(255, 249, 222)
local PALE = Color3.fromRGB(240, 249, 255)
local GREEN = Color3.fromRGB(104, 211, 67)
local ORANGE = Color3.fromRGB(242, 145, 42)
local CORAL = Color3.fromRGB(238, 84, 72)
local MUTED = Color3.fromRGB(183, 201, 215)

local function round(gui: GuiObject, radius: number, thickness: number?, color: Color3?)
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, radius); corner.Parent = gui
	local stroke = Instance.new("UIStroke"); stroke.Color = color or INK; stroke.Thickness = thickness or 2; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; stroke.Parent = gui
end

local function text(parent: Instance, name: string, value: string, pos: UDim2, size: UDim2, maximum: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name; label.BackgroundTransparency = 1; label.Position = pos; label.Size = size; label.Text = value
	label.TextColor3 = INK; label.Font = Enum.Font.FredokaOne; label.TextScaled = true; label.TextWrapped = true; label.Parent = parent
	local constraint = Instance.new("UITextSizeConstraint"); constraint.MinTextSize = 10; constraint.MaxTextSize = maximum; constraint.Parent = label
	return label
end

local function button(parent: Instance, name: string, value: string, pos: UDim2, size: UDim2, color: Color3): TextButton
	local result = Instance.new("TextButton")
	result.Name = name; result.Position = pos; result.Size = size; result.BackgroundColor3 = color; result.BorderSizePixel = 0
	result.Text = value; result.TextColor3 = INK; result.Font = Enum.Font.FredokaOne; result.TextScaled = true; result.Parent = parent
	local constraint = Instance.new("UITextSizeConstraint"); constraint.MinTextSize = 12; constraint.MaxTextSize = 22; constraint.Parent = result
	round(result, 12, 2)
	return result
end

local function totalCounts(counts: { [string]: number }): number
	local total = 0
	for _, resourceId in ipairs(Config.resourceOrder) do total += counts[resourceId] or 0 end
	return total
end

local function duration(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	local minutes = math.floor(seconds / 60)
	local remainder = seconds % 60
	return if minutes > 0 then string.format("%dm %02ds", minutes, remainder) else string.format("%ds", remainder)
end

function CollectionBinController.new(actionRemote: RemoteEvent): any
	local gui = Instance.new("ScreenGui")
	gui.Name = "CollectionBinGui"; gui.ResetOnSpawn = false; gui.DisplayOrder = 14; gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets; gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local dim = Instance.new("Frame"); dim.Name = "Dim"; dim.Size = UDim2.fromScale(1, 1); dim.BackgroundColor3 = Color3.new(0, 0, 0); dim.BackgroundTransparency = 0.28; dim.BorderSizePixel = 0; dim.Parent = gui
	local panel = Instance.new("Frame")
	panel.Name = "Panel"; panel.AnchorPoint = Vector2.new(0.5, 0.5); panel.Position = UDim2.fromScale(0.5, 0.5); panel.Size = UDim2.new(0.78, 0, 0.72, 0)
	panel.BackgroundColor3 = CREAM; panel.BorderSizePixel = 0; panel.ClipsDescendants = true; panel.Parent = dim; round(panel, 24, 5, Color3.fromRGB(21, 91, 163))
	local sizeLimit = Instance.new("UISizeConstraint"); sizeLimit.MinSize = Vector2.new(560, 390); sizeLimit.MaxSize = Vector2.new(880, 600); sizeLimit.Parent = panel
	local accent = Instance.new("Frame"); accent.Name = "TopAccent"; accent.Position = UDim2.fromOffset(10, 8); accent.Size = UDim2.new(1, -20, 0, 8); accent.BackgroundColor3 = SKY; accent.BorderSizePixel = 0; accent.Parent = panel
	local accentCorner = Instance.new("UICorner"); accentCorner.CornerRadius = UDim.new(1, 0); accentCorner.Parent = accent
	local title = text(panel, "Title", "COLLECTION BIN", UDim2.fromOffset(26, 18), UDim2.new(1, -110, 0, 42), 32); title.TextXAlignment = Enum.TextXAlignment.Left
	local subtitle = text(panel, "Subtitle", "Junk saved while you were away.", UDim2.fromOffset(28, 59), UDim2.new(1, -130, 0, 28), 17); subtitle.TextXAlignment = Enum.TextXAlignment.Left; subtitle.TextColor3 = Color3.fromRGB(60, 83, 106)
	local close = button(panel, "Close", "X", UDim2.new(1, -70, 0, 20), UDim2.fromOffset(50, 50), CORAL)

	local status = Instance.new("Frame")
	status.Name = "Status"; status.Position = UDim2.fromOffset(22, 94); status.Size = UDim2.new(1, -44, 0, 52)
	status.BackgroundColor3 = Color3.fromRGB(220, 245, 255); status.BorderSizePixel = 0; status.Parent = panel; round(status, 15, 2, SKY)
	local timer = text(status, "Timer", "NEXT ITEM IN 15m 00s", UDim2.fromOffset(16, 8), UDim2.new(0.62, -16, 1, -16), 20); timer.TextXAlignment = Enum.TextXAlignment.Left
	local capacity = text(status, "Capacity", "0 / 12 ITEMS", UDim2.new(0.62, 0, 0, 8), UDim2.new(0.38, -16, 1, -16), 19); capacity.TextXAlignment = Enum.TextXAlignment.Right

	local overview = Instance.new("ScrollingFrame")
	overview.Name = "Overview"; overview.Position = UDim2.fromOffset(22, 158); overview.Size = UDim2.new(1, -44, 1, -246)
	overview.BackgroundTransparency = 1; overview.BorderSizePixel = 0; overview.AutomaticCanvasSize = Enum.AutomaticSize.Y; overview.CanvasSize = UDim2.fromOffset(0, 0)
	overview.ScrollBarThickness = 6; overview.ScrollBarImageColor3 = SKY; overview.Parent = panel
	local overviewPadding = Instance.new("UIPadding")
	overviewPadding.PaddingLeft = UDim.new(0, 4); overviewPadding.PaddingRight = UDim.new(0, 4); overviewPadding.PaddingTop = UDim.new(0, 4); overviewPadding.PaddingBottom = UDim.new(0, 4); overviewPadding.Parent = overview
	local overviewGrid = Instance.new("UIGridLayout")
	overviewGrid.CellSize = UDim2.new(0.25, -11, 0, 142); overviewGrid.CellPadding = UDim2.fromOffset(8, 8)
	overviewGrid.FillDirectionMaxCells = 4; overviewGrid.SortOrder = Enum.SortOrder.LayoutOrder; overviewGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center; overviewGrid.VerticalAlignment = Enum.VerticalAlignment.Top; overviewGrid.Parent = overview

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Items"; scroll.Position = UDim2.fromOffset(22, 158); scroll.Size = UDim2.new(1, -44, 1, -260); scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.CanvasSize = UDim2.fromOffset(0, 0); scroll.ScrollBarThickness = 7; scroll.ScrollBarImageColor3 = SKY; scroll.Visible = false; scroll.Parent = panel
	local list = Instance.new("UIListLayout"); list.Padding = UDim.new(0, 10); list.SortOrder = Enum.SortOrder.LayoutOrder; list.Parent = scroll

	local summary = text(panel, "Summary", "IN BIN 0  •  HOARD SPACE 0", UDim2.fromOffset(28, 1), UDim2.new(0.60, -35, 0, 54), 18)
	summary.AnchorPoint = Vector2.new(0, 1); summary.Position = UDim2.new(0, 28, 1, -18); summary.BackgroundTransparency = 0; summary.BackgroundColor3 = PALE; round(summary, 14, 2, Color3.fromRGB(83, 143, 182))
	local confirm = button(panel, "Confirm", "BIN IS EMPTY", UDim2.new(0.62, 0, 1, -72), UDim2.new(0.36, -20, 0, 54), MUTED)

	local self: any = setmetatable({
		gui = gui, panel = panel, sizeLimit = sizeLimit, subtitle = subtitle, status = status, timer = timer, capacity = capacity,
		overview = overview, overviewGrid = overviewGrid, scroll = scroll, summary = summary, confirm = confirm, actionRemote = actionRemote,
		rows = {}, overviewRows = {}, storeCounts = {}, sellCounts = {}, batchCounts = {}, token = nil, dismissedToken = nil,
		snapshot = {}, receivedAt = os.clock(), requestedOpen = false, mode = "OVERVIEW", running = true,
	}, CollectionBinController)

	for order, resourceId in ipairs(Config.resourceOrder) do
		local definition = Resources.get(resourceId) :: any
		local tile = Instance.new("Frame")
		tile.Name = resourceId .. "Tile"; tile.LayoutOrder = order; tile.BackgroundColor3 = PALE; tile.BorderSizePixel = 0; tile.Parent = overview; round(tile, 18, 3, SKY)
		local tileArt = Instance.new("Frame"); tileArt.Name = "Art"; tileArt.AnchorPoint = Vector2.new(0.5, 0); tileArt.Position = UDim2.new(0.5, 0, 0, 8); tileArt.Size = UDim2.fromOffset(74, 74)
		tileArt.BackgroundColor3 = Color3.fromRGB(213, 245, 255); tileArt.BorderSizePixel = 0; tileArt.ClipsDescendants = true; tileArt.Parent = tile; round(tileArt, 15, 2, SKY); UiArt.resource(tileArt, resourceId)
		local tileName = text(tile, "Name", definition.displayName, UDim2.fromOffset(8, 86), UDim2.new(1, -16, 0, 24), 18)
		local tileCount = text(tile, "Count", "×0", UDim2.fromOffset(8, 112), UDim2.new(1, -16, 0, 22), 19); tileCount.TextColor3 = GREEN
		self.overviewRows[resourceId] = { count = tileCount, tile = tile }

		local row = Instance.new("Frame")
		row.Name = resourceId .. "Row"; row.LayoutOrder = order; row.Size = UDim2.new(1, -8, 0, 112); row.BackgroundColor3 = PALE; row.BorderSizePixel = 0; row.Parent = scroll; round(row, 18, 3)
		local art = Instance.new("Frame"); art.Name = "Art"; art.Position = UDim2.fromOffset(10, 10); art.Size = UDim2.fromOffset(88, 88); art.BackgroundColor3 = Color3.fromRGB(213, 245, 255); art.BorderSizePixel = 0; art.ClipsDescendants = true; art.Parent = row; round(art, 15, 2, SKY); UiArt.resource(art, resourceId)
		local name = text(row, "Name", definition.displayName, UDim2.fromOffset(112, 12), UDim2.new(0.25, -112, 0, 34), 22); name.TextXAlignment = Enum.TextXAlignment.Left
		local available = text(row, "Available", "0 AVAILABLE", UDim2.fromOffset(112, 50), UDim2.new(0.25, -112, 0, 28), 15); available.TextXAlignment = Enum.TextXAlignment.Left; available.TextColor3 = Color3.fromRGB(60, 83, 106)
		local function chooser(labelText: string, x: number, color: Color3)
			local holder = Instance.new("Frame"); holder.Name = labelText; holder.Position = UDim2.new(x, 0, 0, 10); holder.Size = UDim2.new(0.22, -8, 0, 92); holder.BackgroundColor3 = CREAM; holder.BorderSizePixel = 0; holder.Parent = row; round(holder, 14, 2, color)
			local heading = text(holder, "Heading", labelText, UDim2.fromOffset(4, 4), UDim2.new(1, -8, 0, 24), 15); heading.TextColor3 = color
			local minus = button(holder, "Minus", "−", UDim2.fromOffset(7, 38), UDim2.fromOffset(36, 36), MUTED)
			local count = text(holder, "Count", "0", UDim2.new(0, 46, 0, 38), UDim2.new(1, -92, 0, 36), 21)
			local plus = button(holder, "Plus", "+", UDim2.new(1, -43, 0, 38), UDim2.fromOffset(36, 36), color)
			return { holder = holder, minus = minus, count = count, plus = plus }
		end
		local store = chooser("STORE", 0.27, SKY)
		local sell = chooser("SELL", 0.50, GREEN)
		local leaveHolder = Instance.new("Frame"); leaveHolder.Name = "Leave"; leaveHolder.Position = UDim2.new(0.73, 0, 0, 10); leaveHolder.Size = UDim2.new(0.25, -8, 0, 92); leaveHolder.BackgroundColor3 = CREAM; leaveHolder.BorderSizePixel = 0; leaveHolder.Parent = row; round(leaveHolder, 14, 2, ORANGE)
		local leaveTitle = text(leaveHolder, "Heading", "LEAVE IN BIN", UDim2.fromOffset(4, 8), UDim2.new(1, -8, 0, 28), 15); leaveTitle.TextColor3 = ORANGE
		local leave = text(leaveHolder, "Count", "0", UDim2.fromOffset(4, 43), UDim2.new(1, -8, 0, 36), 22)
		store.minus.Activated:Connect(function() self:change(resourceId, "STORE", -1) end)
		store.plus.Activated:Connect(function() self:change(resourceId, "STORE", 1) end)
		sell.minus.Activated:Connect(function() self:change(resourceId, "SELL", -1) end)
		sell.plus.Activated:Connect(function() self:change(resourceId, "SELL", 1) end)
		self.rows[resourceId] = { available = available, store = store, sell = sell, leave = leave }
	end

	close.Activated:Connect(function() self:close() end)
	confirm.Activated:Connect(function() if self.mode == "OVERVIEW" then self:collect() else self:submit() end end)
	self.inputConnection = UserInputService.InputBegan:Connect(function(input, processed) if not processed and input.KeyCode == Enum.KeyCode.Escape and self.gui.Enabled then self:close() end end)
	task.spawn(function() while self.running do if self.gui.Enabled then self:updateHeader() end; task.wait(1) end end)
	return self
end

function CollectionBinController:setMode(mode: string)
	self.mode = mode
	local choosing = mode == "CHOOSER"
	self.overview.Visible = not choosing
	self.scroll.Visible = choosing
	self.subtitle.Text = if choosing then "Your Hoard is full. Store, sell, or leave each item." else "Junk saved while you were away."
	self.panel.Size = if choosing then UDim2.new(0.9, 0, 0.86, 0) else UDim2.new(0.78, 0, 0.72, 0)
	self.sizeLimit.MinSize = if choosing then Vector2.new(620, 390) else Vector2.new(560, 390)
	self.sizeLimit.MaxSize = if choosing then Vector2.new(1120, 720) else Vector2.new(880, 600)
end

function CollectionBinController:updateHeader()
	local snapshot = self.snapshot
	local total = snapshot.collectionBinTotal or totalCounts(snapshot.collectionBinCounts or {})
	local maximum = snapshot.collectionBinCapacity or 0
	self.capacity.Text = string.format("%d / %d ITEMS", total, maximum)
	if maximum > 0 and total >= maximum then
		self.timer.Text = "BIN FULL  •  PRODUCTION PAUSED"
		self.timer.TextColor3 = ORANGE
	else
		local now = (snapshot.serverNow or 0) + math.max(0, os.clock() - self.receivedAt)
		self.timer.Text = "NEXT ITEM IN " .. duration((snapshot.collectionBinNextAt or now) - now)
		self.timer.TextColor3 = INK
	end
end

function CollectionBinController:open()
	self.requestedOpen = true
	self:setMode(if self.snapshot.collectionBinPending == true then "CHOOSER" else "OVERVIEW")
	self.gui.Enabled = true
	self:draw()
end

function CollectionBinController:close()
	self.requestedOpen = false
	if self.token ~= nil then
		self.dismissedToken = self.token
		self.actionRemote:FireServer("CANCEL_COLLECTION_BIN", { token = self.token })
	end
	self.gui.Enabled = false
end

function CollectionBinController:collect()
	local total = self.snapshot.collectionBinTotal or totalCounts(self.snapshot.collectionBinCounts or {})
	if total <= 0 then return end
	self.requestedOpen = false
	self.gui.Enabled = false
	self.actionRemote:FireServer("OPEN_COLLECTION_BIN")
end

function CollectionBinController:submit()
	if self.token ~= nil and totalCounts(self.storeCounts) + totalCounts(self.sellCounts) > 0 then
		self.actionRemote:FireServer("RESOLVE_COLLECTION_BIN", { token = self.token, storeCounts = table.clone(self.storeCounts), sellCounts = table.clone(self.sellCounts) })
	end
end

function CollectionBinController:change(resourceId: string, kind: string, delta: number)
	local batch = self.batchCounts[resourceId] or 0
	local currentStore = self.storeCounts[resourceId] or 0
	local currentSell = self.sellCounts[resourceId] or 0
	if kind == "STORE" then
		local free = math.max(0, (self.snapshot.freeSlots or 0) - totalCounts(self.storeCounts) + currentStore)
		self.storeCounts[resourceId] = math.clamp(currentStore + delta, 0, math.min(batch - currentSell, free))
	else
		self.sellCounts[resourceId] = math.clamp(currentSell + delta, 0, batch - currentStore)
	end
	self:draw()
end

function CollectionBinController:draw()
	self:updateHeader()
	local snapshotCounts = self.snapshot.collectionBinCounts or {}
	for _, resourceId in ipairs(Config.resourceOrder) do
		self.overviewRows[resourceId].count.Text = string.format("×%d", snapshotCounts[resourceId] or 0)
	end
	if self.mode == "OVERVIEW" then
		local total = self.snapshot.collectionBinTotal or totalCounts(snapshotCounts)
		self.summary.Text = string.format("IN BIN %d  •  HOARD SPACE %d", total, self.snapshot.freeSlots or 0)
		self.confirm.Text = if total > 0 then string.format("COLLECT %d ITEMS", total) else "BIN IS EMPTY"
		self.confirm.Active = total > 0; self.confirm.AutoButtonColor = total > 0; self.confirm.BackgroundColor3 = if total > 0 then GREEN else MUTED
		return
	end

	local storeTotal, sellTotal, leaveTotal, value = 0, 0, 0, 0
	for _, resourceId in ipairs(Config.resourceOrder) do
		local batch = self.batchCounts[resourceId] or 0
		local store = self.storeCounts[resourceId] or 0
		local sell = self.sellCounts[resourceId] or 0
		local leave = math.max(0, batch - store - sell)
		local row = self.rows[resourceId]
		row.available.Text = string.format("%d AVAILABLE", batch)
		row.store.count.Text = tostring(store); row.sell.count.Text = tostring(sell); row.leave.Text = tostring(leave)
		storeTotal += store; sellTotal += sell; leaveTotal += leave
		local definition = Resources.get(resourceId); if definition then value += sell * definition.sellValue end
	end
	self.summary.Text = string.format("STORE %d  •  SELL %d FOR $%d  •  LEAVE %d", storeTotal, sellTotal, value, leaveTotal)
	self.confirm.Text = "CONFIRM"
	local enabled = storeTotal + sellTotal > 0
	self.confirm.Active = enabled; self.confirm.AutoButtonColor = enabled; self.confirm.BackgroundColor3 = if enabled then ORANGE else MUTED
end

function CollectionBinController:render(snapshot: any)
	self.snapshot = snapshot
	self.receivedAt = os.clock()
	if snapshot.collectionBinPending == true then
		local token = snapshot.collectionBinToken
		if self.dismissedToken == token then self.gui.Enabled = false; return end
		if self.dismissedToken ~= nil and self.dismissedToken ~= token then self.dismissedToken = nil end
		if self.token ~= token then
			self.token = token
			self.storeCounts = {}; self.sellCounts = {}
			for _, resourceId in ipairs(Config.resourceOrder) do self.storeCounts[resourceId] = 0; self.sellCounts[resourceId] = 0 end
		end
		self.batchCounts = table.clone(snapshot.collectionBinBatchCounts or {})
		self.requestedOpen = false
		self:setMode("CHOOSER")
		self.gui.Enabled = true
		self:draw()
		return
	end

	self.token = nil
	self.dismissedToken = nil
	self.batchCounts = table.clone(snapshot.collectionBinCounts or {})
	if self.requestedOpen then
		self:setMode("OVERVIEW")
		self.gui.Enabled = true
		self:draw()
	else
		self.gui.Enabled = false
	end
end

function CollectionBinController:destroy()
	self.running = false
	if self.inputConnection then self.inputConnection:Disconnect() end
	self.gui:Destroy()
end

return CollectionBinController
