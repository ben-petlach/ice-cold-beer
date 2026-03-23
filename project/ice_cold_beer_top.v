// =============================================================================
// ice_cold_beer_top.v  —  Top-level entity for DE10-Lite (MAX 10, 10M50)
//
// Instantiation map
// -----------------
//   MAX10_CLK1_50 (50 MHz)
//       └─► vga_pll          → vga_clk (25 MHz), pll_locked
//
//   vga_clk + rst
//       └─► video_sync_generator → h_cnt, v_cnt, blank_n, VGA_HS, VGA_VS
//
//   vga_clk + rst + h_cnt/v_cnt/blank_n + game signals
//       └─► vga_renderer         → vga_r, vga_g, vga_b → VGA_R/G/B[3:0]
//
// Unwritten modules (stubbed with wire/reg defaults below):
//   - game_state_machine  (controls game_state, balls_remaining, score, level)
//   - ball_physics        (updates ball_x, ball_y each game tick)
//   - bar_tilt_ctrl       (maps tilt input → bar_left_y, bar_right_y)
//   - hole_collision      (detects ball entering target hole → signals FSM)
//
// Tilt input (interim):
//   SW[0] pressed → left  end of bar moves down (bar_left_y  increases)
//   SW[1] pressed → right end of bar moves down (bar_right_y increases)
//   Replace SW-based stubs with bar_tilt_ctrl once that module is written.
//
// Reset:
//   KEY[0] (active-low) = user reset.  Also held in reset until PLL locks.
// =============================================================================

module ice_cold_beer_top (
    input  wire        MAX10_CLK1_50,

    input  wire [1:0]  KEY,          // KEY[0] = reset (active-low)
                                     // KEY[1] = start / restart
    input  wire [9:0]  SW,           // SW[1:0] = tilt (interim, see above)

    output wire [9:0]  LEDR,         // balls_remaining shown on LEDs

    output wire [7:0]  HEX0,         // score  ones digit  (BCD 7-seg, active-low; [7]=decimal point, tie high)
    output wire [7:0]  HEX1,         // score  tens digit
    output wire [7:0]  HEX2,         // score  hundreds
    output wire [7:0]  HEX3,         // score  thousands
    output wire [7:0]  HEX4,         // level
    output wire [7:0]  HEX5,         // balls remaining

    output wire [3:0]  VGA_R,
    output wire [3:0]  VGA_G,
    output wire [3:0]  VGA_B,
    output wire        VGA_HS,
    output wire        VGA_VS
);

// ---------------------------------------------------------------------------
// 1.  PLL  —  50 MHz → 25 MHz pixel clock
// ---------------------------------------------------------------------------
wire vga_clk;
wire pll_locked;

