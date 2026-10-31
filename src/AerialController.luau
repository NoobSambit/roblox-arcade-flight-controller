--!strict
-- Server-owned arcade hover mode. Other flight modes can use a different controller
-- through the same start/land/stop interface; no asset or city paths live here.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Motion = require(script.Parent.ArcadeMotion)
local Transmission = require(script.Parent.Transmission)

export type Input = {throttle: number, steer: number, lift: number, brake: boolean, boost: boolean?, stale: boolean?}
export type Tune = Motion.Tune & {
	ClimbSpeed: number, DescentSpeed: number, Ceiling: number, HoverHeight: number,
	LandingSpeed: number, FloorY: number, GroundProbe: number, VerticalResponse: number,
	VerticalAcceleration: number, GroundMargin: number, BankDegrees: number,
	PitchDegrees: number, BrakePitchDegrees: number, OrientationResponse: number,
	DriftResponse: number, HorizontalAcceleration: number, BobAmplitude: number,
	BobFrequency: number, AnimationResponse: number, WorldRadius: number,
	CollisionMargin: number, CollisionLookahead: number,
	Transmission: {Bands: {number}, Power: {number}, Hysteresis: number,
		ShiftDuration: number, ShiftPower: number, MinShiftInterval: number},
}
export type Telemetry = {altitude: number, mode: string, on: boolean,
	gear: number, rpm: number, serial: number, shift: number, throttle: number, bank: number}
local Controller = {}

