-- Apply source-built courtyard in Edit mode, as one undoable geometry change.
assert(not game:GetService("RunService"):IsRunning(), "Edit mode only")
local history = game:GetService("ChangeHistoryService")
local ownsRecording = not history:IsRecordingInProgress()
local recording = if ownsRecording then assert(history:TryBeginRecording("Sandy courtyard"), "Undo recording unavailable") else nil
local ok, result = xpcall(function()
	local mod = game:GetService("ServerScriptService").Server.CourtyardWorld
	local fn = assert(loadstring(mod.Source, "=CourtyardWorld"))
	local base = getfenv(1)
	local cache = {}
 local function fresh(module)
  if cache[module] then return cache[module] end
  local chunk = assert(loadstring(module.Source, "=" .. module.Name))
  setfenv(chunk, setmetatable({script=module, require=fresh}, {__index=base}))
  local value=chunk(); cache[module]=value; return value
 end
 setfenv(fn, setmetatable({script = mod, require=fresh}, {__index = base}))
	return fn().render(workspace)
end, debug.traceback)
if ownsRecording and recording then history:FinishRecording(recording, if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel) end
assert(ok, result)
return tostring(result) .. " courtyard details built; save the place with Ctrl+S"
