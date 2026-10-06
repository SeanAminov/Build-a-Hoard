-- Edit-only sign fixture; no time simulation or character input.
local base=getfenv(1);local cache={}
local fixture=Instance.new("Folder");fixture.Name="_StationSignFixture";fixture.Parent=game.ServerStorage
local hoard=Instance.new("Folder");hoard.Name="Hoard";hoard.Parent=fixture
local plots=Instance.new("Folder");plots.Name="Plots";plots.Parent=hoard
local plot=Instance.new("Model");plot.Name="Plot1";plot.Parent=plots
local stations=Instance.new("Folder");stations.Name="Stations";stations.Parent=plot
local afk=Instance.new("Model");afk.Name="AFKSorter";afk.Parent=stations
local anchor=Instance.new("Part");anchor.Name="IndicatorAnchor";anchor.Parent=afk
local bin=Instance.new("Model");bin.Name="CollectionBin";bin.Parent=stations
local binAnchor=Instance.new("Part");binAnchor.Name="IndicatorAnchor";binAnchor.Parent=bin
local binInteraction=Instance.new("Part");binInteraction.Name="InteractionPart";binInteraction.Parent=bin
local fakeGame={GetService=function(_,name)
 if name=="Workspace" then return {FindFirstChild=function(_,n)return fixture:FindFirstChild(n)end}
 else return game:GetService(name)end
end}
local load
load=function(mod)
 if cache[mod]then return cache[mod]end
 local fn=assert(loadstring(mod.Source));setfenv(fn,setmetatable({script=mod,game=fakeGame,require=load,task={spawn=function()end}},{__index=base}));local value=fn();cache[mod]=value;return value
end
local c=load(game.StarterPlayer.StarterPlayerScripts.Client.StationController).new({FireServer=function()end})
local n=0;local function check(v,msg)assert(v,msg);n+=1 end
local ok,err=pcall(function()
 local s={plotId=1,afkInteracted=false,collectionBinInteracted=false,afkActive=false,afkProgressSeconds=0,afkRemainingSeconds=60,hoardTotal=0,storageCapacity=60,serverNow=0,collectionBinTotal=0,collectionBinCapacity=12,collectionBinNextAt=900}
 c:render(s)
 check(c.afkSign.Enabled and c.afkTitle.Text=="AFK HERE" and c.binSign.Enabled and c.binTitle.Text=="COLLECTION BIN","both first-use hints appear before interaction")
 check(c.binSign.Size==UDim2.fromOffset(174,48) and not c.binDetail.Visible,"Collection Bin world hint stays compact and omits counts")
 check(c.prompt~=nil and c.prompt.ActionText=="Open" and c.prompt.Parent==binInteraction,"Collection Bin keeps an Open prompt")
 s.afkInteracted=true;c:render(s)
 check(not c.afkSign.Enabled and c.binSign.Enabled,"used AFK hint hides while idle")
 s.afkActive=true;s.afkRemainingSeconds=17;c:render(s)
 check(c.afkSign.Enabled and c.afkTitle.Text=="SORTING JUNK" and c.afkDetail.Text=="NEXT ITEM IN 17s","active AFK pad restores its live countdown bubble")
 s.afkActive=false;c:render(s)
 check(not c.afkSign.Enabled,"AFK countdown bubble hides again after stepping off")
 s.collectionBinInteracted=true;c:render(s)
 check(not c.binSign.Enabled and c.prompt.Enabled,"Collection Bin hint dismisses after first view while its prompt remains")
end)
c:destroy();fixture:Destroy();assert(ok,err)
return string.format("%d authoritative station sign checks passed; fixture removed",n)
