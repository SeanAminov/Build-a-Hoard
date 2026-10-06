--!strict
-- Plays the owner's deposit marker pulse once per newer authoritative deposit token.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Stage2Config"))

local DepositEffects = {}; DepositEffects.__index = DepositEffects

function DepositEffects.new(): any return setmetatable({ lastToken = 0 }, DepositEffects) end

function DepositEffects:render(snapshot: any)
	local token = snapshot.depositToken
	if type(token) ~= "number" or token <= self.lastToken then return end
	self.lastToken = token
	local hoard = Workspace:FindFirstChild("Hoard"); local plots = if hoard then hoard:FindFirstChild("Plots") else nil; local plot = if plots and snapshot.plotId then plots:FindFirstChild(string.format("Plot%d", snapshot.plotId)) else nil; local marker = if plot then plot:FindFirstChild("DepositMarker") else nil
	if marker == nil or not marker:IsA("BasePart") then return end
	marker.Color = Config.markerBaseColor
	local half = Config.markerPulseSeconds / 2
	local up = TweenService:Create(marker, TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Color = Config.markerPulseColor })
	local down = TweenService:Create(marker, TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Color = Config.markerBaseColor })
	up.Completed:Connect(function() if marker.Parent then down:Play() end end); up:Play()
end

return DepositEffects
