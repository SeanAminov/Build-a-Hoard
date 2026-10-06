--!strict
--[[
	GameInfo — the project's working title and current stage, written down in source.

	This remains metadata rather than gameplay. Stage 0 modules read it only to report which binding
	stage is running.
]]

local GameInfo = {}

-- Working title. The final name and theme are open questions.
GameInfo.NAME = "Build a Hoard"
GameInfo.STAGE = "STAGE_5"

function GameInfo.validate(): true
	assert(GameInfo.NAME ~= "", "the game needs a working title")
	assert(GameInfo.STAGE ~= "", "the current stage must be named")
	return true
end

GameInfo.validate()

return table.freeze(GameInfo)
