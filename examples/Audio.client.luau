--!strict
-- Optional interface example. Supply your own permitted Startup and Motor Sounds
-- under SampleHover.Root. This repository contains no sound assets or asset IDs.
local RunService=game:GetService("RunService")
local model=workspace:WaitForChild("SampleHover",10)
assert(model)
local root=model:WaitForChild("Root",10)
assert(root)
local startup=root:FindFirstChild("Startup")
local motor=root:FindFirstChild("Motor")
local powered=false
local connection=RunService.Heartbeat:Connect(function()
	local on=model:GetAttribute("PropulsionOn")==true
	if on~=powered then
		powered=on
		if on and startup and startup:IsA("Sound") then startup:Play() end
		if motor and motor:IsA("Sound") then
			motor.Looped=true
			if on then motor:Play() else motor:Stop() end
		end
	end
	if motor and motor:IsA("Sound") then
		motor.PlaybackSpeed=.7+.4*(model:GetAttribute("PowerRpm") or 0)
		motor.Volume=.4*(if on then 1 else 0)*(1-.25*(model:GetAttribute("ShiftBlend") or 0))
	end
end)
local function stop()
	connection:Disconnect()
	if motor and motor:IsA("Sound") then motor:Stop() end
end
model.Destroying:Once(stop)
script.Destroying:Once(stop)
