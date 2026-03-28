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
//   vga_clk + rst
//       └─► joystick_adc         → Avalon-MM ADC IP (ch0 = left, ch1 = right)
//       └─► joystick_adc_reader  → joy_left[1:0], joy_right[1:0]
//
// Unwritten modules (stubbed with wire/reg defaults below):
//   - game_state_machine  (controls game_state, balls_remaining, score, level)
//   - ball_physics        (updates ball_x, ball_y each game tick)
//   - hole_collision      (detects ball entering target hole → signals FSM)
//
// Joystick input (ADC):
//   ADC ch0 (left  joystick): > 2.7 V → DOWN (01), < 2.0 V → UP (10)
//   ADC ch1 (right joystick): > 2.7 V → DOWN (01), < 2.0 V → UP (10)
//   Thresholds assume Vref = 3.3 V, 12-bit ADC (full-scale 4095).
//
// Reset:
//   SW[9] active-high = user reset.  Also held in reset until PLL locks.
// =============================================================================

module ice_cold_beer_top (
    input  wire        MAX10_CLK1_50,

    input  wire [1:0]  KEY,          // KEY[0] = skip hole (active-low)
                                     // KEY[1] = lose ball  (active-low)
    input  wire [9:0]  SW,           // SW[9] = reset (active-high)

    output wire [9:0]  LEDR,         // balls_remaining shown on LEDs

    output wire [7:0]  HEX0,         // score  ones digit  (BCD 7-seg, active-low)
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
    .areset (1'b0),
    .inclk0 (MAX10_CLK1_50),
    .c0     (vga_clk),
    .locked (pll_locked)
);

// Active-high synchronous reset: hold until PLL locked or SW[9] asserted
wire rst = ~pll_locked | SW[9];

// ---------------------------------------------------------------------------
// 2.  VGA sync generator  —  produces h_cnt, v_cnt, blank_n, HS, VS
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
// 3.  ADC joystick interface
//     joystick_adc        — Altera IP core
//     joystick_adc_reader — polls ch0/ch1, decodes to 2-bit joy signals
// ---------------------------------------------------------------------------

// Avalon-MM wires between joystick_adc_reader (master) and joystick_adc (slave)
wire        adc_write;
wire [31:0] adc_writedata;
wire [2:0]  adc_address;
wire        adc_read;
wire [31:0] adc_readdata;
wire        adc_waitrequest;

joystick_adc adc_ip (
    .clk_clk                     (vga_clk),
    .reset_reset_n               (~rst),
    .adc_0_adc_slave_write       (adc_write),
    .adc_0_adc_slave_writedata   (adc_writedata),
    .adc_0_adc_slave_address     (adc_address),
    .adc_0_adc_slave_read        (adc_read),
    .adc_0_adc_slave_readdata    (adc_readdata),
    .adc_0_adc_slave_waitrequest (adc_waitrequest)
);

wire [1:0] joy_left_sig;
wire [1:0] joy_right_sig;

joystick_adc_reader #(
    .THRESH_HIGH (12'd3352),   // > 2.7 V at 12-bit resolution
    .THRESH_LOW  (12'd2482)    // < 2.0 V at 12-bit resolution
) adc_reader (
    .clk             (vga_clk),
    .rst             (rst),
    .adc_write       (adc_write),
    .adc_writedata   (adc_writedata),
    .adc_address     (adc_address),
    .adc_read        (adc_read),
    .adc_readdata    (adc_readdata),
    .adc_waitrequest (adc_waitrequest),
    .joy_left        (joy_left_sig),
    .joy_right       (joy_right_sig)
);

// ---------------------------------------------------------------------------
// 4.  Game signals
// ---------------------------------------------------------------------------

// --- Ball physics ----------------------------------------------------------
wire [7:0] ball_x;
wire [6:0] ball_y = 7'd60;   // stub; computed in renderer from bar
wire       ball_lost;

ball_physics ball_phys (
    .clk         (vga_clk),
    .rst         (rst),
    .ball_event  (ball_event),
    .tick_60hz   (tick_60hz),
    .game_state  (game_state),
    .bar_left_y  (bar_left_y),
    .bar_right_y (bar_right_y),
    .ball_x      (ball_x),
    .ball_lost   (ball_lost)
);

// --- Game state machine ----------------------------------------------------
wire [2:0]  game_state;
wire [3:0]  level;
wire [3:0]  current_step;
wire [2:0]  balls_remaining;
wire [15:0] score;
wire [5:0]  target_hole_id;
wire        ball_event;

game_state_machine gsm (
    .clk            (vga_clk),
    .rst            (rst),
    .key_hole       (~KEY[0]),
    .key_ball_lost  (~KEY[1]),
    .ball_x         (ball_x),
    .ball_y         (ball_y),
    .ball_lost      (ball_lost),
    .game_state     (game_state),
    .level          (level),
    .current_step   (current_step),
    .balls_remaining(balls_remaining),
    .score          (score),
    .target_hole_id (target_hole_id),
    .ball_event     (ball_event)
);

// --- Bar controller --------------------------------------------------------
wire [9:0] bar_left_y_10, bar_right_y_10;

bar_controller #(
    .Y_MIN    (10'd20),
    .Y_MAX    (10'd110),
    .MAX_DY   (10'd20),
    .BAR_SPEED(1),
    .START_Y  (10'd110)
) bar_ctrl (
    .clk        (vga_clk),
    .rst        (rst),
    .ball_event (ball_event),
    .en         (1'b1),
    .tick_60hz  (tick_60hz),
    .joy_left   (joy_left_sig),    // from ADC reader (was SW-based)
    .joy_right  (joy_right_sig),   // from ADC reader (was SW-based)
    .bar_left_y (bar_left_y_10),
    .bar_right_y(bar_right_y_10)
);

wire [6:0] bar_left_y  = bar_left_y_10[6:0];
wire [6:0] bar_right_y = bar_right_y_10[6:0];

// ---------------------------------------------------------------------------
// 5.  Pixel renderer
// ---------------------------------------------------------------------------
wire vga_r, vga_g, vga_b, ball_gray;

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
    .current_step   (current_step),
    .balls_remaining(balls_remaining),
    .score          (score),
    .target_hole_id (target_hole_id),
    .vga_r          (vga_r),
    .vga_g          (vga_g),
    .vga_b          (vga_b),
    .ball_gray      (ball_gray)
);

// ---------------------------------------------------------------------------
// 6.  VGA DAC  —  1-bit colour → 4-bit resistor ladder (DE10-Lite)
// ---------------------------------------------------------------------------
assign VGA_R = ball_gray ? 4'h6 : {4{vga_r}};
assign VGA_G = ball_gray ? 4'h6 : {4{vga_g}};
assign VGA_B = ball_gray ? 4'h6 : {4{vga_b}};

// ---------------------------------------------------------------------------
// 7.  Status outputs
// ---------------------------------------------------------------------------

// LEDs: show balls_remaining (one LED per ball, active-high)
assign LEDR[2:0] = balls_remaining;
assign LEDR[9:3] = 7'b0;

// 7-segment displays: all off until BCD decoder is wired in
assign HEX0 = 8'hFF;
assign HEX1 = 8'hFF;
assign HEX2 = 8'hFF;
assign HEX3 = 8'hFF;
assign HEX4 = 8'hFF;
assign HEX5 = 8'hFF;

endmodule