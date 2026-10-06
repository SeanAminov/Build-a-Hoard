--!strict
--[[
	All world-space steps of onboarding. Screen-space steps are owned by WorkbenchController.

	Presentation only. What is still wanted comes from `TutorialRules`, the same module the server
	uses to refuse a second spare, so the arrow can never point at something the server would then
	reject. Later steps, and remembering that the tutorial is finished, need server state and a save
	change.

	It retargets on a timer rather than on snapshots, because the nearest object changes while the
	player walks even though no state has changed at all. That is also what makes it recover the
	instant somebody else takes the object it was pointing at.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Stage1Config"))
local PointerTargets = require(Shared:WaitForChild("PointerTargets"))
local Resources = require(Shared:WaitForChild("ResourceDefinitions"))
local TutorialRules = require(Shared:WaitForChild("TutorialRules"))
local WorldPointer = require(script.Parent:WaitForChild("WorldPointer"))

local TutorialController = {}
TutorialController.__index = TutorialController

local COLLECT_COLOR = Color3.fromRGB(242, 111, 48)

function TutorialController.new(workbench: any): any
	local self = setmetatable({ pointer = WorldPointer.new(), snapshot = nil, running = true, workbench = workbench }, TutorialController)
	task.spawn(function()
		while self.running do
			self:refresh()
			task.wait(Config.targetRefreshInterval)
		end
	end)
	return self
end

function TutorialController:setCharacter(character: Model?)
	self.pointer:setCharacter(character)
end

function TutorialController:render(snapshot: any)
	self.snapshot = snapshot
	if self.workbench then self.workbench:setTutorial(snapshot) end
	self:refresh()
end

function TutorialController:refresh()
	local snapshot = self.snapshot
	if snapshot == nil or snapshot.status ~= "OWNER" then self.pointer:hide(); return end
	local step = snapshot.tutorialStep or 0
	if step >= TutorialRules.completeStep then self.pointer:hide(); return end
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then self.pointer:hide(); return end
	local hoard = Workspace:FindFirstChild("Hoard")
	local plots = if hoard then hoard:FindFirstChild("Plots") else nil
	local plot = if plots and snapshot.plotId then plots:FindFirstChild(string.format("Plot%d", snapshot.plotId)) else nil
	if step > 0 then
		if step >= 2 and self.workbench and self.workbench.gui.Enabled then self.pointer:hide(); return end
		local targetName = if step == 1 then "DepositZone" else "Workbench"
		local target = if plot then plot:FindFirstChild(targetName) else nil
		if target and target:IsA("BasePart") then
			local color = if step == 1 then Color3.fromRGB(104, 211, 67) else Color3.fromRGB(82, 194, 238)
			local title = if step == 1 then "YOUR HOARD" elseif step == 2 then "TIME TO SELL ONE" elseif step == 3 then "BUILD AFK SORTER" else "TRACK COLLECTION BIN"
			local instruction = if step == 1 then "TAKE ALL 5 HOME" else "OPEN THE WORKBENCH"
			self.pointer:pointTo(target, color, title, instruction)
		else self.pointer:hide() end
		return
	end
	local progress = TutorialRules.progress(Config.resourceOrder, snapshot.carry, snapshot.hoardCounts, snapshot.crafted)
	local resources = if hoard then hoard:FindFirstChild("Resources") else nil
	if resources == nil then self.pointer:hide(); return end

	local candidates: { PointerTargets.Candidate } = {}
	local partsById: { [string]: BasePart } = {}
	for _, child in ipairs(resources:GetChildren()) do
		if child:IsA("BasePart") and type(child:GetAttribute("ItemId")) == "string" then
			local resourceId = tostring(child:GetAttribute("ResourceId") or "")
			if progress.wanted[resourceId] then
				local id = tostring(child:GetAttribute("LitterId") or child.Name)
				table.insert(candidates, { id = id, resourceId = resourceId, position = child.Position })
				partsById[id] = child
			end
		end
	end
	local best = PointerTargets.nearest(candidates, progress.wanted, root.Position)
	local part = if best then partsById[best.id] else nil
	if best == nil or part == nil then self.pointer:hide(); return end
	local definition = Resources.get(best.resourceId)
	local displayName = if definition then string.upper(definition.displayName) else "RESOURCE"
	local instruction = if progress.missingTypes == 0
		then "ONE MORE FOR GOOD MEASURE"
		else string.format("COLLECT 5 THINGS  •  %d TO GO", progress.remaining)
	self.pointer:pointTo(part, COLLECT_COLOR, displayName, instruction)
end

function TutorialController:destroy()
	self.running = false
	self.pointer:destroy()
end

return TutorialController
