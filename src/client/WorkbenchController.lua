--!strict
-- Full-screen, image-led owner workbench with visual recipe requirements.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Stage1Config"))
local Recipes = require(Shared:WaitForChild("RecipeDefinitions"))
local Resources = require(Shared:WaitForChild("ResourceDefinitions"))
local SpecialItems = require(Shared:WaitForChild("SpecialItemDefinitions"))
local UiPresentation = require(Shared:WaitForChild("UiPresentation"))
local IndexController = require(script.Parent:WaitForChild("IndexController"))
local UiArt = require(script.Parent:WaitForChild("UiArt"))
local TutorialOverlay = require(script.Parent:WaitForChild("TutorialOverlay"))

local WorkbenchController = {}
WorkbenchController.__index = WorkbenchController

local SKY = Color3.fromRGB(82, 194, 238)
local SKY_LIGHT = Color3.fromRGB(213, 245, 255)
local CREAM = Color3.fromRGB(255, 249, 222)
local PALE = Color3.fromRGB(246, 252, 255)
local INK = Color3.fromRGB(22, 56, 91)
local ORANGE = Color3.fromRGB(242, 111, 48)
local GREEN = Color3.fromRGB(104, 211, 67)
local CORAL = Color3.fromRGB(238, 84, 72)
local MUTED = Color3.fromRGB(183, 201, 215)
local SECONDARY = Color3.fromRGB(60, 83, 106)
local READY_INK = Color3.fromRGB(31, 125, 63)
local MISSING_INK = Color3.fromRGB(156, 83, 36)

local function isTracked(snapshot: any, recipeId: string): boolean
	return table.find(snapshot.trackedRecipeIds or {}, recipeId) ~= nil
end

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
	result.AutoButtonColor = false
	result.Text = value
	result.Font = Enum.Font.FredokaOne
	result.TextColor3 = INK
	result.Parent = parent
	decorate(result, 14, 3)
	constrainText(result, 15, 25)
	return result
end

local function makeArtHolder(parent: Instance, name: string, position: UDim2, size: UDim2): Frame
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

local function missingDependency(snapshot: any, recipe: any): string?
	local crafted = snapshot.crafted or {}
	if recipe.categoryRequires and not crafted[recipe.categoryRequires] then
		local dependency = Recipes.get(recipe.categoryRequires)
		return if dependency then string.upper(dependency.displayName) else "WORKSHOP II"
	end
	if recipe.requires and not crafted[recipe.requires] then
		local dependency = Recipes.get(recipe.requires)
		return if dependency then string.upper(dependency.displayName) else "REQUIRED UPGRADE"
	end
	return nil
end

local function recipeState(snapshot: any, recipe: any): (string, boolean)
	if snapshot.crafted and snapshot.crafted[recipe.id] == true then return "CRAFTED", false end
	local dependency = missingDependency(snapshot, recipe)
	if dependency then return "REQUIRES " .. dependency, false end
	local counts = snapshot.hoardCounts or {}
	for resourceId, needed in pairs(recipe.resources) do
		if (counts[resourceId] or 0) < needed then return "NEED ITEMS", false end
	end
	for itemId, needed in pairs(recipe.specialItems or {}) do
		if ((snapshot.specialItemCounts or {})[itemId] or 0) < needed then return "NEED GEM", false end
	end
	if (snapshot.coins or 0) < recipe.coinCost then return "NEED COINS", false end
	return "CRAFT", true
end

local function craftStatus(snapshot: any, recipe: any): (string, Color3)
	local state, ready = recipeState(snapshot, recipe)
	if state == "CRAFTED" then return "CRAFTED", READY_INK end
	if ready then return "READY TO CRAFT", READY_INK end
	return "NEEDS ITEMS", MISSING_INK
end

