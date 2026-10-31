--!strict
-- Example preset: all core distances/speeds use studs and seconds; angles use degrees.
-- The conversions below retain the established arcade preset without retuning it.
local metresPerStud = .28
local kmhPerStudPerSecond = metresPerStud*3.6
return table.freeze({
	MaxSpeed=280/kmhPerStudPerSecond, ReverseSpeed=45/kmhPerStudPerSecond,
	Acceleration=68/kmhPerStudPerSecond, Braking=125/kmhPerStudPerSecond,
	CoastBraking=18/kmhPerStudPerSecond, CoastDelay=.35,
	TurnRate=100, HighSpeedTurnRate=65, SteeringResponse=12,
	ClimbSpeed=14/metresPerStud, DescentSpeed=10/metresPerStud,
	Ceiling=600/metresPerStud, HoverHeight=2.4/metresPerStud,
	LandingSpeed=3/metresPerStud, FloorY=0, GroundProbe=1500,
	VerticalResponse=5, VerticalAcceleration=90, GroundMargin=.35,
	BankDegrees=8, PitchDegrees=3, BrakePitchDegrees=5, OrientationResponse=24,
	DriftResponse=18, HorizontalAcceleration=650, AnimationResponse=7,
	BobAmplitude=.18, BobFrequency=.45, WorldRadius=16000,
	CollisionMargin=.5, CollisionLookahead=.08,
	Transmission=table.freeze({
		Bands=table.freeze({55/kmhPerStudPerSecond,110/kmhPerStudPerSecond,
			170/kmhPerStudPerSecond,225/kmhPerStudPerSecond,280/kmhPerStudPerSecond}),
		Power=table.freeze({1,.97,.90,.82,.72}), Hysteresis=6/kmhPerStudPerSecond,
		ShiftDuration=.20, ShiftPower=.65, MinShiftInterval=.55,
	}),
})
