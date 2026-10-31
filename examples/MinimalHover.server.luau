--!strict
-- Put this Script in ServerScriptService. Run in a development place.
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Flight = ServerScriptService:WaitForChild("ArcadeFlight",10)
assert(Flight,"Install ArcadeFlight first")
local Controller = require(Flight.Core.AerialController)
local PilotInput = require(Flight.Core.PilotInput)
local preset = require(Flight.Configs.DefaultHover)
assert(not workspace:FindFirstChild("SampleHover"),"Example already exists")
assert(not ReplicatedStorage:FindFirstChild("ArcadeFlightExample"),"Example remote already exists")

local model=Instance.new("Model") model.Name="SampleHover"
local root=Instance.new("Part") root.Name="Root" root.Size=Vector3.new(8,2,16)
root.CFrame=CFrame.new(0,6,0) root.Anchored=true root.Parent=model
local seat=Instance.new("Seat") seat.Name="PilotSeat" seat.Size=Vector3.new(2,1,2)
seat.CFrame=root.CFrame*CFrame.new(0,1.5,0) seat.Massless=true seat.Parent=model
local weld=Instance.new("WeldConstraint") weld.Part0=root weld.Part1=seat weld.Parent=seat
model.PrimaryPart=root model.Parent=workspace root.Anchored=false

local remote=Instance.new("RemoteEvent") remote.Name="ArcadeFlightExample" remote.Parent=ReplicatedStorage
local controller: {land: () -> (), stop: () -> ()}?=nil
local channel=PilotInput.bind(seat,remote,function() if controller then controller.land() end end)
controller=Controller.start(model,seat,preset,channel.read,function(frame)
	-- Small replicated presentation interface; never sends per-frame physics remotes.
	model:SetAttribute("PropulsionOn",frame.on)
	model:SetAttribute("FlightMode",frame.mode)
	model:SetAttribute("AltitudeStuds",frame.altitude)
	model:SetAttribute("PowerStage",frame.gear)
	model:SetAttribute("PowerRpm",frame.rpm)
	model:SetAttribute("ShiftSerial",frame.serial)
	model:SetAttribute("ShiftBlend",frame.shift)
	model:SetAttribute("FlightThrottle",frame.throttle)
	model:SetAttribute("FlightBank",frame.bank)
end)
model.Destroying:Once(function()
	channel.stop()
	if controller then controller.stop() end
	remote:Destroy()
end)
-- Walk onto the Seat to pilot. Seating triggers automatic hover; E is only ascent.
