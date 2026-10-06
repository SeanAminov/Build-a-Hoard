--!strict
-- Run in Studio Edit mode. Idempotently builds the four-plot Stage 1 greybox in one undo record.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Workspace = game:GetService("Workspace")

local function child(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then assert(existing.ClassName == className, string.format("%s is %s, expected %s", existing:GetFullName(), existing.ClassName, className)); return existing end
	local result = Instance.new(className); result.Name = name; result.Parent = parent; return result
end

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, visible: boolean, collidable: boolean): Part
	local result = child(parent, "Part", name) :: Part
	result.Anchored = true; result.Size = size; result.CFrame = cframe; result.Color = color; result.Material = Enum.Material.Plastic
	result.TopSurface = Enum.SurfaceType.Studs; result.BottomSurface = Enum.SurfaceType.Smooth
	result.Transparency = if visible then 0 else 1; result.CanCollide = collidable; result.CanTouch = false; result.CanQuery = visible
	return result
end

local plots = {
	{ id = 1, center = Vector3.new(0, 0, 110), yaw = 0 },
	{ id = 2, center = Vector3.new(120, 0, 0), yaw = 90 },
	{ id = 3, center = Vector3.new(0, 0, -110), yaw = 180 },
	{ id = 4, center = Vector3.new(-120, 0, 0), yaw = -90 },
}

local function build(): { [string]: number }
	local ownsRecording = not ChangeHistoryService:IsRecordingInProgress()
	local recording: string? = nil
	if ownsRecording then recording = ChangeHistoryService:TryBeginRecording("Build Stage 1 Four Plots"); assert(recording ~= nil, "could not begin undo recording") end
	local ok, result = xpcall(function()
		local hoard = child(Workspace, "Model", "Hoard")
		local field = child(hoard, "Model", "Field")
		part(field, "Ground", Vector3.new(132, 1, 108), CFrame.new(0, -0.5, 0), Color3.fromRGB(100, 185, 70), true, true)
		local oldNodes = field:FindFirstChild("Nodes"); if oldNodes then oldNodes:Destroy() end
		local bounds = part(field, "LitterBounds", Vector3.new(120, 0.2, 96), CFrame.new(0, 0.1, 0), Color3.new(1, 1, 1), false, false); bounds.CanQuery = false
		local oldPath = hoard:FindFirstChild("Path"); if oldPath then oldPath:Destroy() end
		local paths = child(hoard, "Folder", "Paths")
		local plotFolder = child(hoard, "Folder", "Plots")
		for _, definition in ipairs(plots) do
			local plotCFrame = CFrame.new(definition.center) * CFrame.Angles(0, math.rad(definition.yaw), 0)
			part(paths, string.format("Path%d", definition.id), Vector3.new(14, 1, 24), plotCFrame * CFrame.new(0, -0.5, -44), Color3.fromRGB(190, 165, 115), true, true)
			local plot = child(plotFolder, "Model", string.format("Plot%d", definition.id)) :: Model
			plot:SetAttribute("PlotId", definition.id); plot:SetAttribute("OwnerUserId", 0); plot:SetAttribute("ExpansionLevel", 0); plot:SetAttribute("StorageCapacity", 60)
			local ground = part(plot, "Ground", Vector3.new(64, 1, 64), plotCFrame * CFrame.new(0, -0.5, 0), Color3.fromRGB(180, 150, 105), true, true)
			ground:SetAttribute("BaseSize", 64); ground:SetAttribute("ExpandedSize", 64)
			local zone = part(plot, "DepositZone", Vector3.new(20, 6, 12), plotCFrame * CFrame.new(0, 3, -24), Color3.new(1, 1, 1), false, false); zone.CanQuery = false
			local marker = part(plot, "DepositMarker", Vector3.new(20, 0.1, 12), plotCFrame * CFrame.new(0, 0.05, -24), Color3.fromRGB(65, 205, 220), true, false)
			local billboard = child(marker, "BillboardGui", "Label") :: BillboardGui
			billboard.Size = UDim2.fromOffset(160, 40); billboard.StudsOffset = Vector3.new(0, 3, 0); billboard.MaxDistance = 60; billboard.AlwaysOnTop = true
			local title = child(billboard, "TextLabel", "Text") :: TextLabel
			title.Size = UDim2.fromScale(1, 1); title.BackgroundTransparency = 1; title.Font = Enum.Font.FredokaOne; title.Text = "DEPOSIT"; title.TextColor3 = Color3.new(1, 1, 1); title.TextSize = 22; title.TextStrokeColor3 = Color3.fromRGB(25, 45, 60); title.TextStrokeTransparency = 0
			local origin = part(plot, "PileOrigin", Vector3.new(0.2, 0.2, 0.2), plotCFrame * CFrame.new(0, 0, -6), Color3.new(1, 1, 1), false, false); origin.CanQuery = false
			local workbench = part(plot, "Workbench", Vector3.new(8, 3, 4), plotCFrame * CFrame.new(18, 1.5, -18), Color3.fromRGB(134, 76, 42), true, true); workbench:SetAttribute("PlotId", definition.id)
			local oldSpawn = plot:FindFirstChild("SpawnLocation")
			if oldSpawn and not oldSpawn:IsA("SpawnLocation") then oldSpawn:Destroy(); oldSpawn = nil end
			local spawn = (oldSpawn or Instance.new("SpawnLocation")) :: SpawnLocation
			spawn.Name = "SpawnLocation"; spawn.Size = Vector3.new(6, 1, 6); spawn.CFrame = plotCFrame * CFrame.new(-18, 0.5, -18); spawn.Anchored = true; spawn.Neutral = true; spawn.Duration = 0; spawn.Parent = plot
		end
		for _, existing in ipairs(plotFolder:GetChildren()) do local id = tonumber(string.match(existing.Name, "^Plot(%d+)$")); if id and id > 4 then existing:Destroy() end end
		for _, existing in ipairs(paths:GetChildren()) do local id = tonumber(string.match(existing.Name, "^Path(%d+)$")); if id and id > 4 then existing:Destroy() end end
		child(hoard, "Folder", "Resources")
		child(hoard, "Folder", "Visuals")
		local baseplate = Workspace:FindFirstChild("Baseplate")
		if baseplate and baseplate:IsA("BasePart") then baseplate.Size = Vector3.new(360, 1, 360); baseplate.Position = Vector3.new(0, -1.5, 0) end
		return { plots = 4, descendants = #hoard:GetDescendants() }
	end, debug.traceback)
	if ownsRecording and recording then ChangeHistoryService:FinishRecording(recording, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel) end
	if not ok then error(result) end
	return result
end

return build()
