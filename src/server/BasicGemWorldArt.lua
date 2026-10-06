--!strict
-- Decorative crystal shell. The existing invisible root still owns pickup identity and range.
local GemArt = {}

function GemArt.decorate(root: BasePart): Model
	local previous = root:FindFirstChild("GemVisual")
	if previous then previous:Destroy() end
	root.Transparency = 1
	local model = Instance.new("Model")
	model.Name = "GemVisual"
	local function piece(className: string, name: string, size: Vector3, offset: CFrame, color: Color3, transparency: number, material: Enum.Material): BasePart
		local part = Instance.new(className) :: BasePart
		part.Name = name; part.Size = size; part.CFrame = root.CFrame * offset
		part.Color = color; part.Transparency = transparency; part.Material = material
		part.Anchored = false; part.Massless = true
		part.CanCollide = false; part.CanTouch = false; part.CanQuery = false
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root; weld.Part1 = part; weld.Parent = part
		return part
	end
	piece("Part", "CrystalCore", Vector3.new(0.75, 1.2, 0.75), CFrame.new(), Color3.fromRGB(66, 219, 242), 0, Enum.Material.Neon)
	-- Opposing wedges form a pointed crystal, with opaque-enough blue faces outlining the core.
	for index = 0, 3 do
		local angle = index * math.pi / 2
		piece("WedgePart", "Facet" .. index, Vector3.new(1.55, 1.7, 1.15), CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.12, -0.35), if index % 2 == 0 then Color3.fromRGB(21, 112, 175) else Color3.fromRGB(31, 166, 201), 0.18, Enum.Material.SmoothPlastic)
	end
	piece("WedgePart", "LowerFacet", Vector3.new(1.65, 1.1, 1.65), CFrame.new(0, -0.95, 0) * CFrame.Angles(0, 0, math.pi), Color3.fromRGB(20, 90, 151), 0.12, Enum.Material.SmoothPlastic)
	local light = Instance.new("PointLight")
	light.Name = "GemGlow"; light.Color = Color3.fromRGB(100, 238, 255); light.Brightness = 0.65; light.Range = 8; light.Parent = model.CrystalCore
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "GemSparkles"; sparkles.Rate = 3; sparkles.LightEmission = 0.3
	sparkles.Lifetime = NumberRange.new(0.65, 1.1); sparkles.Speed = NumberRange.new(0.2, 0.5)
	sparkles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0)})
	sparkles.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1)})
	sparkles.Color = ColorSequence.new(Color3.fromRGB(127, 227, 245)); sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"; sparkles.Parent = model.CrystalCore
	model.Parent = root
	return model
end

return table.freeze(GemArt)