function WorkbenchController.new(actionRemote: RemoteEvent): any
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("WorkbenchGui")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "WorkbenchGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Enabled = false
	gui.Parent = playerGui
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.3
	dim.BorderSizePixel = 0
	dim.Parent = gui
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(1, -8, 1, -8)
	panel.BackgroundColor3 = SKY
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.Parent = dim
	decorate(panel, 22, 4)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 64)
	header.BackgroundColor3 = Color3.fromRGB(226, 247, 255)
	header.BorderSizePixel = 0
	header.Parent = panel
	local title = label(header, "Title", "WORKBENCH", UDim2.fromOffset(18, 8), UDim2.fromOffset(170, 58), 18, 34)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local buildingsTab = button(header, "BuildingsTab", "BUILDINGS", UDim2.new(0.5, -204, 0, 6), UDim2.fromOffset(130, 52))
	local upgradesTab = button(header, "UpgradesTab", "UPGRADES", UDim2.new(0.5, -65, 0, 6), UDim2.fromOffset(130, 52))
	local inventoryTab = button(header, "InventoryTab", "INVENTORY", UDim2.new(0.5, 74, 0, 6), UDim2.fromOffset(130, 52))
	local close = button(header, "Close", "X", UDim2.new(1, -66, 0, 10), UDim2.fromOffset(54, 54))
	close.BackgroundColor3 = CORAL
	local upgrades = Instance.new("Frame")
	upgrades.Name = "UpgradesPanel"
	upgrades.Position = UDim2.fromOffset(8, 72)
	upgrades.Size = UDim2.new(1, -16, 1, -80)
	upgrades.BackgroundTransparency = 1
	upgrades.Parent = panel
	local categoryBar = Instance.new("Frame")
	categoryBar.Name = "CategoryBar"
	categoryBar.Size = UDim2.new(0.43, -7, 0, 42)
	categoryBar.BackgroundTransparency = 1
	categoryBar.Parent = upgrades
	local starterCategory = button(categoryBar, "StarterCategory", "STARTER", UDim2.fromOffset(0, 0), UDim2.new(0.5, -5, 1, 0))
	local workshopCategory = button(categoryBar, "Workshop2Category", "WORKSHOP II  LOCKED", UDim2.new(0.5, 5, 0, 0), UDim2.new(0.5, -5, 1, 0))
	local gridFrame = Instance.new("ScrollingFrame")
	gridFrame.Name = "UpgradeGrid"
	gridFrame.Position = UDim2.fromOffset(0, 48)
	gridFrame.Size = UDim2.new(0.43, -7, 1, -48)
	gridFrame.BackgroundTransparency = 1
	gridFrame.BorderSizePixel = 0
	gridFrame.ScrollBarThickness = 6
	gridFrame.ScrollBarImageColor3 = INK
	gridFrame.CanvasSize = UDim2.fromOffset(0, 0)
	gridFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	gridFrame.Parent = upgrades
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = gridFrame
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -10, 0, 168)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = gridFrame
	local function resizeGrid()
		local compact = gridFrame.AbsoluteSize.Y < 460
		grid.CellSize = UDim2.new(0.5, -10, 0, if compact then 136 else 168)
		gridFrame.CanvasSize = UDim2.fromOffset(0, grid.AbsoluteContentSize.Y + 8)
	end
	gridFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeGrid)
	grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizeGrid)
	resizeGrid()
	local detail = Instance.new("Frame")
	detail.Name = "SelectedRecipe"
	detail.Position = UDim2.new(0.43, 7, 0, 0)
	detail.Size = UDim2.new(0.57, -7, 1, 0)
	detail.BackgroundColor3 = CREAM
	detail.BorderSizePixel = 0
	detail.ClipsDescendants = true
	detail.Parent = upgrades
	decorate(detail, 18, 3)
	local recipeCards: { [string]: any } = {}
	local self: any = setmetatable({
		gui = gui, header = header, title = title, upgrades = upgrades, buildingsTab = buildingsTab, upgradesTab = upgradesTab, inventoryTab = inventoryTab,
		panel = panel, gridFrame = gridFrame, recipeCards = recipeCards, detail = detail, detailRows = {}, detailCraft = nil,
		categoryBar = categoryBar, starterCategory = starterCategory, workshopCategory = workshopCategory, activeCategory = "STARTER", activeTab = "BUILDINGS",
		detailDependency = nil, selectedRecipeId = "AFKSorter", currentSnapshot = {}, detailTrack = nil,
		actionRemote = actionRemote, plotId = nil, prompt = nil, promptConnection = nil, running = true,
		tutorialStepSeen = -1,
	}, WorkbenchController)
	for _, recipe in ipairs(Recipes.ordered()) do
		local card = Instance.new("TextButton")
		card.Name = recipe.id .. "Card"
		card.LayoutOrder = recipe.order
		card.BackgroundColor3 = PALE
		card.BorderSizePixel = 0
		card.AutoButtonColor = false
		card.Text = ""
		card.Parent = gridFrame
		local cardStroke = decorate(card, 18, 3)
		local artHolder = makeArtHolder(card, "Art", UDim2.new(0.17, 0, 0.04, 0), UDim2.new(0.66, 0, 0.50, 0))
		UiArt.recipe(artHolder, recipe.id)
		local recipeName = label(card, "RecipeName", recipe.displayName, UDim2.new(0.05, 0, 0.56, 0), UDim2.new(0.9, 0, 0.16, 0), 12, 21)
		recipeName.TextXAlignment = Enum.TextXAlignment.Center
		local benefit = label(card, "Benefit", UiPresentation.benefitText(recipe), UDim2.new(0.05, 0, 0.72, 0), UDim2.new(0.9, 0, 0.14, 0), 10, 16)
		benefit.TextColor3 = Color3.fromRGB(31, 125, 63)
		local status = label(card, "Status", "", UDim2.new(0.13, 0, 0.86, 0), UDim2.new(0.74, 0, 0.11, 0), 10, 14)
		status.TextColor3 = SECONDARY
		card.Activated:Connect(function() self:selectRecipe(recipe.id) end)
		local tracked = label(card, "Tracked", "TRACKED", UDim2.fromOffset(8, 7), UDim2.fromOffset(76, 20), 10, 12)
		tracked.BackgroundTransparency = 0
		tracked.BackgroundColor3 = SKY_LIGHT
		tracked.Visible = false
		decorate(tracked, 7, 1, SKY)
		recipeCards[recipe.id] = { button = card, stroke = cardStroke, status = status, tracked = tracked }
	end
	self.inventory = IndexController.new(panel, actionRemote)
	self.overlay = TutorialOverlay.new(gui)
	self:selectRecipe("AFKSorter")
	function self:setCategory(category: string)
		if self.activeTab == "UPGRADES" and category == "WORKSHOP_2" and not (self.currentSnapshot.crafted and self.currentSnapshot.crafted.WorkshopLevel2) then return end
		self.activeCategory = category
		for recipeId, card in pairs(self.recipeCards) do
			local recipe = Recipes.get(recipeId)
			card.button.Visible = recipe ~= nil and recipe.workbenchTab == self.activeTab and (self.activeTab == "BUILDINGS" or recipe.category == category)
		end
		local showCategories = self.activeTab == "UPGRADES"
		self.categoryBar.Visible = showCategories
		self.gridFrame.Position = UDim2.fromOffset(0, if showCategories then 48 else 0)
		self.gridFrame.Size = UDim2.new(0.43, -7, 1, if showCategories then -48 else 0)
		self.starterCategory.BackgroundColor3 = if category == "STARTER" then GREEN else MUTED
		self.workshopCategory.BackgroundColor3 = if category == "WORKSHOP_2" then GREEN else MUTED
		local selected = Recipes.get(self.selectedRecipeId)
		if selected == nil or selected.workbenchTab ~= self.activeTab or (self.activeTab == "UPGRADES" and selected.category ~= category) then
			for _, recipe in ipairs(Recipes.ordered()) do
				if recipe.workbenchTab == self.activeTab and (self.activeTab == "BUILDINGS" or recipe.category == category) then self:selectRecipe(recipe.id); break end
			end
		end
	end
	starterCategory.Activated:Connect(function() self:setCategory("STARTER") end)
	workshopCategory.Activated:Connect(function() self:setCategory("WORKSHOP_2") end)
	self:setCategory("STARTER")
	self:layout()
	function self:setTab(tab: string)
		if tab ~= "BUILDINGS" and tab ~= "UPGRADES" and tab ~= "INVENTORY" then return end
		self.activeTab = tab
		local showRecipes = tab ~= "INVENTORY"
		self.title.Text = if tab == "BUILDINGS" then "BUILDINGS" elseif tab == "UPGRADES" then "WORKBENCH" else "INVENTORY"
		self.upgrades.Visible = showRecipes
		self.inventory:setVisible(tab == "INVENTORY")
		self.buildingsTab.BackgroundColor3 = if tab == "BUILDINGS" then GREEN else MUTED
		self.upgradesTab.BackgroundColor3 = if tab == "UPGRADES" then GREEN else MUTED
		self.inventoryTab.BackgroundColor3 = if tab == "INVENTORY" then GREEN else MUTED
		if showRecipes then self:setCategory(self.activeCategory) end
	end
	self:setTab("BUILDINGS")
	buildingsTab.Activated:Connect(function() self:setTab("BUILDINGS") end)
	upgradesTab.Activated:Connect(function() self:setTab("UPGRADES") end)
	inventoryTab.Activated:Connect(function() self:setTab("INVENTORY") end)
	close.Activated:Connect(function() gui.Enabled = false end)
	self.inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape and gui.Enabled then gui.Enabled = false end
	end)
	if Workspace.CurrentCamera then
		self.viewportConnection = Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() self:layout() end)
	end
	task.spawn(function()
		while self.running do self:refreshPrompt(); task.wait(0.5) end
	end)
	return self
