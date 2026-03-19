# Pixel & Coordinate Conventions

This document is the authoritative reference for all coordinate systems used in the project.
Every module must follow these rules so coordinate handling stays consistent.

---

## Coordinate Spaces

### 1. VGA Counter Space (hardware-only)
| Signal | Width | Range | Notes |
|--------|-------|-------|-------|
| `h_cnt` | `[10:0]` | 0–799 | Full 800-cycle horizontal period |
| `v_cnt` | `[9:0]`  | 0–524 | Full 525-line vertical period |

- **Used by:** `vga_sync` (or equivalent timing generator) only.
- **Never used** for game logic or rendering comparisons.

### 2. Screen Pixel Space (renderer-internal only)
| Signal | Width | Range | Notes |
|--------|-------|-------|-------|
| `screen_x` | `[9:0]` | 0–639 | Derived: `h_cnt[9:0] - 10'd144` |
| `screen_y` | `[9:0]` | 0–479 | Derived: `v_cnt - 10'd35` |

- **Used by:** `vga_renderer` internally, solely to derive `game_x`/`game_y`.
- Values outside the active window are undefined — always guard with `blank_n`.
- **Do not expose** screen coords to any other module.

### 3. Game Pixel Space (all logic lives here)
| Signal | Width | Range | Notes |
|--------|-------|-------|-------|
| `game_x` | `[7:0]` | 0–159 | `screen_x[9:2]` (>>2 = /4) |
| `game_y` | `[6:0]` | 0–119 | `screen_y[8:2]` (>>2 = /4) |

- **Used by:** all game logic, all I/O ports between modules, `hole_positions.vh`.
- Each game pixel maps to a 4×4 block of screen pixels.
- The playfield is 160×120. Walls at game_x = 39 and game_x = 119.

---

## Conversion Summary

```
VGA counter  →  screen pixel  →  game pixel
h_cnt - 144  =  screen_x      →  screen_x >> 2  =  game_x
v_cnt - 35   =  screen_y      →  screen_y >> 2  =  game_y
```

Reverse (game → screen, e.g. for coordinates entering the renderer):
- No conversion needed — renderers receive game coords and derive screen internally.

---

## Module Rules

| Module type | Allowed spaces | Notes |
|-------------|---------------|-------|
| Game logic (ball, bar, score, state machine) | Game only | All positions/velocities in game coords |
| `vga_renderer` | Game (logic), Screen (internal), VGA (input timing) | Convert once at the top of the module; never pass screen or VGA coords out |
| Future framebuffer / sprite engine | Game only for addresses | Framebuffer addressed in game coords; read address = `{game_y, game_x}` |
| Testbenches | Any | May drive screen/VGA coords for stimulus; compare results in game coords |

---

## Port Bit-Width Reference

| Port | Width | Space | Range |
|------|-------|-------|-------|
| `ball_x` | `[7:0]` | game | 0–159 |
| `ball_y` | `[6:0]` | game | 0–119 |
| `bar_left_y` | `[6:0]` | game | 0–119 |
| `bar_right_y` | `[6:0]` | game | 0–119 |
| `HOLE_X[i]` | `[6:0]` | game | 0–119 (see `hole_positions.vh`) |
| `HOLE_Y[i]` | `[6:0]` | game | 0–119 (see `hole_positions.vh`) |

---

## Hole Tile Specification (from `hole_positions.vh`)
- Tile size: 8×8 game pixels
- Corner cut: 3 pixels per corner, diagonal (`dx + dy < 2`, etc.)
- Collision window: ball center within `[HOLE_X+2, HOLE_X+5] × [HOLE_Y+2, HOLE_Y+5]`

---

## Key Screen-Position Equivalences

| Feature | Game coord | Screen coord |
|---------|-----------|--------------|
| Left wall | `game_x == 39` | `screen_x == 156` |
| Right wall | `game_x == 119` | `screen_x == 476` |
| HUD strip | `game_y < 5` | `screen_y < 20` |
| Full width | 0–159 | 0–639 |
| Full height | 0–119 | 0–479 |