function Controller.start(model: Model, seat: Seat, tune: Tune, readInput: () -> Input,
	publish: (Telemetry) -> ())
	local root = assert(model.PrimaryPart,"Aerial vehicle needs a PrimaryPart")
	assert(not root:FindFirstChild("FlightAttachment"),"Aerial controller already running")
	local attachment = Instance.new("Attachment")
	attachment.Name = "FlightAttachment"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "HoverVelocity"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.ForceLimitsEnabled = true
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	velocity.Parent = root
	local rotation = Instance.new("AlignOrientation")
	rotation.Name = "HoverOrientation"
	rotation.Attachment0 = attachment
	rotation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	rotation.Responsiveness = tune.OrientationResponse
	rotation.MaxAngularVelocity = math.rad(tune.TurnRate+60)
	rotation.Parent = root
	root:SetNetworkOwner(nil)
	local bounds, size = model:GetBoundingBox()
	local clearance = math.max(root.Size.Y/2,root.Position.Y-(bounds.Y-size.Y/2))+tune.GroundMargin
	local _, yaw = root.CFrame:ToOrientation()
	local motion = Motion.new(yaw)
	local targetY = root.Position.Y
	local vertical, bank, pitch, bobClock = 0, 0, 0, 0
	local landing, stopped = true, false
	local previousPilot: Humanoid? = nil
	local ground = tune.FloorY
	local stage = Transmission.new()
	local groundClock, stateClock = 1, 1
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local probeOffsets = {Vector3.zero,Vector3.new(5,0,8),Vector3.new(-5,0,8),
		Vector3.new(5,0,-8),Vector3.new(-5,0,-8)}
	local function updateGround()
		local filter: {Instance} = {model}
		for _, player in Players:GetPlayers() do
			if player.Character then table.insert(filter,player.Character) end
		end
		params.FilterDescendantsInstances = filter
		local highest = tune.FloorY
		for _, offset in probeOffsets do
			local start = root.Position+CFrame.Angles(0,motion.yaw,0):VectorToWorldSpace(offset)+Vector3.yAxis*.5
			local hit = workspace:Raycast(start,-Vector3.yAxis*tune.GroundProbe,params)
			if hit then highest = math.max(highest,hit.Position.Y) end
		end
		ground = highest
	end
	updateGround()
	local connection = RunService.PreSimulation:Connect(function(dt)
		if stopped or not model.Parent then return end
		dt = math.min(dt,.1)
		groundClock += dt
		stateClock += dt
		bobClock += dt
		if groundClock >= .1 then updateGround() groundClock = 0 end
		local input = readInput()
		local pilot = seat.Occupant
		if pilot and pilot.Health <= 0 then pilot = nil end
		-- Occupancy starts flight independently of the first control packet or E key.
		if pilot ~= previousPilot then
			landing = pilot == nil
			targetY = root.Position.Y
			previousPilot = pilot
		end
		if not pilot then landing = true end
		local live = pilot ~= nil and not input.stale
		if live and input.lift > .1 then landing = false end
		local floor = ground+clearance
		local hoverFloor = ground+math.max(clearance,tune.HoverHeight)
		local ceiling = math.max(hoverFloor,tune.Ceiling)
		local lift = if live then input.lift else 0
		if landing then
			targetY = math.max(floor,math.min(targetY,root.Position.Y)-tune.LandingSpeed*dt)
		else
			local climb = if lift >= 0 then tune.ClimbSpeed else tune.DescentSpeed
			-- At release, arrest vertical motion at the current height instead of
			-- chasing a target that may have run far ahead during a long climb.
			targetY = math.clamp(targetY+lift*climb*dt,hoverFloor,ceiling)
			if lift ~= 0 then targetY = math.clamp(targetY,root.Position.Y-12,root.Position.Y+12) end
		end
		local actual = root.AssemblyLinearVelocity
		local horizontal = Vector3.new(actual.X,0,actual.Z)
		-- Observe collisions rather than continually restoring pre-impact speed.
		motion.speed = horizontal.Magnitude*(if motion.speed < -.01 then -1 else 1)
		Transmission.step(stage,tune.Transmission,horizontal.Magnitude,dt)
		local throttle = if live and not landing and not input.brake then input.throttle else 0
		local steer = if live and not landing then input.steer else 0
		local brake = input.brake or not live or landing
		local acceleration = Motion.step(motion,tune,throttle,steer,brake,stage.accelerationScale,dt)
		local facing = CFrame.Angles(0,motion.yaw,0)
		local heading = root.CFrame.LookVector*Vector3.new(1,0,1)
		heading = if heading.Magnitude > .1 then heading.Unit else facing.LookVector
		local lateral = horizontal-heading*horizontal:Dot(heading)
		local command = heading*motion.speed+lateral*math.exp(-tune.DriftResponse*dt)
		if command.Magnitude > .001 then command = command.Unit*math.abs(motion.speed) end
		local flatPosition = root.Position*Vector3.new(1,0,1)
		if flatPosition.Magnitude > tune.WorldRadius and command:Dot(flatPosition) > 0 then
			local normal = flatPosition.Unit
			command -= normal*command:Dot(normal)
		end
		local idle = if not landing and math.abs(lift) < .01 then 1-math.clamp(horizontal.Magnitude/25,0,1) else 0
		local bob = math.sin(bobClock*tune.BobFrequency*2*math.pi)*tune.BobAmplitude*idle
		local verticalGoal = math.clamp((targetY+bob-root.Position.Y)*tune.VerticalResponse,
			-tune.DescentSpeed,tune.ClimbSpeed)
		vertical += math.clamp(verticalGoal-vertical,-tune.VerticalAcceleration*dt,tune.VerticalAcceleration*dt)
		local desired = command+Vector3.yAxis*vertical
		-- Sweep the collision hull forward, upward and down, including fast flight.
		-- Physical collisions remain enabled; this bounds commands before impact.
		local sweep = desired*(dt+tune.CollisionLookahead)
		if sweep.Magnitude > .001 then
			local hit = workspace:Blockcast(root.CFrame,root.Size,sweep,params)
			if hit then
				local into = desired:Dot(hit.Normal)
				if into < 0 then
					local allowed = math.clamp((hit.Distance-tune.CollisionMargin)/sweep.Magnitude,0,1)
					desired -= hit.Normal*into*(1-allowed)
				end
				if math.abs(hit.Normal.Y) > .5 and math.sign(vertical) == -math.sign(hit.Normal.Y) then
					targetY = root.Position.Y vertical = desired.Y
				end
			end
		end
		local mass = root.AssemblyMass
		velocity.MaxAxesForce = Vector3.new(mass*tune.HorizontalAcceleration,
			mass*(workspace.Gravity+tune.VerticalAcceleration),mass*tune.HorizontalAcceleration)
		velocity.VectorVelocity = desired
		rotation.MaxTorque = mass*40000
		local airClearance = math.clamp((root.Position.Y-floor)/4,0,1)
		local blend = 1-math.exp(-tune.AnimationResponse*dt)
		bank += (-motion.steering*math.rad(tune.BankDegrees)*math.clamp(horizontal.Magnitude/50,0,1)*airClearance-bank)*blend
		local pitchGoal = if acceleration < -1 then tune.BrakePitchDegrees*math.clamp(-acceleration/tune.Braking,0,1)
			else -tune.PitchDegrees*math.clamp(acceleration/tune.Acceleration,0,1)
		pitch += (math.rad(pitchGoal)*airClearance-pitch)*blend
		rotation.CFrame = facing*CFrame.Angles(pitch,0,bank)
		if stateClock >= .1 then
			stateClock = 0
			local landed = landing and root.Position.Y-floor < .5 and math.abs(actual.Y) < 1
			publish({altitude=math.max(0,root.Position.Y-ground),
				mode=if landed then "LANDED" elseif landing then "LANDING" else "HOVER",
				on=pilot ~= nil or not landed,gear=stage.gear,rpm=stage.rpm,serial=stage.serial,
				shift=stage.shift/tune.Transmission.ShiftDuration,throttle=throttle,bank=bank})
		end
	end)
	local function stop()
		if stopped then return end
		stopped = true
		connection:Disconnect()
		velocity:Destroy() rotation:Destroy() attachment:Destroy()
	end
	local destroying = model.Destroying:Once(stop)
	return {
		land = function() landing = true end,
		stop = function() stop() destroying:Disconnect() end,
	}
end

return Controller