end

function WorkbenchController:layout()
	local camera = Workspace.CurrentCamera
	local compact = camera ~= nil and camera.ViewportSize.Y < 550
	local narrow = camera ~= nil and camera.ViewportSize.X < 900
	self.title.Visible = not narrow
	local tabY = if compact then 4 else 6
	self.buildingsTab.Position = UDim2.new(0.5, -204, 0, tabY)
	self.upgradesTab.Position = UDim2.new(0.5, -65, 0, tabY)
	self.inventoryTab.Position = UDim2.new(0.5, 74, 0, tabY)
	if self.inventory then self.inventory:layout(compact) end
	self.header.Size = UDim2.new(1, 0, 0, if compact then 60 else 64)
	self.upgrades.Position = UDim2.fromOffset(8, if compact then 66 else 72)
	self.upgrades.Size = UDim2.new(1, -16, 1, if compact then -72 else -80)
	local hero = self.detail:FindFirstChild("HeroArt") :: GuiObject?
	local title = self.detail:FindFirstChild("RecipeTitle") :: GuiObject?
	local benefit = self.detail:FindFirstChild("Benefit") :: GuiObject?
	local dependency = self.detail:FindFirstChild("Dependency") :: GuiObject?
	local requiresTitle = self.detail:FindFirstChild("RequiresTitle") :: GuiObject?
	local requirements = self.detail:FindFirstChild("Requirements") :: GuiObject?
	local craft = self.detail:FindFirstChild("CraftButton") :: GuiObject?
	local trackButton = self.detail:FindFirstChild("TrackButton") :: GuiObject?
	if not hero or not title or not benefit or not dependency or not requiresTitle or not requirements or not craft or not trackButton then return end
	local detailHeight = self.detail.AbsoluteSize.Y
	if compact then
		hero.Position = UDim2.new(0.025, 0, 0, 5); hero.Size = UDim2.new(0.20, 0, 0, 62)
		title.Position = UDim2.new(0.25, 0, 0, 4); title.Size = UDim2.new(0.72, 0, 0, 28)
		benefit.Position = UDim2.new(0.25, 0, 0, 32); benefit.Size = UDim2.new(0.72, -8, 0, 23)
		dependency.Position = UDim2.new(0.025, 0, 0, 82); dependency.Size = UDim2.new(0.95, 0, 0, 24)
		craft.Position = UDim2.new(0.38, 3, 1, -50); craft.Size = UDim2.new(0.595, -3, 0, 44)
		trackButton.Position = UDim2.new(0.025, 0, 1, -50); trackButton.Size = UDim2.new(0.35, -3, 0, 44)
	else
		hero.Position = UDim2.new(0.025, 0, 0, 6); hero.Size = UDim2.new(0.20, 0, 0, 92)
		title.Position = UDim2.new(0.25, 0, 0, 5); title.Size = UDim2.new(0.72, 0, 0, 38)
		benefit.Position = UDim2.new(0.25, 0, 0, 46); benefit.Size = UDim2.new(0.72, -8, 0, 25)
		dependency.Position = UDim2.new(0.025, 0, 0, 96); dependency.Size = UDim2.new(0.95, 0, 0, 20)
		craft.Position = UDim2.new(0.38, 3, 1, -64); craft.Size = UDim2.new(0.595, -3, 0, 56)
		trackButton.Position = UDim2.new(0.025, 0, 1, -64); trackButton.Size = UDim2.new(0.35, -3, 0, 56)
	end
	self.detailTracked.Position = UDim2.new(0.25, 0, 0, if compact then 59 else 76)
	self.detailTracked.Size = UDim2.new(0.23, 0, 0, 18)
	self.detailState.Position = UDim2.new(0.49, 0, 0, if compact then 59 else 76)
	self.detailState.Size = UDim2.new(0.48, -8, 0, 18)
	local top = if compact then 82 else 96
	if dependency.Visible then top += if compact then 26 else 22 end
	local titleHeight = 20
	local listTop = top + titleHeight
	local listBottom = detailHeight - (if compact then 54 else 70)
	requiresTitle.Position = UDim2.new(0.035, 0, 0, top)
	requiresTitle.Size = UDim2.new(0.93, 0, 0, titleHeight)
	requirements.Position = UDim2.new(0.025, 0, 0, listTop)
	requirements.Size = UDim2.new(0.95, 0, 0, math.max(30, listBottom - listTop))
	local rowCount = 0
	for _ in pairs(self.detailRows) do rowCount += 1 end
	local rowPadding = if compact then 5 else 6
	local available = math.max(30, listBottom - listTop - 8)
	local rowHeight = if rowCount > 0 then math.clamp(math.floor((available - rowPadding * (rowCount - 1)) / rowCount), 56, 64) else 64
	local list = requirements:FindFirstChildOfClass("UIListLayout")
	if list then list.Padding = UDim.new(0, rowPadding) end
	for _, rowData in pairs(self.detailRows) do
		rowData.row.Size = UDim2.new(1, 0, 0, rowHeight)
		rowData.icon.Position = UDim2.fromOffset(8, math.floor((rowHeight - 48) / 2))
		rowData.icon.Size = UDim2.fromOffset(48, 48)
		rowData.name.Position = UDim2.fromOffset(64, 3)
		rowData.name.Size = UDim2.new(0.55, -64, 0, 20)
		rowData.count.Position = UDim2.new(0.55, 0, 0, 3)
		rowData.count.Size = UDim2.new(0.45, -10, 0, 20)
		rowData.status.Position = UDim2.fromOffset(64, 25)
		rowData.status.Size = UDim2.new(1, -74, 0, 14)
		rowData.track.Position = UDim2.fromOffset(64, rowHeight - 12)
		rowData.track.Size = UDim2.new(1, -74, 0, 6)
	end
