--!strict
-- Routes authoritative Stage 2 private/public snapshots to presentation and intent controllers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Stage1Config"))
local GameInfo = require(Shared:WaitForChild("GameInfo"))
local Layout = require(Shared:WaitForChild("PresentationLayout"))
local CarryRenderer = require(script.Parent:WaitForChild("CarryRenderer"))
local CollectionBinController = require(script.Parent:WaitForChild("CollectionBinController"))
local DepositEffects = require(script.Parent:WaitForChild("DepositEffects"))
local HudController = require(script.Parent:WaitForChild("HudController"))
local GemAnnouncementController = require(script.Parent:WaitForChild("GemAnnouncementController"))
local OverflowController = require(script.Parent:WaitForChild("OverflowController"))
local PickupController = require(script.Parent:WaitForChild("PickupController"))
local PileRenderer = require(script.Parent:WaitForChild("PileRenderer"))
local TutorialController = require(script.Parent:WaitForChild("TutorialController"))
local TrackerController = require(script.Parent:WaitForChild("TrackerController"))
local StationController = require(script.Parent:WaitForChild("StationController"))
local WorkbenchController = require(script.Parent:WaitForChild("WorkbenchController"))

print(string.format("[Hoard] client up: %s (%s)", GameInfo.NAME, GameInfo.STAGE))
local remotes = ReplicatedStorage:WaitForChild("HoardRemotes")
local actionRemote = remotes:WaitForChild("Action") :: RemoteEvent
local stateRemote = remotes:WaitForChild("State") :: RemoteEvent
local publicStateRemote = remotes:WaitForChild("PublicState") :: RemoteEvent
local player = Players.LocalPlayer
local hud = HudController.new()
local gemAnnouncement = GemAnnouncementController.new()
local carry = CarryRenderer.new()
local collectionBin = CollectionBinController.new(actionRemote)
local pile = PileRenderer.new()
local depositEffects = DepositEffects.new()
local pickup = PickupController.new(actionRemote)
local workbench = WorkbenchController.new(actionRemote)
local overflow = OverflowController.new(actionRemote)
local tracker = TrackerController.new(actionRemote)
local stations = StationController.new(actionRemote, function() collectionBin:open() end)
local tutorial = TutorialController.new(workbench)
local currentSession: number? = nil
local currentRevision: number? = nil
local received = false

local function setCharacter(character: Model?)
	carry:setCharacter(character)
	tutorial:setCharacter(character)
	if character then actionRemote:FireServer("READY") end
end
setCharacter(player.Character)
player.CharacterAdded:Connect(setCharacter)
player.CharacterRemoving:Connect(function() carry:setCharacter(nil); tutorial:setCharacter(nil) end)

stateRemote.OnClientEvent:Connect(function(snapshot: any)
	if type(snapshot) ~= "table" or type(snapshot.sessionId) ~= "number" or type(snapshot.revision) ~= "number" then return end
	if not Layout.shouldApplySnapshot(currentSession, currentRevision, snapshot.sessionId, snapshot.revision) then return end
	currentSession = snapshot.sessionId; currentRevision = snapshot.revision; received = true
	pickup:setEnabled(snapshot.status == "OWNER")
	hud:render(snapshot, snapshot.status, snapshot.feedback)
	carry:render(snapshot)
	depositEffects:render(snapshot)
	workbench:render(snapshot)
	overflow:render(snapshot)
	collectionBin:render(snapshot)
	tracker:render(snapshot)
	stations:render(snapshot)
	tutorial:render(snapshot)
end)

publicStateRemote.OnClientEvent:Connect(function(packet: any) pile:renderPublic(packet) end)

task.spawn(function() while not received do actionRemote:FireServer("READY"); task.wait(Config.readyInterval) end end)
