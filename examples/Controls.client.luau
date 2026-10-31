--!strict
-- Put this LocalScript in StarterPlayerScripts alongside the server example.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Actions=game:GetService("ContextActionService")
local UserInputService=game:GetService("UserInputService")
local remote=game:GetService("ReplicatedStorage"):WaitForChild("ArcadeFlightExample",10)
local model=workspace:WaitForChild("SampleHover",10)
assert(remote and remote:IsA("RemoteEvent") and model,"Start the server example first")
local seat=model:WaitForChild("PilotSeat",10) :: Seat
local player=Players.LocalPlayer
local held: {[string]: number}={}
local sequence,clock=0,0
local function piloting(): boolean
	local character=player.Character
	return character~=nil and seat.Occupant~=nil and seat.Occupant.Parent==character
end
local bindings={
	Forward={Enum.KeyCode.W,Enum.KeyCode.Up}, Reverse={Enum.KeyCode.S,Enum.KeyCode.Down},
	Left={Enum.KeyCode.A,Enum.KeyCode.Left}, Right={Enum.KeyCode.D,Enum.KeyCode.Right},
	Up={Enum.KeyCode.E}, Down={Enum.KeyCode.Q}, Brake={Enum.KeyCode.LeftShift}, Land={Enum.KeyCode.L},
}
for name,keys in bindings do
	Actions:BindActionAtPriority("ArcadeFlightExample_"..name,function(_,state)
		if not piloting() or UserInputService:GetFocusedTextBox() then
			table.clear(held) return Enum.ContextActionResult.Pass
		end
		if name=="Land" then
			if state==Enum.UserInputState.Begin then remote:FireServer("Land") end
		else held[name]=if state==Enum.UserInputState.Begin then 1 else 0 end
		return Enum.ContextActionResult.Sink
	end,false,3000,table.unpack(keys))
end
local focus=UserInputService.WindowFocusReleased:Connect(function() table.clear(held) end)
local occupant=seat:GetPropertyChangedSignal("Occupant"):Connect(function() table.clear(held) sequence=0 end)
local heartbeat=RunService.Heartbeat:Connect(function(dt)
	if not piloting() then return end
	clock+=dt if clock<1/15 then return end clock=0
	if UserInputService:GetFocusedTextBox() then table.clear(held) end
	sequence+=1
	remote:FireServer("Control",(held.Forward or 0)-(held.Reverse or 0),
		(held.Right or 0)-(held.Left or 0),(held.Up or 0)-(held.Down or 0),(held.Brake or 0)>0,sequence)
end)
script.Destroying:Once(function()
	heartbeat:Disconnect() focus:Disconnect() occupant:Disconnect()
	for name in bindings do Actions:UnbindAction("ArcadeFlightExample_"..name) end
end)