end

function WorkbenchController:selectRecipe(recipeId: string)
	local recipe = Recipes.get(recipeId)
	if recipe == nil then return end
	self.selectedRecipeId = recipeId
	self:renderCards()
	self.detail:ClearAllChildren()
	decorate(self.detail, 18, 3)
	local artHolder = makeArtHolder(self.detail, "HeroArt", UDim2.new(0.03, 0, 0.03, 0), UDim2.new(0.27, 0, 0, 132))
	UiArt.recipe(artHolder, recipe.id)
	local title = label(self.detail, "RecipeTitle", string.upper(recipe.displayName), UDim2.new(0.33, 0, 0.035, 0), UDim2.new(0.64, 0, 0, 58), 16, 30)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local benefit = label(self.detail, "Benefit", UiPresentation.benefitText(recipe), UDim2.new(0.33, 0, 0, 62), UDim2.new(0.64, -8, 0, 52), 12, 21)
	benefit.BackgroundTransparency = 0
	benefit.BackgroundColor3 = Color3.fromRGB(211, 255, 173)
	benefit.TextColor3 = Color3.fromRGB(31, 125, 63)
	decorate(benefit, 13, 2, Color3.fromRGB(51, 158, 62))
	local tracked = label(self.detail, "Tracked", "TRACKED", UDim2.fromOffset(0, 0), UDim2.fromOffset(80, 18), 10, 12)
	tracked.BackgroundTransparency = 0
	tracked.BackgroundColor3 = SKY_LIGHT
	decorate(tracked, 6, 1, SKY)
	self.detailTracked = tracked
	self.detailState = label(self.detail, "CraftState", "", UDim2.fromOffset(0, 0), UDim2.fromOffset(140, 18), 10, 14)
	local dependency = label(self.detail, "Dependency", "", UDim2.new(0.03, 0, 0, 144), UDim2.new(0.94, 0, 0, 34), 12, 18)
	dependency.BackgroundTransparency = 0
	dependency.BackgroundColor3 = Color3.fromRGB(255, 220, 171)
	dependency.TextColor3 = Color3.fromRGB(154, 73, 31)
	decorate(dependency, 10, 2, Color3.fromRGB(197, 103, 42))
	self.detailDependency = dependency
	local requiresTitle = label(self.detail, "RequiresTitle", "REQUIRES  •  OWNED / NEEDED", UDim2.new(0.04, 0, 0, 184), UDim2.new(0.92, 0, 0, 30), 11, 17)
	requiresTitle.TextXAlignment = Enum.TextXAlignment.Left
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Requirements"
	scroll.Position = UDim2.new(0.03, 0, 0, 216)
	scroll.Size = UDim2.new(0.94, 0, 1, -304)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 7
	scroll.ScrollBarImageColor3 = SKY
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = self.detail
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = scroll
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 7)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll
	self.detailRows = {}
	local function addRequirement(kind: string, displayName: string, needed: number, order: number)
		local row = Instance.new("Frame")
		row.Name = kind .. "Requirement"
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -9, 0, 68)
		row.BackgroundColor3 = Color3.fromRGB(244, 248, 251)
		row.BorderSizePixel = 0
		row.Parent = scroll
		decorate(row, 12, 2, Color3.fromRGB(101, 132, 154))
		local icon = makeArtHolder(row, "Icon", UDim2.fromOffset(6, 6), UDim2.fromOffset(56, 56))
		if kind == "Coins" then UiArt.coin(icon) else UiArt.resource(icon, kind) end
		local rowName = label(row, "Name", displayName, UDim2.fromOffset(72, 5), UDim2.new(0.5, -72, 0, 28), 11, 18)
		rowName.TextXAlignment = Enum.TextXAlignment.Left
		local count = label(row, "Count", "0 / 0", UDim2.new(0.5, 0, 0, 5), UDim2.new(0.5, -12, 0, 28), 11, 19)
		count.TextXAlignment = Enum.TextXAlignment.Right
		local status = label(row, "Status", "", UDim2.fromOffset(64, 25), UDim2.new(1, -74, 0, 14), 10, 12)
		status.TextXAlignment = Enum.TextXAlignment.Left
		local track = Instance.new("Frame")
		track.Name = "ProgressTrack"
		track.Position = UDim2.fromOffset(72, 39)
		track.Size = UDim2.new(1, -84, 0, 17)
		track.BackgroundColor3 = Color3.fromRGB(210, 222, 231)
		track.BorderSizePixel = 0
		track.ClipsDescendants = true
		track.Parent = row
		decorate(track, 8, 2, Color3.fromRGB(101, 132, 154))
		local fill = Instance.new("Frame")
		fill.Name = "ProgressFill"
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = GREEN
		fill.BorderSizePixel = 0
		fill.Parent = track
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill
		self.detailRows[kind] = { row = row, icon = icon, name = rowName, count = count, status = status, track = track, fill = fill, needed = needed }
	end
	local order = 0
	for _, resourceId in ipairs(Config.resourceOrder) do
		local needed = recipe.resources[resourceId]
		if needed then
			order += 1
			local definition = Resources.get(resourceId) :: Resources.ResourceDefinition
			addRequirement(resourceId, definition.displayName, needed, order)
		end
	end
	for _, definition in ipairs(SpecialItems.ordered()) do
		local needed = if recipe.specialItems then recipe.specialItems[definition.id] else nil
		if needed then order += 1; addRequirement(definition.id, definition.displayName, needed, order) end
	end
	addRequirement("Coins", "Coins", recipe.coinCost, order + 1)
	local trackButton = button(self.detail, "TrackButton", "TRACK", UDim2.new(0.03, 0, 1, -78), UDim2.new(0.32, 0, 0, 68))
	trackButton.BackgroundColor3 = SKY
	trackButton.Activated:Connect(function()
		self:toggleTracking()
	end)
	local craft = button(self.detail, "CraftButton", "CRAFT", UDim2.new(0.37, 0, 1, -78), UDim2.new(0.60, 0, 0, 68))
	craft.Activated:Connect(function()
		local _, enabled = recipeState(self.currentSnapshot, recipe)
		if enabled then self.actionRemote:FireServer("CRAFT", recipe.id) end
	end)
	self.detailCraft = craft
	self.detailTrack = trackButton
	self:renderSelected()
	self:layout()
