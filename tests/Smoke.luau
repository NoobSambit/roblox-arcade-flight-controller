-- Server Play test. Requires a live character to clone as a disposable pilot.
-- No assets are embedded. Choose an open ground position for the primitive rig.
return function(package,character: Model,at: CFrame)
	local Controller=require(package.Core.AerialController)
	local tune=require(package.Configs.DefaultHover)
	local model=Instance.new("Model") model.Name="ArcadeFlightSmoke"
	local root=Instance.new("Part") root.Size=Vector3.new(8,2,16)
	root.CFrame=at root.Anchored=true root.Parent=model
	local seat=Instance.new("Seat") seat.CFrame=at*CFrame.new(0,2,0)
	seat.Massless=true seat.Parent=model
	local weld=Instance.new("WeldConstraint") weld.Part0=root weld.Part1=seat weld.Parent=seat
	model.PrimaryPart=root model.Parent=workspace root.Anchored=false
	local previous=character.Archivable character.Archivable=true
	local pilot=character:Clone() character.Archivable=previous
	pilot.Name="ArcadeFlightSmokePilot"
	for _,item in pilot:GetDescendants() do
		if item:IsA("BaseScript") then item:Destroy()
		elseif item:IsA("BasePart") then item.CanCollide=false end
	end
	pilot.Parent=workspace pilot:PivotTo(seat.CFrame*CFrame.new(0,3,0))
	local humanoid=pilot:FindFirstChildOfClass("Humanoid")
	assert(humanoid) humanoid.Sit=false seat:Sit(humanoid)
	local input={throttle=0,steer=0,lift=0,brake=false,stale=false}
	local telemetry
	local handle=Controller.start(model,seat,tune,function() return input end,function(frame) telemetry=frame end)
	local ok,result=xpcall(function()
		task.wait(1.5)
		assert(telemetry and telemetry.mode=="HOVER","Automatic hover initialization")
		assert(root.Position.Y>at.Y+1,"Automatic ground clearance")
		assert(root:GetNetworkOwner()==nil,"Physics must remain server-owned")
		input={throttle=1,steer=.5,lift=0,brake=false,stale=false}
		task.wait(1)
		assert(root.AssemblyLinearVelocity.Magnitude>20,"Control response without lift")
		local y=root.Position.Y
		input={throttle=0,steer=0,lift=0,brake=true,stale=true}
		task.wait(2)
		assert(telemetry.mode=="HOVER" and math.abs(root.Position.Y-y)<1,"Packet loss holds altitude")
		assert(root.AssemblyLinearVelocity.Magnitude<1,"Packet loss brakes")
		return "PASS: primitive hover rig, control response, server ownership, stale-input hold"
	end,debug.traceback)
	handle.stop() handle.stop() model:Destroy() pilot:Destroy()
	assert(ok,result)
	return result
end
