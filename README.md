# Godot FPS Player Controller

A modular, reusable first-person player controller for Godot 4.

---

## Features

- **Smooth movement** — walk, jog, sprint, crouch with lerped transitions
- **Variable height jumping** — short hop on early release, full jump when held
- **Stair stepping** — automatic step-up with camera smoothing
- **Leaning** — left/right lean with geometry collision clamping
- **Headbob & FOV** — per-state bob speeds and intensities, sprint FOV kick
- **Landing feedback** — camera dip on hard landings
- **Interaction system** — cone raycast detects interactables and entities, emits typed signals
- **Light detection** — SubViewport probe samples ambient light level, emits shadow/light signals
- **Animated crosshair** — expands on focus, changes colour by entity type
- **Debug overlay** — live readout of state, speed, floor status, light level, and focused interactable
- **Fully inspector-configurable** — all tunable values exposed via `@export`

---

## Installation

1. Copy the `addons/fps_controller/` folder into your project's `addons/` directory
2. Open your project in Godot 4
3. Instance `player.tscn` into your level

No plugin activation required — the controller is a plain scene, not an editor plugin.

---

## Scene Structure

```
Player (CharacterBody3D)
├── CameraController
├── InputComponent
├── MovementComponent
├── InteractionComponent
├── LightDetector
│   └── SubViewport
│       ├── ProbeCamera
│       └── OctahedronMesh
├── StandingCollisionShape
├── CrouchingCollisionShape
├── StandupCheck (ShapeCast3D)
├── Head (Node3D)
│   └── LeanPivot (Node3D)
│       └── Eyes (Node3D)
│           └── Camera3D
└── UserInterface
    └── CanvasLayer
        ├── Crosshair
        └── DebugOverlay
```

---

## Components

### `InputComponent`
Translates raw input into a clean API. Continuous actions (sprint, walk, lean) are polled each frame. Discrete actions (jump, crouch, interact) emit signals and set consumable flags.

**Signals:** `jump_requested`, `crouch_toggled`, `interact_requested`

---

### `MovementComponent`
Owns all physics: gravity, jumping, horizontal motion, crouching, and stair stepping. Reusable on any `CharacterBody3D` — assign any node that implements the input API to `controller`.

**Signals:** `state_changed(new_state: State)`

**Exports:**
| Group | Property | Default |
|---|---|---|
| Movement Speeds | `speed_sprint` | `4.0` |
| | `speed_jog` | `3.0` |
| | `speed_walk` | `2.0` |
| | `speed_crouch` | `1.5` |
| Jump & Gravity | `jump_velocity` | `10.0` |
| | `gravity_fall` | `3.0` |
| | `gravity_rise` | `4.0` |
| | `gravity_cut` | `8.0` |
| Stair Stepping | `max_step_height` | `0.75` |
| | `step_probe_dist` | `0.35` |

---

### `CameraController`
Handles mouse look, FOV, headbob, sway, lean visuals, and step/landing smoothing. Runs in its own `_process` — no manual update call required.

**Exports:**
| Group | Property | Default |
|---|---|---|
| Mouse Look | `mouse_sensitivity` | `0.2` |
| Field of View | `base_fov` | `90.0` |
| | `sprint_fov_multiplier` | `1.1` |
| Head Height | `standing_head_y` | `1.6` |
| | `crouching_head_y` | `0.8` |
| Lean | `lean_angle` | `8.0` |
| | `lean_offset` | `0.6` |
| Feel | `lerp_speed` | `10.0` |
| | `sway_intensity` | `0.0125` |

---

### `InteractionComponent`
Casts a cone of rays from the camera to detect interactable objects and entities. Emits typed signals on focus/unfocus.

**Signals:** `interactable_focused(interactable)`, `interactable_unfocused`, `entity_focused(entity)`, `entity_unfocused`

**Exports:** `interact_reach`, `entity_reach`, `ray_spread`, `ray_count`

To make an object interactable, add it to the `Openable` group and implement:
```gdscript
func interact(action: StringName, interactor: Node) -> void:
    pass
```

To make an entity detectable, add it to the `NPC` or `Enemy` group.

---

### `LightDetector`
Samples ambient light at the player's position using a SubViewport probe. Emits signals when the player enters or leaves shadow.

**Signals:** `entered_shadow`, `entered_light`

**Properties:** `light_level: float`, `in_shadow: bool`

---

## Input Map

The following actions must be defined in `Project Settings → Input Map`:

| Action | Suggested Key |
|---|---|
| `forward` | W |
| `backward` | S |
| `left` | A |
| `right` | D |
| `jump` | Space |
| `sprint` | Shift |
| `walk` | Alt |
| `crouch` | Ctrl |
| `interact` | E |
| `lean_left` | Q |
| `lean_right` | E |

---

## Extending the Controller

### Custom input source (e.g. AI controller)
Create a node that exposes the same properties as `InputComponent` and assign it to `movement.controller` in your entity's `_ready`:

```gdscript
func _ready() -> void:
    movement.controller = $AIInputComponent
```

### Reacting to state changes
```gdscript
movement.state_changed.connect(func(new_state):
    if new_state == movement.State.SPRINTING:
        $FootstepPlayer.pitch_scale = 1.4
)
```

### Reacting to light changes
```gdscript
light_detector.entered_shadow.connect(func():
    stealth_mode = true
)
```

---

## Requirements

- Godot **4.3** or later
- Forward+ or Mobile renderer (SubViewport light sampling requires rendering)