end

function WorkbenchController:toggleTracking()
	local recipe = Recipes.get(self.selectedRecipeId)
	if recipe == nil or (self.currentSnapshot.crafted or {})[recipe.id] then return end
	self.actionRemote:FireServer("TRACK", { recipeId = recipe.id, action = if isTracked(self.currentSnapshot, recipe.id) then "REMOVE" else "ADD" })
end

function WorkbenchController:renderCards()
	for id, card in pairs(self.recipeCards) do
		local recipe = Recipes.get(id)
		local selected = id == self.selectedRecipeId
		local tracked = isTracked(self.currentSnapshot, id) and not (self.currentSnapshot.crafted or {})[id]
		card.button.BackgroundColor3 = if selected then Color3.fromRGB(228, 255, 218) else PALE
		card.stroke.Color = if tracked then SKY elseif selected then Color3.fromRGB(63, 115, 149) else INK
		card.stroke.Thickness = if selected or tracked then 4 else 3
		card.tracked.Visible = tracked
		card.status.Text, card.status.TextColor3 = craftStatus(self.currentSnapshot, recipe)
	end
end

function WorkbenchController:renderSelected()
	local recipe = Recipes.get(self.selectedRecipeId)
	if recipe == nil or self.detailCraft == nil or self.detailDependency == nil or self.detailTrack == nil then return end
	local counts = self.currentSnapshot.hoardCounts or {}
	for kind, row in pairs(self.detailRows) do
		local owned = if kind == "Coins" then self.currentSnapshot.coins or 0 elseif SpecialItems.get(kind) then (self.currentSnapshot.specialItemCounts or {})[kind] or 0 else counts[kind] or 0
		local met = owned >= row.needed
		row.count.Text = if kind == "Coins" then string.format("$%.1f / $%d", owned, row.needed) else string.format("%d / %d", owned, row.needed)
		row.count.TextColor3 = if met then Color3.fromRGB(31, 125, 63) else CORAL
		local missing = math.max(0, row.needed - owned)
		row.status.Text = if met then "✓  REQUIREMENT MET" elseif kind == "Coins" then string.format("NEED $%.1f MORE", missing) else string.format("NEED %d MORE", missing)
		row.status.TextColor3 = if met then READY_INK else CORAL
		row.fill.Size = UDim2.fromScale(math.clamp(owned / row.needed, 0, 1), 1)
		row.fill.BackgroundColor3 = if met then GREEN else CORAL
		row.row.BackgroundColor3 = if met then Color3.fromRGB(235, 255, 225) else Color3.fromRGB(255, 241, 227)
	end
	local dependency = missingDependency(self.currentSnapshot, recipe)
	self.detailDependency.Visible = dependency ~= nil
	self.detailDependency.Text = if dependency then "CRAFT " .. dependency .. " FIRST" else ""
	self:layout()
	local stateText, enabled = recipeState(self.currentSnapshot, recipe)
	self.detailCraft.Text = if stateText == "CRAFTED" then "CRAFTED" elseif enabled then "CRAFT" else "NEED ITEMS"
	self.detailCraft.Active = enabled
	self.detailCraft.AutoButtonColor = enabled
	self.detailCraft.BackgroundColor3 = if stateText == "CRAFTED" then GREEN elseif enabled then ORANGE else MUTED
	local tracked = isTracked(self.currentSnapshot, recipe.id) and stateText ~= "CRAFTED"
	self.detailTracked.Visible = tracked
	self.detailState.Text, self.detailState.TextColor3 = craftStatus(self.currentSnapshot, recipe)
	self.detailTrack.Text = if stateText == "CRAFTED" then "CRAFTED" elseif tracked then "TRACKED ✓" else "TRACK"
	self.detailTrack.Active = stateText ~= "CRAFTED"
	self.detailTrack.AutoButtonColor = self.detailTrack.Active
	self.detailTrack.BackgroundColor3 = if self.detailTrack.Active then SKY else MUTED
