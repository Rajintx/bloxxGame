# Agent Guidance: City Blox (Godot 4.4)

## Critical Facts
- **Engine**: Godot 4.4, GDScript (not C# — dotnet section in `project.godot` is stale)
- **Entry**: `scenes/Main.tscn` → `scripts/main.gd` (Node2D, `_ready()` starts game)
- **Run**: Open project in Godot 4.4 editor, press **F5** (Play). No CLI build/test setup.
- **Blocks**: `RigidBody2D` spawned by `_spawn_new_block()`, frozen until `_release_block()` drops them.
- **Collision layers**: blocks = layer 4, tower = layer 2 after landing. Foundation = layer 2.
- **Wind**: `wind_velocity` applied as force; max wind increases by +10 every 10 landed blocks (`wind_duration_min/max` randomize interval).
- **Camera**: Follows last landed block with `target_camera_y = block.y - 150`, lerp speed 0.8.

## Game Over Conditions (from `main.gd`)
1. Block touches anything except `last_landed_node` (`_on_block_body_entered:209`)
2. Dropped block exits screen bounds (`_on_block_screen_exited:278`)
3. Any of last 3 landed blocks exit screen (`_on_block_screen_exited:282`)

## Non-Obvious Details
- Block parent reassignment on drop: moved from `Crane/BlockContainer` to `Main`, then after landing to `Tower` node.
- `block_dropped` flag prevents multiple drops; reset only after `_score_block()`.
- `FREEZE_MODE_KINEMATIC` + `freeze=true` holds crane block stationary before drop.
- Wind applies only while block is falling (`apply_central_force` in `_physics_process:114`).
- `perfect_threshold = 5.0` pixels for multiplier increase; multiplier caps at 10×.
- Signals connect with `.bind(current_block)` to identify which block triggered collision.
- `contact_monitor = true`, `max_contacts_reported = 4` required for collision events.
- Camera clamped by scene bounds (~550–850); crane recentered at `camera.y - 250`.

## Pause / UI
- **Pause**: Escape (`ui_cancel`) toggles `get_tree().paused`. UI screens (`GameOverScreen`, `PauseScreen`) are `Control` nodes under `UI/`.
- **Restart**: Clears tower & blocks, resets all state, awaits 2 frames for `queue_free` to complete.

## Important Gotchas
- Do **not** delete `.godot/` manually; let Godot manage imports.
- Scene file `Main.tscn` uses external resource `scripts/main.gd` — moving scripts breaks the ext_resource link.
- Block visual is a `ColorRect` with manual offset ±50×25; shape is 100×50.
- `crane_base_x = 400` matches Foundation center (400, 550). Moving Foundation breaks alignment.
- Wind label text: "Calm" if <20% of current max wind; otherwise directional `>> N` or `<< N`.
- `block_physics_material` sets friction=0.8, bounce=0.2 for all blocks.

## File Structure
```
scripts/main.gd      → all game logic (390 lines)
scenes/Main.tscn     → scene tree, UI, camera, crane, foundation
assets/              → images/sounds (if added)
```

## Godot Editor Notes
- Use **Script Editor** → **Edit → Convert Indentation To Spaces** (project uses spaces).
- Keep `VisibleOnScreenNotifier2D` on each block; used to detect screen exit.
- physics material override set per-block; changing `block_physics_material` affects all new blocks.

## Tilt/Stability Feature Requests
If implementing tilt-based falling:
- Track `block.angular_velocity` or `block.rotation` in `_physics_process`.
- Threshold candidate: `abs(block.rotation) > PI/4 (45°)` or `abs(angular_velocity) > X`.
- Consider applying additional torque from wind to increase tilt.
- Trigger `_game_over()` or make block tumble off-screen; ensure it still counts for "last 3 blocks" check if landed before tilt.
