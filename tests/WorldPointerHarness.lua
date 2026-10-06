-- Edit-only fixture for the real WorldPointer: no Play mode, no simulated input, nothing left behind.
-- It reproduces the failure that once kept the tutorial trail invisible: a character whose
-- HumanoidRootPart has not replicated yet at the moment CharacterAdded fires.
local client=game:GetService("StarterPlayer").StarterPlayerScripts.Client
local base=getfenv(1)
local cache={}
local function loadModule(mod)
 if cache[mod] then return cache[mod] end
 local fn=assert(loadstring(mod.Source,"="..mod.Name))
 setfenv(fn,setmetatable({script=mod,require=loadModule},{__index=base}))
 local value=fn();cache[mod]=value;return value
end
local WorldPointer=loadModule(client.WorldPointer)
local Art=loadModule(client.WorldArtAssets)
assert(not workspace:FindFirstChild("_PointerFixture"),"Existing fixture; abort")
local fixture=Instance.new("Folder");fixture.Name="_PointerFixture";fixture.Parent=workspace
local function part(name,parent,position)
 local p=Instance.new("Part");p.Name=name;p.Anchored=true;p.CFrame=CFrame.new(position);p.Parent=parent;return p
end
local character=Instance.new("Model");character.Name="_FakeCharacter";character.Parent=fixture
local target=part("_FakeLitterA",fixture,Vector3.new(20,1,10))
local second=part("_FakeLitterB",fixture,Vector3.new(-8,1,4))
local ORANGE,GREEN=Color3.fromRGB(242,111,48),Color3.fromRGB(104,211,67)

local count=0
local function check(ok,message) assert(ok,message);count+=1 end
local ok,err=pcall(function()
 local pointer=WorldPointer.new()
 pointer:setCharacter(character)
 pointer:pointTo(target,ORANGE,"WOOD","COLLECT 5 THINGS")
 check(character:FindFirstChildWhichIsA("Attachment",true)==nil,"nothing may be built before the root part exists")

 local root=part("HumanoidRootPart",character,Vector3.new(0,5,0))
 pointer:pointTo(target,ORANGE,"WOOD","COLLECT 5 THINGS")
 local origin=root:FindFirstChild("TutorialPointerOrigin")
 check(origin~=nil,"the pointer must recover once the root part appears")
 local beam=origin:FindFirstChild("TutorialTrail")
 check(beam~=nil and #beam:GetChildren()>0,"chevrons must exist after root resolves")
 for _,arrow in beam:GetChildren() do
  local aim=Vector3.new(target.Position.X-root.Position.X,0,target.Position.Z-root.Position.Z).Unit
  check(arrow:GetPivot().LookVector:Dot(aim)>.999,"chevron must aim at target")
  for _,arm in arrow:GetChildren() do
   check(arm.Size.Z<.8 and arm.Color==Color3.new(1,1,1) and not arm.CanQuery and not arm.CanCollide,"small white arrows are decorative")
  end
 end
 local first,secondArrow=beam:FindFirstChild("1"),beam:FindFirstChild("2")
 check(first and secondArrow and math.abs((first:GetPivot().Position-secondArrow:GetPivot().Position).Magnitude-1.8)<.001,"arrows use tight even spacing")
 for _,offset in ipairs({Vector3.new(20,0,0),Vector3.new(-20,0,0),Vector3.new(0,0,20),Vector3.new(0,0,-20),Vector3.new(1000,0,0)}) do
  target.Position=root.Position+offset;pointer:updateArrows()
  check(#beam:GetChildren()<=32 and beam["1"]:GetPivot().LookVector:Dot(offset.Unit)>.999,"direction works in every quadrant with bounded arrow count")
 end
 target.Position=Vector3.new(20,1,10);pointer:updateArrows()
 local popup=origin:FindFirstChild("TutorialPopup")
 check(popup~=nil and popup.Enabled and popup.Card.Label.Text=="COLLECT 5 THINGS","the instruction bubble must show its text")
 check(popup.Card:IsA("ImageLabel") and popup.Card.Image==Art.TutorialBubble and popup.Card.BackgroundTransparency==1,"the bubble must use the uploaded art")
 check(popup.Size.X.Offset==280 and popup.Size.Y.Offset==140 and popup.Card.Label.Position.X.Scale>0.13 and popup.Card.Label.Size.X.Scale<0.73,"instruction copy must stay clear of the screw-and-tab frame")
 check(popup.Card.Label:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize==25,"instruction text must be capped instead of expanding into the frame")
 local badge=pointer.destination:FindFirstChild("TutorialTargetBadge")
 check(badge~=nil and badge.Card.Label.Text=="WOOD","the target badge must name the object")
 check(badge.Size.X.Offset==160 and badge.Size.Y.Offset==80 and badge.Card.Label:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize==19,"target badge must remain compact and padded")

 for _,copy in ipairs({"TAKE ALL 5 HOME","OPEN THE WORKBENCH","TIME TO SELL ONE"}) do
  pointer:pointTo(target,ORANGE,"SCRAP METAL",copy)
  check(popup.Card.Label.Position.Y.Scale>=.19 and popup.Card.Label.Position.Y.Scale+popup.Card.Label.Size.Y.Scale<=.65,"wrapped instructions must stay in yellow body: "..copy)
  check(badge.Card.Label.Position.Y.Scale>=.19,"wrapped resource label must lower")
 end
 pointer:pointTo(target,ORANGE,"YOUR HOARD","WOOD")
 check(badge.Card.Label.Position.Y.Scale>=.19,"YOUR HOARD must lower")
 check(popup.Card.Label.Position.Y.Scale<.19,"short single-line placement preserved")

 pointer:pointTo(target,ORANGE,"WOOD","still")
 check(origin:FindFirstChild("TutorialTrail")==beam,"re-pointing at the same target must not rebuild the trail")
 pointer:pointTo(second,GREEN,"STONE","ONE MORE FOR GOOD MEASURE")
 check(target:FindFirstChild("TutorialPointerTarget")==nil,"the old target must be released")
 check(pointer.destination.Parent==second,"the trail must move to the new target")
 check(popup.Card.Label.Text=="ONE MORE FOR GOOD MEASURE","the instruction must update")

 pointer:hide()
 check(origin:FindFirstChild("TutorialTrail")==nil and not popup.Enabled,"hide must release the trail and close the bubble")

 local respawned=Instance.new("Model");respawned.Name="_Respawned";respawned.Parent=fixture
 local newRoot=part("HumanoidRootPart",respawned,Vector3.new(3,5,0))
 pointer:setCharacter(respawned)
 check(root:FindFirstChild("TutorialPointerOrigin")==nil,"respawn must clean up the old character")
 pointer:pointTo(target,ORANGE,"WOOD","COLLECT 5 THINGS")
 check(newRoot:FindFirstChild("TutorialPointerOrigin")~=nil,"the pointer must rebuild on the new character")

 pointer:destroy()
 check(newRoot:FindFirstChild("TutorialPointerOrigin")==nil,"destroy must leave nothing behind")
end)
fixture:Destroy()
assert(ok,err)
return string.format("%d pointer checks passed; fixture removed",count)