end

function WorkbenchController:setTutorial(snapshot: any)
	local step = snapshot.tutorialStep or 0
	if step ~= self.tutorialStepSeen then
		self.tutorialStepSeen = step
		if step == 2 then self:setTab("INVENTORY"); if snapshot.tutorialDuplicateResourceId then self.inventory:select(snapshot.tutorialDuplicateResourceId) end
		elseif step == 3 then self:setTab("BUILDINGS"); self:setCategory("STARTER"); self:selectRecipe("AFKSorter")
		elseif step == 4 then
			self:setTab("BUILDINGS"); self:setCategory("STARTER"); self:selectRecipe("CollectionBin")
		else self.overlay:setTarget(nil) end
	end
	if not self.gui.Enabled then self.overlay:setTarget(nil); return end
	if step == 2 then
		local duplicate = snapshot.tutorialDuplicateResourceId
		local card = if duplicate and self.inventory.cards[duplicate] then self.inventory.cards[duplicate].button else nil
		local target = if self.inventory.selectedResourceId == duplicate then self.inventory.sellSelected else card
		self.overlay:setTarget(target, if target == self.inventory.sellSelected then "SELL ONE SPARE ITEM" else "CHOOSE YOUR DUPLICATE ITEM")
	elseif step == 3 then self.overlay:setTarget(self.detailCraft, "BUILD YOUR AFK SORTER")
	elseif step == 4 then self.overlay:setTarget(self.detailTrack, "TRACK THE COLLECTION BIN")
	else self.overlay:setTarget(nil) end
