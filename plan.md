# **Ice-Cold Beer — Task Delegation Plan**

## **Context**

Two students (Abie and Ben) need to split implementation of the FPGA "Ice-Cold Beer" game with minimal overlap and clean interfaces. The game reads two 1-bit joystick inputs, runs physics/game logic, and outputs to VGA (640x480). Existing files (vga\_pll, video\_sync\_generator, number\_driver, hole\_positions.vh) are available but under review — treat as potential reuse candidates only.

---

## **Module Breakdown**

| Module | Owner | Purpose |
| :---- | :---- | :---- |
| top.v | Ben | Top-level: wires all modules together, maps DE10-Lite pins |
| game\_fsm.v | Ben | Main FSM: START\_MENU → INIT\_GAME → ... → GAME\_OVER per mermaid diagram |
| ball\_physics.v | Ben | Updates ball\_x, ball\_y, vel\_x, vel\_y each game tick based on bar slope |
| collision\_detect.v | Ben | Checks ball position against 37 hole coords \+ boundary; outputs hole\_entered, hole\_id |
| bar\_controller.v | Ben | Maps joystick inputs to bar\_left\_y and bar\_right\_y (ramp up/down each tick) |
| level\_data.v | Ben | Stores target hole assignment per level per round (ROM or parameterized) |
| vga\_renderer.v | Abie | Pixel-by-pixel color output: background, holes, bar, ball, UI overlay |
| start\_menu.v | Abie | Renders start screen; outputs start button press to FSM |
| game\_over\_screen.v | Abie | Renders lose screen with score and high score |
| score\_display.v | Abie | Draws level, balls remaining, score using number\_driver font |
| vga\_sync.v | Shared | video\_sync\_generator \+ vga\_pll wrappers (already complete) |

---

## **Task Assignment**

### **Abie — VGA / Rendering**

* vga\_renderer.v (core rendering engine)  
* start\_menu.v  
* game\_over\_screen.v  
* score\_display.v  
* Integration of number\_driver.v, video\_sync\_generator.v, vga\_pll.v

### **Ben — Game Logic / Input**

* top.v  
* game\_fsm.v  
* ball\_physics.v  
* collision\_detect.v  
* bar\_controller.v  
* level\_data.v

---

## **Interface Specification**

### **Ben → Abie**

These are the signals Abie's renderer consumes. Ben must provide them as registered outputs from his modules.

```verilog
// Clock & reset (top.v)
input  wire        clk_25,          // 25 MHz VGA pixel clock
input  wire        rst,             // synchronous active-high reset

// VGA sync (video_sync_generator, shared)
input  wire        blank_n,
input  wire [10:0] h_cnt,           // pixel column 0-799
input  wire [9:0]  v_cnt,           // pixel row 0-524

// Ball position (ball_physics.v) — in SCREEN coordinates (10-bit)
input  wire [9:0]  ball_x,          // ball center X, 0-639
input  wire [9:0]  ball_y,          // ball center Y, 0-479

// Bar endpoints (bar_controller.v) — in SCREEN coordinates
input  wire [9:0]  bar_left_y,      // screen Y of left end of bar
input  wire [9:0]  bar_right_y,     // screen Y of right end of bar

// Game state (game_fsm.v)
input  wire [2:0]  game_state,      // encoded FSM state (see enum below)
input  wire [3:0]  level,           // current level 1-10
input  wire [2:0]  balls_remaining, // 0-5
input  wire [15:0] score,           // accumulated score

// Target hole highlight (level_data.v -> game_fsm.v)
input  wire [5:0]  target_hole_id,  // index 0-36 into HOLE_X/HOLE_Y arrays
```

### **Abie → Ben**

```verilog
// Start/play-again button confirmed (start_menu.v)
output wire        start_btn,       // 1-cycle pulse when player presses start
output wire        play_again_btn,  // 1-cycle pulse on game-over screen
```

