# Roblox Arcade Flight Controller

A configurable, server-owned Luau controller for arcade hover vehicles.
Designed for responsive pursuit and traversal: steer like a hovering car,
hold altitude when vertical input stops, and keep speed through a turn.

**v0.1.0 supports arcade hover mechanics. Helicopter flight is not implemented.**
There are no bundled vehicle meshes, sounds, textures, paid assets or runtime dependencies.

## Features

- Automatic hover activation when a living pilot occupies the seat.
- Symmetric speed-sensitive steering and strong lateral drift suppression.
- Acceleration, reverse, a short coast period and predictable braking.
- Ground clearance, manual climb/descent, altitude hold and requested landing.
- Self-leveling with subtle turn banking, acceleration dip, braking rise and idle bob.
- Swept root-hull collision checks, a configurable ceiling and radial world boundary.
- Five configurable virtual power stages with RPM and shift telemetry.
- Optional server input boundary with pilot checks, finite/range validation,
  sequence checks, rate limits and stale-input braking/altitude hold.
- Presentation callback for your own HUD, propulsion audio and visual effects.

The physics controller is independent of a particular model, game economy or input UI.
Future hover vehicles supply another preset, without copying the controller.
Different flight modes can later implement the same `start` / `land` / `stop`
integration pattern; this release does not simulate helicopter or fixed-wing aerodynamics.

## Install in Roblox Studio

