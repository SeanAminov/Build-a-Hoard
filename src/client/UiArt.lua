--!strict
-- Generated cartoon sprites with temporary fallback until Roblox asset IDs are installed.

local UiArt = {}
local Assets: { [string]: string } = require(script.Parent:WaitForChild("UiImageAssets"))

local function sprite(parent: Instance, id: string): Frame?
	local asset = Assets[id]
	if asset == nil or asset == "" then return nil end
	local root = Instance.new("Frame")
	root.Name = id .. "Art"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = parent
	local image = Instance.new("ImageLabel")
	image.Name = "CartoonIcon"
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromScale(0.94, 0.94)
	image.BackgroundTransparency = 1
	image.Image = asset
	image.ScaleType = Enum.ScaleType.Fit
	image.Parent = root
	return root
end

local INK = Color3.fromRGB(22, 56, 91)
local WOOD = Color3.fromRGB(165, 88, 43)
local WOOD_LIGHT = Color3.fromRGB(225, 139, 62)
local METAL = Color3.fromRGB(123, 151, 171)
local METAL_DARK = Color3.fromRGB(65, 87, 108)
local STONE = Color3.fromRGB(130, 139, 151)
local STONE_LIGHT = Color3.fromRGB(190, 198, 205)
local GREEN = Color3.fromRGB(105, 205, 68)
local GREEN_DARK = Color3.fromRGB(48, 134, 61)
local CAN = Color3.fromRGB(235, 91, 51)
local GOLD = Color3.fromRGB(255, 190, 35)

local function corner(object: GuiObject, radius: UDim)
	local value = Instance.new("UICorner")
	value.CornerRadius = radius
	value.Parent = object
end

local function stroke(object: GuiObject, thickness: number, color: Color3?)
	local value = Instance.new("UIStroke")
	value.Thickness = thickness
	value.Color = color or INK
	value.Parent = object
end

local function piece(
	parent: Instance,
	name: string,
	color: Color3,
	position: UDim2,
	size: UDim2,
	rotation: number?,
	radius: UDim?,
	zIndex: number?
): Frame
	local result = Instance.new("Frame")
	result.Name = name
	result.AnchorPoint = Vector2.new(0.5, 0.5)
	result.Position = position
	result.Size = size
	result.Rotation = rotation or 0
	result.BackgroundColor3 = color
	result.BorderSizePixel = 0
	result.ZIndex = zIndex or 2
	result.Parent = parent
	corner(result, radius or UDim.new(0.22, 0))
	stroke(result, 2)
	return result
end

local function canvas(parent: Instance, name: string): Frame
	local result = Instance.new("Frame")
	result.Name = name
	result.Size = UDim2.fromScale(1, 1)
	result.BackgroundTransparency = 1
	result.BorderSizePixel = 0
	result.ClipsDescendants = false
	result.Parent = parent
	return result
end

local function wood(parent: Instance)
	for index, row in ipairs({
		{ 0.47, 0.52, 0.62, 0.17, -28 },
		{ 0.53, 0.51, 0.62, 0.17, 26 },
		{ 0.50, 0.57, 0.66, 0.18, 0 },
	}) do
		local log = piece(parent, "Log" .. index, if index == 3 then WOOD_LIGHT else WOOD, UDim2.fromScale(row[1], row[2]), UDim2.fromScale(row[3], row[4]), row[5], UDim.new(0.5, 0), 3 + index)
		local grain = Instance.new("Frame")
		grain.Name = "Grain"
		grain.AnchorPoint = Vector2.new(1, 0.5)
		grain.Position = UDim2.fromScale(0.98, 0.5)
		grain.Size = UDim2.fromScale(0.13, 0.72)
		grain.BackgroundColor3 = Color3.fromRGB(244, 174, 84)
		grain.BorderSizePixel = 0
		grain.ZIndex = log.ZIndex + 1
		grain.Parent = log
		corner(grain, UDim.new(1, 0))
	end
end