### **game\_state Encoding (agree on values)**

```verilog
3'b000  S_START_MENU
3'b001  S_PLAYING       // includes INIT_GAME, INIT_ROUND, SPAWN_BALL
3'b010  S_GAME_OVER
3'b011  (reserved)
```

---

## **Design Decisions — Must Agree Before Coding**

**1\. Coordinate System**

* Origin: top-left, (0,0)  
* Screen resolution: 640×480  
* Game-pixel scale: 4× (160×120 game pixels → 640×480 screen pixels)  
* All ball and bar positions are in screen coordinates (multiply game-pixel coords by 4\)  
* Ball represented as center point; radius \= 4 screen pixels (1 game pixel)

**2\. Bar Geometry**

* Bar spans width: X from pixel 39-119 (this is then magnified 4x)  
* Left end Y \= bar\_left\_y, right end Y \= bar\_right\_y  
* Bar thickness: 2 screen pixels (drawn as filled rectangle between endpoints)  
* Abie renders the bar as a line/rect connecting the two endpoints  
* Ben computes endpoint positions; valid range: e.g., Y = [60, 420] to stay on screen

**3\. Joystick → Bar Mapping**

* Each joystick is 2-bit: 00 \= not moving, 10 \= raise that side, 01 \= lower that side,   
* Bar moves at a fixed rate per game tick (e.g., \+/- 2 screen pixels per tick)  
* Ben defines the rate constant; agreed value needed before integration

**4\. Physics Parameters (Ben decides, Abie just uses ball\_x/ball\_y)**

* Sub-pixel velocity using fixed-point? Suggest: vel_x[9:0] as Q6.4 (4 fractional bits)  
* Gravity: constant downward acceleration applied each game tick  
* Ball stops when resting on bar (velocity zeroed when ball\_y reaches bar surface)

**5\. Game Tick Clock**

* Physics updates on a slower clock (e.g., 60Hz \= every 25MHz/416667 cycles)  
* VGA rendering always on 25 MHz pixel clock  
* Ben generates the game tick; Abie's renderer is purely combinational on h\_cnt/v\_cnt

**6\. Hole Rendering**

* Holes at positions from hole\_positions.vh, scaled ×4 for screen coords (*trivial \- applies to all)*  
* Target hole highlighted differently (different color or border)  
* Abie renders all holes; target\_hole\_id from Ben tells Abie which to highlight

**7\. Level/Round Data**

* 10 levels per round; target hole per level is preset (not random for simplicity)  
* Ben defines the level_data ROM; format: target_hole_id = level_data[round][level]  
* Agree on number of rounds before Ben hardcodes the ROM size

**8\. Score System**

* Points awarded on success (e.g., 100 × level)  
* High score: stored in a register, never reset (persists until power cycle)  
* Ben tracks score; Abie displays it

**9\. Ball Spawn Position**

* Ball always spawns at a fixed screen position (bottom-center of playfield)  
* E.g., ball\_x \= 320, ball\_y \= 440 (in screen coords)  
* Both agree on this value so collision/boundary logic matches rendering

**10\. Boundary / Death Condition**

* Implement max and min bar\_\*\_x and bar\_\*\_y heights, with an additional restriction of height difference between left and right bar values  
* Constant boundary for the sides (ball can’t roll past this) [39], [119]

---

## **Integration Strategy**

1. Ben delivers a stub top.v early with all interface signals wired to constants — lets Abie test rendering independently.  
2. Abie delivers a stub renderer that outputs a solid color based on game\_state — lets Ben test FSM transitions on 7-seg or LEDs first.  
3. Integration test order:  
   * VGA sync → confirm stable 640×480 image  
   * Renderer with hardcoded ball/bar positions → confirm drawing is correct  
   * Joystick → bar\_controller → renderer → confirm bar moves  
   * Ball physics → renderer → confirm ball moves and gravity works  
   * Collision → FSM → confirm state transitions  
   * Full game loop