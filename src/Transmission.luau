--!strict
-- Virtual power stages only. Never writes physical velocity or selects a gear remotely.
local Transmission = {}
type Tune = {Bands: {number}, Power: {number}, Hysteresis: number,
	ShiftDuration: number, ShiftPower: number, MinShiftInterval: number}
export type State = {gear: number, rpm: number, shift: number, serial: number,
	timeSinceShift: number, accelerationScale: number}

function Transmission.new(): State
	return {gear=1, rpm=0, shift=0, serial=0, timeSinceShift=10, accelerationScale=1}
end

function Transmission.step(state: State, tune: Tune, speedKmh: number, dt: number)
	state.timeSinceShift += dt
	state.shift = math.max(0, state.shift-dt)
	local speed = math.max(0, speedKmh)
	local gear = state.gear
	if state.timeSinceShift >= tune.MinShiftInterval and state.shift == 0 then
		if gear < #tune.Bands and speed >= tune.Bands[gear] then
			gear += 1
		elseif gear > 1 and speed < tune.Bands[gear-1]-tune.Hysteresis then
			gear -= 1
		end
	end
	if gear ~= state.gear then
		state.gear = gear
		state.serial += 1
		state.shift = tune.ShiftDuration
		state.timeSinceShift = 0
	end
	local low = if gear == 1 then 0 else tune.Bands[gear-1]
	state.rpm = math.clamp((speed-low)/(tune.Bands[gear]-low), 0, 1)
	local progress = 1-state.shift/tune.ShiftDuration
	-- Continuous dip/recovery; a shift never changes the velocity target directly.
	local ease = 1-(1-tune.ShiftPower)*math.sin(math.pi*progress)
	state.accelerationScale = tune.Power[gear]*ease
end

return Transmission