local function stone(parent: Instance)
	local back = piece(parent, "BackStone", STONE, UDim2.fromScale(0.37, 0.54), UDim2.fromScale(0.42, 0.42), -14, UDim.new(0.42, 0), 2)
	back.AnchorPoint = Vector2.new(0.5, 0.5)
	piece(parent, "RightStone", STONE_LIGHT, UDim2.fromScale(0.66, 0.58), UDim2.fromScale(0.38, 0.34), 12, UDim.new(0.45, 0), 3)
	piece(parent, "FrontStone", Color3.fromRGB(157, 166, 177), UDim2.fromScale(0.50, 0.69), UDim2.fromScale(0.50, 0.30), -4, UDim.new(0.48, 0), 4)
end

local function scrap(parent: Instance)
	piece(parent, "PlateA", METAL, UDim2.fromScale(0.39, 0.55), UDim2.fromScale(0.52, 0.20), -32, UDim.new(0.18, 0), 2)
	piece(parent, "PlateB", Color3.fromRGB(184, 202, 214), UDim2.fromScale(0.59, 0.53), UDim2.fromScale(0.50, 0.20), 28, UDim.new(0.18, 0), 3)
	local gear = piece(parent, "Gear", METAL_DARK, UDim2.fromScale(0.53, 0.58), UDim2.fromScale(0.29, 0.29), 0, UDim.new(1, 0), 5)
	local hole = piece(gear, "Hole", Color3.fromRGB(225, 235, 240), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.38, 0.38), 0, UDim.new(1, 0), 6)
	hole.Parent = gear
end

local function oldCan(parent: Instance)
	local body = piece(parent, "CanBody", CAN, UDim2.fromScale(0.50, 0.55), UDim2.fromScale(0.42, 0.62), -10, UDim.new(0.18, 0), 3)
	piece(body, "TopRim", METAL_DARK, UDim2.fromScale(0.5, 0.04), UDim2.fromScale(1.05, 0.13), 0, UDim.new(1, 0), 5)
	piece(body, "BottomRim", METAL_DARK, UDim2.fromScale(0.5, 0.96), UDim2.fromScale(1.05, 0.13), 0, UDim.new(1, 0), 5)
	local band = piece(body, "LabelBand", Color3.fromRGB(255, 226, 171), UDim2.fromScale(0.5, 0.53), UDim2.fromScale(1.02, 0.30), 0, UDim.new(0.15, 0), 5)
	band.Parent = body
end

local function crate(parent: Instance)
	local body = piece(parent, "CrateBody", WOOD_LIGHT, UDim2.fromScale(0.5, 0.57), UDim2.fromScale(0.72, 0.56), 0, UDim.new(0.12, 0), 2)
	piece(body, "TopBrace", WOOD, UDim2.fromScale(0.5, 0.16), UDim2.fromScale(1.02, 0.14), 0, UDim.new(0.08, 0), 4)
	piece(body, "BottomBrace", WOOD, UDim2.fromScale(0.5, 0.84), UDim2.fromScale(1.02, 0.14), 0, UDim.new(0.08, 0), 4)
	piece(body, "SlashA", WOOD, UDim2.fromScale(0.50, 0.50), UDim2.fromScale(0.72, 0.10), 34, UDim.new(0.4, 0), 5)
	piece(body, "SlashB", WOOD, UDim2.fromScale(0.50, 0.50), UDim2.fromScale(0.72, 0.10), -34, UDim.new(0.4, 0), 5)
end

local function carryRack(parent: Instance)
	local pack = piece(parent, "Pack", Color3.fromRGB(126, 76, 47), UDim2.fromScale(0.5, 0.61), UDim2.fromScale(0.48, 0.43), 0, UDim.new(0.22, 0), 3)
	piece(pack, "Pocket", WOOD_LIGHT, UDim2.fromScale(0.5, 0.67), UDim2.fromScale(0.65, 0.35), 0, UDim.new(0.22, 0), 5)
	for index, x in ipairs({ 0.28, 0.72 }) do
		piece(parent, "Rail" .. index, METAL_DARK, UDim2.fromScale(x, 0.52), UDim2.fromScale(0.10, 0.74), 0, UDim.new(0.4, 0), 5)
	end
	piece(parent, "Crossbar", WOOD_LIGHT, UDim2.fromScale(0.5, 0.28), UDim2.fromScale(0.58, 0.12), 0, UDim.new(0.3, 0), 6)