vga_pll pll (
    .areset (1'b0),           // never reset PLL after power-on
    .inclk0 (MAX10_CLK1_50),
    .c0     (vga_clk),
    .locked (pll_locked)
);

// Active-high synchronous reset: hold until PLL is locked or KEY[0] pressed
wire rst = ~pll_locked | ~KEY[0];

// ---------------------------------------------------------------------------
// 2.  VGA sync generator  —  produces h_cnt, v_cnt, blank_n, HS, VS
//     All signals are registered; both this module and vga_renderer clock
//     on the same vga_clk edge, so their outputs stay in lockstep.
// ---------------------------------------------------------------------------
wire [10:0] h_cnt;
wire [9:0]  v_cnt;
wire        blank_n;

// 60 Hz tick: one vga_clk pulse at the start of each video frame
wire tick_60hz = (h_cnt == 11'd0) && (v_cnt == 10'd0);

video_sync_generator sync_gen (
    .reset   (rst),
    .vga_clk (vga_clk),
    .blank_n (blank_n),
    .HS      (VGA_HS),
    .VS      (VGA_VS),
    .h_cnt   (h_cnt),
    .v_cnt   (v_cnt)
);

// ---------------------------------------------------------------------------
// 3.  Game signals
//     Replace each stub with the real module output once written.
// ---------------------------------------------------------------------------

// --- Ball physics stub ----------------------------------------------------
// TODO: replace with ball_physics instance
wire [7:0] ball_x    = 8'd79;   // game-pixel centre X (0-159)
wire [6:0] ball_y    = 7'd60;   // game-pixel centre Y (0-119)
wire       ball_lost = 1'b0;    // TODO: ball_physics.ball_lost

// --- Game state machine ---------------------------------------------------
wire [2:0]  game_state;
wire [3:0]  level;
wire [2:0]  balls_remaining;
wire [15:0] score;
wire [5:0]  target_hole_id;

game_state_machine gsm (
    .clk            (vga_clk),
    .rst            (rst),
    .key_start      (~KEY[1]),      // KEY[1] active-low → invert to active-high
    .ball_x         (ball_x),
    .ball_y         (ball_y),
    .ball_lost      (ball_lost),
    .game_state     (game_state),
    .level          (level),
    .balls_remaining(balls_remaining),
    .score          (score),
    .target_hole_id (target_hole_id)
);

// --- Bar controller --------------------------------------------------------
wire [9:0] bar_left_y_10, bar_right_y_10;

bar_controller #(
    .Y_MIN    (10'd20),   // highest allowed game Y
    .Y_MAX    (10'd110),  // lowest allowed game Y
    .MAX_DY   (10'd20),   // max tilt difference (game pixels)
    .BAR_SPEED(1),        // 1 game pixel per 60 Hz tick
    .START_Y  (10'd110)   // start at bottom of play area
) bar_ctrl (
    .clk        (vga_clk),
    .rst        (rst),
    .en         (1'b1),
    .tick_60hz  (tick_60hz),
    .joy_left   ({SW[0], SW[1]}),   // SW0=up, SW1=down
    .joy_right  ({SW[8], SW[7]}),   // SW8=up, SW7=down
    .bar_left_y (bar_left_y_10),
    .bar_right_y(bar_right_y_10)
);

wire [6:0] bar_left_y  = bar_left_y_10[6:0];
wire [6:0] bar_right_y = bar_right_y_10[6:0];

// ---------------------------------------------------------------------------
// 4.  Pixel renderer
// ---------------------------------------------------------------------------
wire vga_r, vga_g, vga_b;

vga_renderer renderer (
    .clk            (vga_clk),
    .rst            (rst),
    .blank_n        (blank_n),
    .h_cnt          (h_cnt),
    .v_cnt          (v_cnt),
    .ball_x         (ball_x),
    .ball_y         (ball_y),
    .bar_left_y     (bar_left_y),
    .bar_right_y    (bar_right_y),
    .game_state     (game_state),
    .level          (level),
    .balls_remaining(balls_remaining),
    .score          (score),
    .target_hole_id (target_hole_id),
    .vga_r          (vga_r),
    .vga_g          (vga_g),
    .vga_b          (vga_b)
);

// ---------------------------------------------------------------------------
// 5.  VGA DAC  —  1-bit colour → 4-bit resistor ladder (DE10-Lite)
//     Replicate the single bit across all 4 DAC bits: 0→0000, 1→1111
// ---------------------------------------------------------------------------
assign VGA_R = {4{vga_r}};
assign VGA_G = {4{vga_g}};
assign VGA_B = {4{vga_b}};

// ---------------------------------------------------------------------------
// 6.  Status outputs
// ---------------------------------------------------------------------------

// LEDs: show balls_remaining (one LED per ball, active-high)
assign LEDR[2:0] = balls_remaining;
assign LEDR[9:3] = 7'b0;

// 7-segment displays: tie off for now (all segments off = 7'b111_1111)
// TODO: wire through a bcd_to_7seg decoder once score/level logic exists
assign HEX0 = 8'hFF;   // all segments + decimal point off (active-low)
assign HEX1 = 8'hFF;
assign HEX2 = 8'hFF;
assign HEX3 = 8'hFF;
assign HEX4 = 8'hFF;
assign HEX5 = 8'hFF;

endmodule
