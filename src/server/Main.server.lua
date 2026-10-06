--!strict
-- Server bootstrap keeps service startup in one fixed place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameInfo = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameInfo"))
local HoardService = require(script.Parent:WaitForChild("HoardService"))

print(string.format("[Hoard] server up: %s (%s)", GameInfo.NAME, GameInfo.STAGE))

HoardService.start()