end

function WorkbenchController:refreshPrompt()
	local hoard = Workspace:FindFirstChild("Hoard")
	local plots = if hoard then hoard:FindFirstChild("Plots") else nil
	local plot = if plots and self.plotId then plots:FindFirstChild(string.format("Plot%d", self.plotId)) else nil
	local bench = if plot then plot:FindFirstChild("Workbench") else nil
	if bench == nil or not bench:IsA("BasePart") or (self.prompt and self.prompt.Parent == bench) then return end
	if self.prompt then self.prompt:Destroy() end
	if self.promptConnection then self.promptConnection:Disconnect() end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WorkbenchPrompt"
	prompt.ActionText = "Open Workbench"
	prompt.ObjectText = "Your Hoard"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.workbenchRange
	prompt.RequiresLineOfSight = false
	prompt.ClickablePrompt = true
	prompt.Parent = bench
	self.prompt = prompt
	self.promptConnection = prompt.Triggered:Connect(function() self.gui.Enabled = true; self:setTutorial(self.currentSnapshot) end)
end

function WorkbenchController:render(snapshot: any)
	self.plotId = snapshot.plotId
	self.currentSnapshot = snapshot
	self:renderCards()
	local workshopUnlocked = snapshot.crafted and snapshot.crafted.WorkshopLevel2 == true
	self.workshopCategory.Text = if workshopUnlocked then "WORKSHOP II" else "WORKSHOP II  LOCKED"
	self.workshopCategory.Active = workshopUnlocked
	if not workshopUnlocked and self.activeCategory == "WORKSHOP_2" then self.activeCategory = "STARTER" end
	self:setCategory(self.activeCategory)
	self:renderSelected()
	self.inventory:render(snapshot)
	self:setTutorial(snapshot)
end

function WorkbenchController:destroy()
	self.running = false
	if self.inputConnection then self.inputConnection:Disconnect() end
	if self.viewportConnection then self.viewportConnection:Disconnect() end
	if self.promptConnection then self.promptConnection:Disconnect() end
	if self.prompt then self.prompt:Destroy() end
	if self.overlay then self.overlay:destroy() end
	self.gui:Destroy()
end

return WorkbenchController
