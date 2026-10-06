-- Edit-only: real constructors/renderers with a private fake Workspace in ServerStorage.
-- No live roots, characters, place geometry, remotes or input are touched.
local storage = game:GetService("ServerStorage")
assert(not storage:FindFirstChild("_ResourceVisualFixture"), "Existing resource fixture; abort")
local fixture = Instance.new("Folder")
fixture.Name = "_ResourceVisualFixture"
fixture.Parent = storage
local shared = game:GetService("ReplicatedStorage").Shared
local client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local base, cache = getfenv(1), {}
local fakeGame = { GetService = function(_, name)
	if name == "Workspace" then return fixture end
	return game:GetService(name)
end }
local function load(mod)
	if cache[mod] ~= nil then return cache[mod] end
	local fn = assert(loadstring(mod.Source, "=" .. mod.Name))
	setfenv(fn, setmetatable({ script = mod, game = fakeGame, require = load }, { __index = base }))
	local value = fn(); cache[mod] = value; return value
end
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end
local function folder(name, parent)
	local value = Instance.new("Folder"); value.Name = name; value.Parent = parent; return value
end
local function part(name, parent)
	local value = Instance.new("Part"); value.Name = name; value.Anchored = true; value.Parent = parent; return value
end
local pileRenderer
local ok, err = pcall(function()
	local art, resources = load(shared.ResourceVisuals), load(shared.ResourceDefinitions)
	check(art.validate(), "resource descriptors must validate")
	check(table.isfrozen(art.rows), "descriptor catalogue must be immutable")
	check(#art.rows.Stone.pieces==1,"stone should read as one rock instead of stacked pieces")
	check(art.rows.Stone.pieces[1].meshType==Enum.MeshType.Sphere and art.rows.Stone.pieces[1].material==Enum.Material.Slate,"stone should use one simple flattened slate pebble")
	local missing = table.clone(art.rows); missing.Wood = nil
	check(not pcall(art.validate, missing), "missing resource descriptor must be rejected")
	local crowded = table.clone(art.rows); crowded.Wood = { pieces = {} }
	for i = 1, 6 do crowded.Wood.pieces[i] = art.rows.Wood.pieces[1] end
	check(not pcall(art.validate, crowded), "more than five art pieces must be rejected")
	local function checkArt(root, resourceId)
		local model = root:FindFirstChild("ResourceVisual")
		check(model ~= nil and model:IsA("Model"), resourceId .. " visual model missing")
		check(#model:GetChildren() == #art.rows[resourceId].pieces, resourceId .. " piece count differs by context")
		for _, piece in ipairs(model:GetChildren()) do
			check(piece:IsA("BasePart") and not piece.CanCollide and not piece.CanTouch and not piece.CanQuery and piece.Massless and not piece.Anchored, "art cannot affect physics or targeting")
			local weld = piece:FindFirstChild("RootWeld")
			check(weld ~= nil and weld.Part0 == root and weld.Part1 == piece, "every decorative part must follow the root")
		end
		if resourceId == "Stone" then
			local mesh = model.Stone:FindFirstChildOfClass("SpecialMesh")
			check(mesh ~= nil and mesh.MeshType == Enum.MeshType.Sphere and mesh.Scale == art.rows.Stone.pieces[1].meshScale, "stone must build the approved single flattened pebble mesh")
		end
	end
	for resourceId, definition in pairs(resources.rows) do
		local root = part(resourceId, fixture)
		root.Size = definition.size; root.CFrame = CFrame.new(4, 8, 12) * CFrame.Angles(0, .7, 0)
		root:SetAttribute("LitterId", "FixtureLitter"); root:SetAttribute("ResourceId", resourceId)
		root:SetAttribute("ItemId", "FixtureLitter:1"); root:SetAttribute("Yaw", 40)
		local original = root.CFrame
		art.decorate(root, resourceId)
		check(root.Parent == fixture and root.Size == definition.size and root.CFrame == original and root.Anchored and root.CanCollide and root.CanQuery and root.CanTouch, "constructor changed authoritative root geometry/interaction")
		check(root:GetAttribute("LitterId") == "FixtureLitter" and root:GetAttribute("ResourceId") == resourceId and root:GetAttribute("ItemId") == "FixtureLitter:1" and root:GetAttribute("Yaw") == 40, "constructor changed identity attributes")
		check(root.Transparency == 1, "old placeholder root remains visible")
		checkArt(root, resourceId)
		local firstModel = root.ResourceVisual
		art.decorate(root, resourceId)
		check(firstModel.Parent == nil and #root:GetChildren() == 1, "redecorating accumulates models")
		for _, descriptor in ipairs(art.rows[resourceId].pieces) do
			local built = root.ResourceVisual:FindFirstChild(descriptor.name)
			check((original:ToObjectSpace(built.CFrame).Position - descriptor.offset.Position).Magnitude < .001 and built.Size == descriptor.size and built.Color == descriptor.color, "constructor lost descriptor transform or palette")
		end
	end
	local character = Instance.new("Model"); character.Name = "Character"; character.Parent = fixture
	local head = part("Head", character); head.Size = Vector3.new(2, 1, 1)
	local carry = load(client.CarryRenderer).new()
	carry:setCharacter(character)
	local ids = { "Wood", "Stone", "ScrapMetal", "OldCan" }
	local carried = {}
	for index, id in ipairs(ids) do carried[index] = { resourceId = id, itemId = "Carry:" .. index } end
	carry:render({ carry = carried })
	check(#character.CarryStack:GetChildren() == 4, "carry roots must remain one per carried item")
	for index, id in ipairs(ids) do
		local root = character.CarryStack:FindFirstChild("Slot" .. index)
		checkArt(root, id)
		check(root.HeadWeld.Part0 == head and root:GetAttribute("ItemId") == "Carry:" .. index, "carried root must stay attached to head and retain item identity")
	end
	carry:render({ carry = {} })
	check(#character.CarryStack:GetChildren() == 0, "empty carry must clear all decorative pieces")
	local hoard = folder("Hoard", fixture); folder("Visuals", hoard)
	local plots = folder("Plots", hoard); local plot = folder("Plot1", plots)
	local origin = part("PileOrigin", plot); origin.CFrame = CFrame.new(0, 2, 0)
	local ground = part("Ground", plot); ground.Size = Vector3.new(64, 1, 64)
	local config = load(shared.Stage1Config)
	local pileIds = {}
	for i = 1, config.visiblePileCap + 10 do pileIds[i] = ids[(i - 1) % #ids + 1] end
	pileRenderer = load(client.PileRenderer).new()
	pileRenderer:renderPublic({ worldRevision = 1, plots = { { plotId = 1, displayName = "Fixture", hoardTotal = #pileIds, storageCapacity = 200, pileResourceIds = pileIds } } })
	local pile = hoard.Visuals.Plot1.Pile
	check(#pile:GetChildren() == config.visiblePileCap, "composite pile must respect original visible-object cap")
	for index, id in ipairs(ids) do checkArt(pile:FindFirstChild(string.format("Item%03d", index)), id) end
	pileRenderer:renderPublic({ worldRevision = 2, plots = {} })
	check(not hoard.Visuals:FindFirstChild("Plot1") and next(pileRenderer.activeTweens) == nil, "plot release must remove art and cancel pending tweens")
end)
if pileRenderer then pileRenderer:destroy() end
fixture:Destroy()
assert(ok, err)
return string.format("%d resource visual checks passed; fixture removed", checks)
