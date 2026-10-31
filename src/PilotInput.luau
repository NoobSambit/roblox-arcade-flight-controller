--!strict
-- One server-owned RemoteEvent per vehicle. Clients send intent, never physics/results.
local RunService = game:GetService("RunService")
local Controller = require(script.Parent.AerialController)
local PilotInput = {}

local function finite(value: unknown): boolean
	return typeof(value)=="number" and value==value and math.abs(value)<math.huge
end

function PilotInput.bind(seat: Seat, remote: RemoteEvent, onLand: () -> ())
	assert(RunService:IsServer(),"PilotInput must run on the server")
	local input: Controller.Input = {throttle=0,steer=0,lift=0,brake=true,stale=true}
	local lastInput, sequence = 0, -1
	local tokens, actionTokens, refill = 24, 2, os.clock()
	local stopped = false
	local connections: {RBXScriptConnection} = {}
	local function reset()
		lastInput=0 sequence=-1 tokens=24 actionTokens=2 refill=os.clock()
		input={throttle=0,steer=0,lift=0,brake=true,stale=true}
	end
	table.insert(connections,seat:GetPropertyChangedSignal("Occupant"):Connect(reset))
	table.insert(connections,remote.OnServerEvent:Connect(function(player,action,...)
		local pilot=seat.Occupant
		if stopped or not pilot or pilot.Health<=0 or pilot.Parent~=player.Character then return end
		local now=os.clock()
		local elapsed=math.max(0,now-refill) refill=now
		tokens=math.min(24,tokens+elapsed*20)
		actionTokens=math.min(2,actionTokens+elapsed*2)
		if action=="Control" then
			if tokens<1 then return end
			tokens-=1
			if select("#",...)~=5 then return end
			local throttle,steer,lift,brake,seq=...
			if not finite(throttle) or not finite(steer) or not finite(lift) then return end
			if math.abs(throttle)>1 or math.abs(steer)>1 or math.abs(lift)>1 then return end
			if typeof(brake)~="boolean" or not finite(seq) or seq%1~=0 or seq<0 or seq>2147483647 or seq<=sequence then return end
			sequence=seq lastInput=now
			input={throttle=throttle,steer=steer,lift=lift,brake=brake,stale=false}
		elseif action=="Land" and select("#",...)==0 and actionTokens>=1 then
			actionTokens-=1 onLand()
		end
	end))
	local function stop()
		if stopped then return end
		stopped=true
		for _,connection in connections do connection:Disconnect() end
		table.clear(connections) reset()
	end
	table.insert(connections,seat.Destroying:Once(stop))
	table.insert(connections,remote.Destroying:Once(stop))
	return {
		read=function(): Controller.Input
			if stopped or os.clock()-lastInput>.5 then
				return {throttle=0,steer=0,lift=0,brake=true,stale=true}
			end
			return table.clone(input)
		end,
		stop=stop,
	}
end

return PilotInput
