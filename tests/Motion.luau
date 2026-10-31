-- Return a function so the same check can run with any installed package folder.
return function(package)
	local Motion=require(package.Core.ArcadeMotion)
	local tune=require(package.Configs.DefaultHover)
	local left,right=Motion.new(0),Motion.new(0)
	left.speed=tune.MaxSpeed right.speed=tune.MaxSpeed
	for _=1,120 do
		Motion.step(left,tune,1,-1,false,1,1/60)
		Motion.step(right,tune,1,1,false,1,1/60)
	end
	assert(math.abs(left.yaw+right.yaw)<.00001,"Steering symmetry")
	assert(left.yaw>2 and left.speed==tune.MaxSpeed,"High-speed turning retains speed")
	local coast=Motion.new(0) coast.speed=200
	for _=1,18 do Motion.step(coast,tune,0,0,false,1,1/60) end
	assert(coast.speed==200,"Coast grace period")
	for _=1,60 do Motion.step(coast,tune,0,0,false,1,1/60) end
	assert(coast.speed<185 and coast.speed>175,"Gradual coast slowdown")
	for _=1,120 do Motion.step(coast,tune,0,0,true,1,1/60) end
	assert(coast.speed==0,"Braking stops")
	return "PASS: motion, steering symmetry, retained speed, coast and braking"
end
