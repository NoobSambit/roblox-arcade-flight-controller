# Provenance

Copyright 2026 NoobSambit. Published under MIT with the project owner's authorization.

| Files | Origin | Publication treatment |
| --- | --- | --- |
| `src/AerialController.luau`, `src/ArcadeMotion.luau` | Original arcade hover implementation, project revision `73a6f9e` | Extracted without physics changes; line endings normalized |
| `src/Transmission.luau` | Original virtual power-stage logic, introduced in revision `23a4121`, retained by `73a6f9e` | Same implementation; independent of physical transmissions |
| `src/PilotInput.luau` | Original server intent validation patterns, adapted to one generic vehicle remote | No game-specific lifecycle, economy or models |
| Preset, examples, tests and documentation | Original extraction work for v0.1.0 | MIT |

No third-party source or runtime dependencies are included. In particular, this
package does not contain A-Chassis code, Roblox marketplace model scripts,
Jailbreak/Mad City implementations, audio recordings, mesh files, textures,
concept artwork, map assets, asset IDs, private project snapshots or credentials.
The handling philosophy is an arcade design reference, not borrowed implementation.

Users supplying their own sounds/models must arrange the corresponding permissions
and licenses. Roblox engine APIs remain provided by Roblox; they are not redistributed.
