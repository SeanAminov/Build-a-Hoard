--!strict
--[[
	Run in Studio Edit mode. Creates only the binding Stage 0 greybox hierarchy, inside one undo
	recording. Re-running updates the same named Instances instead of creating duplicates.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Workspace = game:GetService("Workspace")

local function child(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing ~= nil then
		assert(existing.ClassName == className, string.format("%s exists as %s, expected %s", existing:GetFullName(), existing.ClassName, className))
		return existing
	end
	local result = Instance.new(className)
	result.Name = name
	result.Parent = parent
	return result
end

local function part(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, visible: boolean, collidable: boolean): Part
	local result = child(parent, "Part", name) :: Part
	result.Anchored = true
	result.Size = size
	result.Position = position
	result.Color = color
	result.Material = Enum.Material.Plastic
	result.TopSurface = Enum.SurfaceType.Studs
	result.BottomSurface = Enum.SurfaceType.Smooth
	result.Transparency = if visible then 0 else 1
	result.CanCollide = collidable
	result.CanTouch = false
	result.CanQuery = visible
	return result
end

local function build(): { [string]: number }
	-- Studio bridge commands already run inside their own undo recording. Direct command-bar use
	-- needs a recording of its own; never try to nest one because Studio rejects nested records.
	local ownsRecording = not ChangeHistoryService:IsRecordingInProgress()
	local recording: string? = nil
	if ownsRecording then
		recording = ChangeHistoryService:TryBeginRecording("Build Stage 0 Greybox")
		assert(recording ~= nil, "could not start an undo recording")
	end
	local ok, result = xpcall(function()
		local hoard = child(Workspace, "Model", "Hoard")
		local field = child(hoard, "Model", "Field")
		part(field, "Ground", Vector3.new(132, 1, 108), Vector3.new(0, -0.5, 0), Color3.fromRGB(100, 185, 70), true, true)
		local obsoleteNodes = field:FindFirstChild("Nodes")
		if obsoleteNodes ~= nil then
			assert(obsoleteNodes:IsA("Folder"), "Workspace.Hoard.Field.Nodes has an unexpected class")
			obsoleteNodes:Destroy()
		end
		local litterBounds = part(field, "LitterBounds", Vector3.new(120, 0.2, 96), Vector3.new(0, 0.1, 0), Color3.new(1, 1, 1), false, false)
		litterBounds.CanQuery = false

		part(hoard, "Path", Vector3.new(20, 1, 24), Vector3.new(0, -0.5, 66), Color3.fromRGB(190, 165, 115), true, true)
		local plots = child(hoard, "Folder", "Plots")
		local plot = child(plots, "Model", "Plot1") :: Model
		plot:SetAttribute("OwnerUserId", 0)
		part(plot, "Ground", Vector3.new(64, 1, 64), Vector3.new(0, -0.5, 110), Color3.fromRGB(180, 150, 105), true, true)
		local zone = part(plot, "DepositZone", Vector3.new(20, 6, 12), Vector3.new(0, 3, 86), Color3.new(1, 1, 1), false, false)
		zone.CanQuery = false
		local marker = part(plot, "DepositMarker", Vector3.new(20, 0.1, 12), Vector3.new(0, 0.05, 86), Color3.fromRGB(65, 205, 220), true, false)
		marker.CanQuery = true
		local billboard = child(marker, "BillboardGui", "Label") :: BillboardGui
		billboard.Size = UDim2.fromOffset(160, 40)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		billboard.MaxDistance = 60
		billboard.AlwaysOnTop = true
		local text = child(billboard, "TextLabel", "Text") :: TextLabel
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.Text = "DEPOSIT"
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextSize = 22
		text.TextStrokeColor3 = Color3.fromRGB(25, 45, 60)
		text.TextStrokeTransparency = 0
		part(plot, "PileOrigin", Vector3.new(0.2, 0.2, 0.2), Vector3.new(0, 0, 104), Color3.new(1, 1, 1), false, false).CanQuery = false

		local spawn = plot:FindFirstChild("SpawnLocation")
		if spawn == nil then spawn = Workspace:FindFirstChild("SpawnLocation") end
		if spawn == nil then spawn = Instance.new("SpawnLocation") end
		assert(spawn:IsA("SpawnLocation"), "SpawnLocation has an unexpected class")
		spawn.Name = "SpawnLocation"
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.CFrame = CFrame.lookAt(Vector3.new(-18, 0.5, 92), Vector3.new(-18, 0.5, 91))
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Parent = plot

		child(hoard, "Folder", "Resources")
		child(hoard, "Folder", "Visuals")
		local baseplate = Workspace:FindFirstChild("Baseplate")
		if baseplate ~= nil then
			assert(baseplate:IsA("BasePart"), "Workspace.Baseplate must be a BasePart")
			baseplate.Position = Vector3.new(baseplate.Position.X, -1 - baseplate.Size.Y / 2, baseplate.Position.Z)
		end
		return { litterCount = 72, descendants = #hoard:GetDescendants() }
	end, debug.traceback)
	if ownsRecording and recording ~= nil then
		ChangeHistoryService:FinishRecording(recording, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
	end
	if not ok then error(result) end
	return result
end

return build()