end

local function boots(parent: Instance)
	for index, data in ipairs({ { 0.38, -9 }, { 0.62, 9 } }) do
		local boot = piece(parent, "Boot" .. index, Color3.fromRGB(116, 73, 47), UDim2.fromScale(data[1], 0.56), UDim2.fromScale(0.27, 0.55), data[2], UDim.new(0.28, 0), 3 + index)
		piece(boot, "Sole", INK, UDim2.fromScale(0.58, 0.93), UDim2.fromScale(1.10, 0.14), 0, UDim.new(0.4, 0), 6)
		for laceIndex = 1, 3 do
			piece(boot, "Lace" .. laceIndex, Color3.fromRGB(244, 149, 51), UDim2.fromScale(0.5, 0.23 + laceIndex * 0.14), UDim2.fromScale(0.62, 0.05), 0, UDim.new(1, 0), 6)
		end
	end
end

local function plot(parent: Instance)
	local ground = piece(parent, "Ground", GREEN, UDim2.fromScale(0.5, 0.58), UDim2.fromScale(0.72, 0.56), 0, UDim.new(0.12, 0), 2)
	local inner = piece(ground, "Inner", Color3.fromRGB(150, 232, 76), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.72, 0.64), 0, UDim.new(0.12, 0), 3)
	stroke(inner, 2, Color3.new(1, 1, 1))
	for index, point in ipairs({ { 0.15, 0.18 }, { 0.85, 0.18 }, { 0.15, 0.82 }, { 0.85, 0.82 } }) do
		piece(ground, "Post" .. index, WOOD, UDim2.fromScale(point[1], point[2]), UDim2.fromScale(0.10, 0.28), 0, UDim.new(0.3, 0), 5)
	end
end

function UiArt.resource(parent: Instance, resourceId: string): Frame
	local artwork = sprite(parent, resourceId)
	if artwork then return artwork end
	local result = canvas(parent, resourceId .. "Art")
	if resourceId == "Wood" then wood(result)
	elseif resourceId == "Stone" then stone(result)
	elseif resourceId == "ScrapMetal" then scrap(result)
	elseif resourceId == "OldCan" then oldCan(result)
	else error("unknown resource art") end
	return result
end

function UiArt.recipe(parent: Instance, recipeId: string): Frame
	local artwork = sprite(parent, recipeId)
	if artwork then return artwork end
	local result = canvas(parent, recipeId .. "Art")
	if recipeId == "AFKSorter" then crate(result)
	elseif recipeId == "CollectionBin" then crate(result)
	elseif recipeId == "ScavengerSatchel" then carryRack(result)
	elseif recipeId == "CarryRack" then carryRack(result)
	elseif recipeId == "TrailBoots" then boots(result)
	elseif recipeId == "HoardCrate" then crate(result)
	elseif recipeId == "BiggerPlot" then plot(result)
	elseif recipeId == "WorkshopLevel2" then crate(result)
	elseif recipeId == "ReinforcedCarryRack" then carryRack(result)
	elseif recipeId == "TrailBoots2" then boots(result)
	elseif recipeId == "StorageShelves" then crate(result)
	else error("unknown recipe art") end
	return result
end

function UiArt.coin(parent: Instance): Frame
	local result = canvas(parent, "CoinArt")
	local disc = piece(result, "Coin", GOLD, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.74, 0.74), 0, UDim.new(1, 0), 3)
	stroke(disc, 3, Color3.fromRGB(167, 101, 16))
	local text = Instance.new("TextLabel")
	text.Name = "Dollar"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "$"
	text.Font = Enum.Font.FredokaOne
	text.TextColor3 = Color3.fromRGB(255, 243, 153)
	text.TextScaled = true
	text.ZIndex = 5
	text.Parent = disc
	return result
end

return table.freeze(UiArt)
