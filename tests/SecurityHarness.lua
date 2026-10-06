-- Real rules and adapter with inert storage. No live DataStore calls.
local base=getfenv(1);local cache={}
local function load(mod)
	if cache[mod] then return cache[mod] end
	local fn=assert(loadstring(mod.Source,"="..mod.Name))
	setfenv(fn,setmetatable({script=mod,require=load},{__index=base}))
	local value=fn();cache[mod]=value;return value
end
local count=0
local function check(ok,message) assert(ok,message);count+=1 end
local limiter=load(game.ServerScriptService.Server.ActionLimiter)
local buckets={}
for i=1,20 do check(limiter.allow(buckets,"a",0),"normal initial burst allowed") end
check(not limiter.allow(buckets,"a",0),"excess burst rejected")
check(limiter.allow(buckets,"b",0),"budgets isolated per player")
check(limiter.allow(buckets,"a",.1) and not limiter.allow(buckets,"a",.1),"only elapsed server time refills budget")
local rules=load(game.ReplicatedStorage.Shared.ProgressionRules)
for _,value in ipairs({0/0,math.huge,-math.huge}) do
	local world=rules.newWorld(123,0);rules.spawnBasicGemDue(world,300)
	local state=rules.newPlayerState()
	local request={itemId=rules.currentBasicGemId(world),rootPosition=Vector3.new(value,3,0),now=301,alive=true,isOwner=true}
	local accepted,reason=rules.claimBasicGem(world,state,request)
	check(not accepted and reason=="MALFORMED_POSITION" and state.specialItems.BasicGem==0,"nonfinite gem distance cannot bypass range")
	request.itemId=rules.currentItemId(world,world.litterOrder[1])
	accepted,reason=rules.pickUp(world,state,request)
	check(not accepted and reason=="MALFORMED_POSITION" and #state.carry==0,"nonfinite normal pickup cannot bypass range")
end
local writes,current,offline=0,nil,true
local backing={UpdateAsync=function(_,_,fn)
 if offline then error("offline") end
 local updated=fn(current)
 if updated~=nil then current=updated;writes+=1 end
 return updated
end}
local fakeGame={PlaceId=1,JobId="server-a",GetService=function(_,name)
 if name=="DataStoreService" then return {GetDataStore=function()return backing end} end
 if name=="RunService" then return {IsStudio=function()return false end} end
 return game:GetService(name)
end}
local mod=game.ServerScriptService.Server.DataStoreAdapter
local fn=assert(loadstring(mod.Source,"=DataStoreAdapter"))
setfenv(fn,setmetatable({script=mod,game=fakeGame,require=load,task={wait=function()end}},{__index=base}))
local adapter=fn().new()
local ok,saved,reason=adapter:load(7)
check(not ok and reason=="LOAD_FAILED" and not adapter:save(7,{coins=0}) and writes==0,"failed load never overwrites existing progress")
offline=false;current={coins=5}
ok,saved=adapter:load(8)
check(ok and saved.coins==5 and current.__buildAHoardProfile==1 and current.sessionId=="server-a","legacy save acquires and migrates into a profile lease")
check(adapter:save(8,{coins=10}) and writes==2 and current.data.coins==10 and current.sessionId=="server-a","owned profile saves and renews its lease")
check(adapter:release(8,{coins=11}) and writes==3 and current.data.coins==11 and current.sessionId==nil,"final save releases its profile lease")
check(not adapter:save(8,{coins=12}),"released profile cannot be saved again by the old session")

current={__buildAHoardProfile=1,data={coins=20},sessionId="server-b",sessionTouchedAt=os.time()}
ok,saved,reason=adapter:load(9)
check(not ok and reason=="SESSION_ACTIVE" and current.sessionId=="server-b","active cross-server lease rejects a second load")
current.sessionTouchedAt=os.time()-181
ok,saved=adapter:load(9)
check(ok and saved.coins==20 and current.sessionId=="server-a","expired cross-server lease can be recovered")
current.sessionId="server-b"
check(not adapter:save(9,{coins=30}) and not adapter.loaded[9],"server that loses ownership cannot overwrite the profile")

offline=true
current=nil
local failed=fn().new();ok=failed:load(10)
check(not ok and not failed.saving[10],"failed lease acquisition clears adapter state after bounded retries")
-- Update compatibility: rejected records must remain byte-for-byte untouched.
offline=false
for _,record in ipairs({
	{version=7,coins=900},
	{__buildAHoardProfile=2,data={version=5,coins=900}},
	{__buildAHoardProfile=1,data={version=7,coins=900}},
	"invalid record",
}) do
	current=record
	local before=writes
	local probe=fn().new()
	local loaded,_,why=probe:load(20)
	check(not loaded and why=="INCOMPATIBLE_SAVE" and current==record and writes==before and not probe:save(20,{coins=0}),"future or malformed save is preserved without writes")
end
for version=1,5 do
	current={version=version,coins=75,inventoryCounts={Wood=2},crafted={}}
	local probe=fn().new()
	local loaded,data=probe:load(21)
	check(loaded and data.version==6 and data.coins==75,"each supported old save loads without resetting coins")
	local migrated=rules.serialize(rules.normalize(data))
	check(probe:release(21,migrated) and current.data.coins==75 and current.data.inventoryCounts.Wood==2 and current.data.version==6,"old saves migrate and keep deposited items")
	local nextServer=fn().new()
	local reloaded,again=nextServer:load(21)
	check(reloaded and again.coins==75 and again.inventoryCounts.Wood==2,"next release reloads the same durable progress")
end
current={version=5,coins=100}
local stale=fn().new();stale:load(22)
current.data.version=7
local before=writes
check(not stale:save(22,{version=5,coins=0}) and writes==before and current.data.coins==100,"save-time guard also blocks schema downgrades")

current={version=6,coins=10,inventoryCounts={Wood=10},offlineIncomeAt=os.time()-20000}
local earner=fn().new()
local earned,paid=earner:load(30)
check(earned and paid.coins==16210 and current.data.coins==16210,"offline reward is committed atomically with profile acquisition")
local again,same=earner:load(30)
check(again and same.coins==16210,"repeated acquisition cannot claim offline reward twice")
-- Yielding fake storage verifies autosave/final-save ordering without live persistence.
setfenv(fn,setmetatable({script=mod,game=fakeGame,require=load},{__index=base}))
offline=false;current=nil
local queued=fn().new();queued:load(11)
local active,peak,finished,last=0,0,0,nil
backing.UpdateAsync=function(_,_,cb)
 active+=1;peak=math.max(peak,active)
	task.wait(.03);last=cb(current);if last~=nil then current=last end;active-=1
 return last
end
for i=1,3 do task.spawn(function() queued:save(11,{coins=i});finished+=1 end);task.wait() end
local deadline=os.clock()+3
while finished<3 and os.clock()<deadline do task.wait() end
check(finished==3 and peak==1 and last.data.coins==3,"overlapping saves serialize and preserve newest snapshot")
return string.format("%d security checks passed",count)
