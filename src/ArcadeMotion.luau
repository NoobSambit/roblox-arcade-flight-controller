--!strict
-- Speeds and accelerations are studs/s and studs/s^2. No model or game assets.
local Motion = {}
export type Tune = {
	MaxSpeed: number, ReverseSpeed: number, Acceleration: number, Braking: number,
	CoastDelay: number, CoastBraking: number, TurnRate: number, HighSpeedTurnRate: number,
	SteeringResponse: number,
}
export type State = {speed: number, steering: number, yaw: number, coast: number}

function Motion.new(yaw: number): State
	return {speed=0, steering=0, yaw=yaw, coast=0}
end

function Motion.step(state: State, tune: Tune, throttle: number, steer: number,
	brake: boolean, power: number, dt: number)
	local oldSpeed = state.speed
	local goal = throttle*(if throttle < 0 then tune.ReverseSpeed else tune.MaxSpeed)
	local reversing = goal*oldSpeed < 0
	local acceleration = tune.Acceleration*power
	if brake or reversing then acceleration = tune.Braking end
	if brake then goal = 0 end
	if throttle == 0 and not brake then
		state.coast += dt
		acceleration = if state.coast <= tune.CoastDelay then 0 else tune.CoastBraking
	else state.coast = 0 end
	state.speed += math.clamp(goal-state.speed,-acceleration*dt,acceleration*dt)
	state.steering += (steer-state.steering)*(1-math.exp(-tune.SteeringResponse*dt))
	local rate = tune.TurnRate+(tune.HighSpeedTurnRate-tune.TurnRate)
		*math.clamp(math.abs(state.speed)/tune.MaxSpeed,0,1)
	state.yaw -= state.steering*math.rad(rate)*dt
	return (state.speed-oldSpeed)/math.max(dt,.0001)
end

return Motion
