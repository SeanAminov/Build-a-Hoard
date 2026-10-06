-- Edit-only arrival fixture; synthetic gem roots never enter the real world.
local base=getfenv(1);local cache={};local storage=game:GetService("ServerStorage")
local fixture=Instance.new("Folder");fixture.Name="_GemArrivalFixture";fixture.Parent=storage
local hoard=Instance.new("Folder");hoard.Name="Hoard";hoard.Parent=fixture
local drops=Instance.new("Folder");drops.Name="SpecialDrops";drops.Parent=hoard
local function gem(id)
 local p=Instance.new("Part");p.Name="BasicGem";if id then p:SetAttribute("ItemId",id)end;p.Parent=drops;return p
end
gem("existing")
local fakeGame={GetService=function(_,name)
 if name=="Players" then return {LocalPlayer={WaitForChild=function()return game.StarterGui end}}
 elseif name=="Workspace" then return {CurrentCamera=nil,DescendantAdded=fixture.DescendantAdded,FindFirstChild=function(_,n)return fixture:FindFirstChild(n)end}
 else return game:GetService(name) end
end}
local load
load=function(mod)
 if cache[mod] then return cache[mod] end
 local fn=assert(loadstring(mod.Source));setfenv(fn,setmetatable({script=mod,require=load,game=fakeGame},{__index=base}));local v=fn();cache[mod]=v;return v
end
local c=load(game.StarterPlayer.StarterPlayerScripts.Client.GemAnnouncementController).new()
local n=0;local function check(v,msg)assert(v,msg);n+=1 end
local ok,err=pcall(function()
 check(c.arrivals==0 and not c.group.Visible,"existing gem stays quiet")
 local p=gem("new");task.wait(.05);check(c.arrivals==1 and c.group.Visible,"new arrival announces")
 c:observe(p,false);check(c.arrivals==1,"same identity deduplicated")
 local delayed=gem(nil);task.wait();delayed:SetAttribute("ItemId","late");task.wait(.05);check(c.arrivals==2,"late attributes handled")
 check(c.group.IllustratedFrame.Image~="" and c.group.IllustratedFrame.ScaleType==Enum.ScaleType.Slice,"illustrated scalable frame")
 check(c.group.Title.Text=="A BASIC GEM HAS APPEARED!" and c.group.Subtitle.Text=="ONLY ONE SCAVENGER CAN CLAIM IT","exact announcement copy")
end)
c:destroy();fixture:Destroy();assert(ok,err)
return string.format("%d gem arrival checks passed; fixture removed",n)