1. Download `ArcadeFlight-v0.1.0.rbxm` from
   [Releases](https://github.com/NoobSambit/roblox-arcade-flight-controller/releases).
2. Drag it into Studio, then move the resulting **ArcadeFlight** folder into
   **ServerScriptService**. Install one copy.
3. Copy `examples/MinimalHover.server.luau` into a Script in ServerScriptService.
   Copy `examples/Controls.client.luau` into a LocalScript in StarterPlayerScripts.
4. Play in a development place with open ground around `(0, 0, 0)`. Walk onto
   the primitive vehicle's Seat. It automatically hovers; press W to move.

For manual installation, create this exact hierarchy and paste the corresponding files:

```text
ServerScriptService
  ArcadeFlight (Folder)
    Core (Folder)
      AerialController (ModuleScript, src/AerialController.luau)
      ArcadeMotion     (ModuleScript, src/ArcadeMotion.luau)
      Transmission     (ModuleScript, src/Transmission.luau)
      PilotInput       (ModuleScript, src/PilotInput.luau)
    Configs (Folder)
      DefaultHover     (ModuleScript, configs/DefaultHover.luau)
```

Rojo users can build the same folder with
`rojo build default.project.json -o ArcadeFlight.rbxm`.
Rojo is optional; the controller requires no package manager or external library.
Keep LICENSE with redistributed copies. The release model also carries its MIT
notice in a `License` StringValue.

## Connect your own vehicle

Use an unanchored, welded assembly with a Model.PrimaryPart and a welded Seat.
The PrimaryPart should be a sensible collision hull oriented with **-Z forward**.
Keep scenery separate; oversized decorative bounds affect ground clearance.
The host owns spawning, entry permissions, passenger collision rules and cleanup.

```luau
local Flight = game:GetService("ServerScriptService").ArcadeFlight
local Controller = require(Flight.Core.AerialController)
local preset = table.clone(require(Flight.Configs.DefaultHover))
preset.MaxSpeed = 200 -- studs/s; other presets can use the same controller

local handle = Controller.start(vehicle, pilotSeat, preset, readValidatedInput, function(frame)
    -- This callback runs about 10 times per second. Replicate only needed state.
    vehicle:SetAttribute("PropulsionOn", frame.on)
    vehicle:SetAttribute("PowerRpm", frame.rpm)
end)
-- handle.land() requests a controlled landing.
-- handle.stop() removes constraints and connections; safe to call repeatedly.
```

`readValidatedInput()` returns `{throttle, steer, lift, brake, stale?}`:
axes are finite numbers from -1 to 1, brake/stale are booleans. Throttle +1 moves
forward, steer +1 turns right, lift +1 ascends. These are **trusted server inputs**;
the core does not validate an arbitrary client table. Use `PilotInput` or your
own validated remote boundary. The optional `boost` field is reserved and has no effect.
Keep callbacks synchronous and non-yielding. Destroying the model cleans up the
core controller. Stop the input channel when its seat/remote/model is removed.

## Configuration

All core lengths use **studs**, speeds **studs/s**, accelerations **studs/s²**,
times **seconds**, and tuning angles/rates **degrees** / **degrees per second**.
The example converts its display reference using 0.28 metres/stud; the core has
no fixed real-world conversion. Clone a preset before changing it; clone its
nested Transmission table and arrays too when tuning power stages.

| Fields | Default | Purpose |
| --- | --- | --- |
| `MaxSpeed`, `ReverseSpeed` | 277.78, 44.64 | Forward/reverse speed caps |
| `Acceleration`, `Braking` | 67.46, 124.01 | Speed change; acceleration also uses stage power |
| `CoastDelay`, `CoastBraking` | 0.35, 17.86 | Brief coast, then gradual slowing |
| `TurnRate`, `HighSpeedTurnRate` | 100, 65 | Low/high speed steering strength |
| `SteeringResponse`, `DriftResponse` | 12, 18 | Steering smoothing and lateral velocity suppression |
| `HorizontalAcceleration` | 650 | Per-axis horizontal constraint force / assembly mass |
| `HoverHeight`, `GroundMargin` | 8.57, 0.35 | Minimum piloted height and geometry clearance |
| `ClimbSpeed`, `DescentSpeed`, `LandingSpeed` | 50, 35.71, 10.71 | Vertical velocity limits |
| `Ceiling`, `FloorY`, `GroundProbe` | 2142.86, 0, 1500 | Absolute ceiling, fallback ground Y, probe length |
| `VerticalResponse`, `VerticalAcceleration` | 5, 90 | Height correction and vertical velocity smoothing |
| `OrientationResponse` | 24 | AlignOrientation responsiveness |
| `BankDegrees`, `PitchDegrees`, `BrakePitchDegrees` | 8, 3, 5 | Turn bank, acceleration dip and braking rise |
| `AnimationResponse` | 7 | Bank/pitch recovery smoothing |
| `BobAmplitude`, `BobFrequency` | 0.18, 0.45 Hz | Stationary hover bob |
| `WorldRadius` | 16000 | Radial outward-motion boundary around world origin |
| `CollisionMargin`, `CollisionLookahead` | 0.5, 0.08 | Root-hull sweep clearance and lookahead |
| `Transmission.Bands` | 54.56, 109.13, 168.65, 223.21, 277.78 | Stage upper speed bands, same units as speed |
| `Transmission.Power` | 1, .97, .90, .82, .72 | Per-stage acceleration scale |
| `Transmission.Hysteresis` | 5.95 | Downshift gap |
| `Transmission.ShiftDuration`, `ShiftPower`, `MinShiftInterval` | .20, .65, .55 | Virtual shift easing and minimum interval |

Tune positive finite values, ordered bands and matching Power entries on the server.
The preset is developer configuration, not an untrusted remote payload.
Ground clearance takes priority when ground geometry lies above the configured ceiling.
Free flight does not require a ground hit: fallback height and the held target remain available.

## Controls and networking

The minimal client example supports desktop W/S, A/D, E/Q, Shift brake and L land.
It sends bounded intent at 15 Hz, without a custom camera. It is a teaching example;
touch/gamepad UI and a production seating/exit flow belong to the host integration.
If your entry key also controls ascent, ignore its held state until release after seating.

`PilotInput.bind(seat, remote, onLand)` returns `read()` and `stop()`.
Use a server-created RemoteEvent associated with one known vehicle:

| Request | Payload after action | Server rules |
| --- | --- | --- |
| `Control` | throttle, steer, lift, brake, sequence | Exactly 5 values; living seat occupant must belong to caller; finite axes in [-1,1]; boolean brake; increasing integer sequence in [0, 2³¹-1] |
| `Land` | none | Same pilot eligibility; separate action budget |

Control budget: burst 24, refill 20/s. Land budget: burst 2, refill 2/s.
Seat changes reset input and sequence. No accepted packet for 0.5 s causes
braking and altitude hold. Losing the pilot causes landing. After an explicit
landing, positive lift resumes hovering.

The controller calls `SetNetworkOwner(nil)` and simulates on the server.
Server ownership favors authoritative motion over low-latency client prediction.
Do not grant clients ownership and assume intent validation also validates motion.
The package does not implement economy, combat, access rights or movement anti-cheat.

## Presentation and audio interfaces

The `publish(frame)` callback receives `altitude` (studs), `mode`
(`HOVER`, `LANDING`, `LANDED`), `on`, `gear`, `rpm`, `serial` (shift count),
`shift` (remaining shift fraction), `throttle` and `bank` (radians).
Use on/off transitions for startup/shutdown, RPM for motor pitch, and shift state
for a motor dip or effect cue. `examples/Audio.client.luau` shows an optional
consumer using your own permitted Sounds; it ships no audio assets.

Banking/pitching are already applied to the root by AlignOrientation. Welded
visuals follow them; do not add another physics writer. Read root orientation
for a separate cosmetic rig, and use `frame.bank` for hover-unit articulation.
See the server example for a compact replicated attribute interface.

## Verification and limitations

`tests/Motion.luau` returns a function accepting the installed ArcadeFlight folder
and can run in Edit. `tests/Smoke.luau` returns a function accepting that folder,
a live character and an open-ground CFrame; run it on the server during Play.
It clones a disposable pilot and creates/cleans a primitive rig. These files
are test modules, not scripts that should run automatically in production.

The release is checked for standalone initialization, control response, server
ownership, stale-input hold and preservation of the original game's integration.
It has no helicopter flight, fixed-wing flight, boost, autopilot, damage, persistence
or client prediction. Ground probes use a fixed five-point footprint; sweeps use
the PrimaryPart box, not decorative meshes. Boundary handling is a motion guard,
not a complete world safety/anti-cheat system. Streaming, latency, varying hull
sizes and performance need validation in your own world. No mobile performance
or two-client test certification is claimed.

## License and attribution

[MIT](LICENSE), copyright 2026 NoobSambit. See [PROVENANCE.md](PROVENANCE.md).
Only the code and documentation in this repository are licensed here; no rights
to the original game's vehicles, artwork, maps or sounds are included.
