--!strict
-- Compact top-right bubbles keep Coins, passive income, carry and hoard readable during play.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Stage1Config"))
local UiPresentation = require(Shared:WaitForChild("UiPresentation"))
local UiArt = require(script.Parent:WaitForChild("UiArt"))

local HudController = {}
HudController.__index = HudController

local INK = Color3.fromRGB(22, 56, 91)

-- PROTOTYPE PRESENTATION: clean rounded panels replace baked-in screws and asymmetric tabs.
local function panel(frame: Frame, color: Color3)
	frame.BackgroundTransparency = 0
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = frame
	local border = Instance.new("UIStroke")
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Color = INK
	border.Thickness = 3
	border.Parent = frame
	local rail = Instance.new("Frame")
	rail.Name = "InnerRail"; rail.Position = UDim2.fromOffset(4, 4); rail.Size = UDim2.new(1, -8, 1, -8)
	rail.BackgroundTransparency = 1; rail.BorderSizePixel = 0; rail.Parent = frame
	local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 14); rc.Parent = rail
	local rs = Instance.new("UIStroke"); rs.Color = Color3.fromRGB(64, 183, 225); rs.Thickness = 2; rs.Parent = rail
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(224, 237, 245))
	shade.Parent = frame
end

local function text(parent: Instance, name: string, position: UDim2, size: UDim2, textSize: number, color: Color3?): TextLabel
	local result = Instance.new("TextLabel")
	result.Name = name
	result.BackgroundTransparency = 1
	result.Position = position
	result.Size = size
	result.Font = Enum.Font.FredokaOne
	result.TextColor3 = color or INK
	result.TextSize = textSize
	result.TextXAlignment = Enum.TextXAlignment.Center
	result.Text = ""
	result.Parent = parent
	return result
end

local function chip(parent: Instance, name: string, recipeId: string, position: UDim2): TextLabel
	local frame = Instance.new("Frame")
	frame.Name = name .. "Chip"
	frame.Size = UDim2.fromOffset(156, 60)
	frame.Position = position
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	panel(frame, Color3.fromRGB(228, 248, 255))
	local art = Instance.new("Frame")
	art.Name = name .. "Icon"
	art.Position = UDim2.fromOffset(9, 7)
	art.Size = UDim2.fromOffset(46, 46)
	art.BackgroundTransparency = 1
	art.Parent = frame
	UiArt.recipe(art, recipeId)
	local label = text(frame, name .. "Label", UDim2.fromOffset(59, 10), UDim2.fromOffset(88, 40), 14)
	label.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 10
	limit.MaxTextSize = 14
	limit.Parent = label
	return label
end

function HudController.new(): any
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("HoardHud")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "HoardHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.Parent = playerGui
	local chrome = Instance.new("Frame")
	chrome.Name = "HudChrome"
	chrome.AnchorPoint = Vector2.new(1, 0)
	chrome.Position = UDim2.new(1, -10, 0, 6)
	chrome.Size = UDim2.fromOffset(320, 156)
	chrome.BackgroundTransparency = 1
	chrome.BorderSizePixel = 0
	chrome.Parent = gui
	local moneyFrame = Instance.new("Frame")
	moneyFrame.Name = "MoneyChip"
	moneyFrame.Position = UDim2.fromOffset(0, 0)
	moneyFrame.Size = UDim2.fromOffset(320, 88)
	moneyFrame.BackgroundTransparency = 1
	moneyFrame.Parent = chrome
	panel(moneyFrame, Color3.fromRGB(255, 245, 210))
	local accent = Instance.new("Frame")
	accent.Name = "OrangeAccent"; accent.Position = UDim2.fromOffset(-3, 29); accent.Size = UDim2.fromOffset(6, 30)
	accent.BackgroundColor3 = Color3.fromRGB(248, 166, 50); accent.BorderSizePixel = 0; accent.Parent = moneyFrame
	local ac = Instance.new("UICorner"); ac.CornerRadius = UDim.new(0, 3); ac.Parent = accent
	local coin = Instance.new("Frame")
	coin.Name = "CoinIcon"
	coin.Position = UDim2.fromOffset(14, 14)
	coin.Size = UDim2.fromOffset(60, 60)
	coin.BackgroundTransparency = 1
	coin.Parent = moneyFrame
	UiArt.coin(coin)
	local money = text(moneyFrame, "MoneyLabel", UDim2.fromOffset(82, 12), UDim2.fromOffset(224, 34), 24)
	local income = text(moneyFrame, "PassiveIncomeLabel", UDim2.fromOffset(82, 49), UDim2.fromOffset(224, 25), 16, Color3.fromRGB(31, 144, 65))
	for _, entry in ipairs({{money,24},{income,16}}) do
		entry[1].TextScaled = true
		local cap = Instance.new("UITextSizeConstraint"); cap.MinTextSize = 11; cap.MaxTextSize = entry[2]; cap.Parent = entry[1]
	end
	local status = Instance.new("Frame")
	status.Name = "StatusPanel"
	status.Position = UDim2.fromOffset(0, 96)
	status.Size = UDim2.fromOffset(320, 60)
	status.BackgroundTransparency = 1
	status.Parent = chrome
	local carry = chip(status, "Carry", "ScavengerSatchel", UDim2.fromOffset(0, 0))
	local hoard = chip(status, "Hoard", "HoardCrate", UDim2.fromOffset(164, 0))
	local feedback = Instance.new("TextLabel")
	feedback.Name = "FeedbackLabel"
	feedback.AnchorPoint = Vector2.new(0.5, 1)
	feedback.Position = UDim2.new(0.5, 0, 1, -30)
	feedback.Size = UDim2.fromOffset(276, 42)
	feedback.BackgroundTransparency = 1
	feedback.Font = Enum.Font.FredokaOne
	feedback.TextColor3 = Color3.new(1, 1, 1)
	feedback.TextStrokeColor3 = INK
	feedback.TextStrokeTransparency = 0
	feedback.TextSize = 17
	feedback.TextWrapped = true
	feedback.Text = ""
	feedback.Parent = gui
	local self = setmetatable({
		gui = gui, money = money, income = income, carry = carry, hoard = hoard,
		feedback = feedback, feedbackToken = 0,
	}, HudController)
	self:render({}, "WAITING", nil)
	return self
end

function HudController:render(snapshot: any, status: string, message: string?)
	local carryCount = if type(snapshot.carry) == "table" then #snapshot.carry else 0
	self.money.Text = string.format("COINS  $%.1f", snapshot.coins or 0)
	self.income.Text = UiPresentation.formatRate(snapshot.passivePerSecond or 0) .. " PASSIVE"
	self.carry.Text = string.format("Carry %d/%d", carryCount, snapshot.capacity or Config.startingCarryCapacity)
	self.hoard.Text = string.format("Hoard %d/%d", snapshot.hoardTotal or 0, snapshot.storageCapacity or Config.startingStorageCapacity)
	local transparency = if status == "OWNER" then 0 else 0.45
	self.money.TextTransparency = transparency
	self.income.TextTransparency = transparency
	self.carry.TextTransparency = transparency
	self.hoard.TextTransparency = transparency
	if message and message ~= "" then
		self.feedbackToken += 1
		local token = self.feedbackToken
		self.feedback.Text = message
		task.delay(Config.feedbackLifetime, function()
			if self.feedbackToken == token then self.feedback.Text = "" end
		end)
	end
end

return HudController
