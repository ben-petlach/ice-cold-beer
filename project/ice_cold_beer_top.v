module ice_cold_beer_top (
    input  wire        MAX10_CLK1_50,

    input  wire        KEY,           // KEY = reset (active-low)
    input  wire [9:0]  SW,           // SW[9] = reset (active-high)

    output wire [3:0]  VGA_R,
    output wire [3:0]  VGA_G,
    output wire [3:0]  VGA_B,
    output wire        VGA_HS,
    output wire        VGA_VS,

    output wire [7:0]  HEX0,
    output wire [7:0]  HEX1,
    output wire [7:0]  HEX2,
    output wire [7:0]  HEX3,
    output wire [7:0]  HEX4,
    output wire [7:0]  HEX5
);

wire vga_clk;
wire pll_locked;

vga_pll pll (
    .areset (1'b0),
    .inclk0 (MAX10_CLK1_50),
    .c0     (vga_clk),
    .locked (pll_locked)
);

wire rst = ~pll_locked | SW[9] | ~KEY;  

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
    .THRESH_HIGH (12'd2500),   // > 2.0 V 
    .THRESH_LOW  (12'd1600)    // < 1.3 V 
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

// Ball physics
wire [7:0] ball_x;
wire [6:0] ball_y;          
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
    .ball_y      (ball_y),
    .ball_lost   (ball_lost)
);

// Game state machine
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

// Bar controller 
wire [9:0] bar_left_y_10, bar_right_y_10;

bar_controller #(
    .Y_MIN    (10'd8),
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
    .joy_left   (joy_left_sig),    
    .joy_right  (joy_right_sig),   
    .bar_left_y (bar_left_y_10),
    .bar_right_y(bar_right_y_10)
);

wire [6:0] bar_left_y  = bar_left_y_10[6:0];
wire [6:0] bar_right_y = bar_right_y_10[6:0];

// Pixel renderer
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

assign VGA_R = ball_gray ? 4'h6 : {4{vga_r}};
assign VGA_G = ball_gray ? 4'h6 : {4{vga_g}};
assign VGA_B = ball_gray ? 4'h6 : {4{vga_b}};

// Seven-segment display driver — shows "u win" or "u lose" on game over
seven_segment_driver seg_drv (
    .game_state      (game_state),
    .balls_remaining (balls_remaining),
    .HEX5            (HEX5),
    .HEX4            (HEX4),
    .HEX3            (HEX3),
    .HEX2            (HEX2),
    .HEX1            (HEX1),
    .HEX0            (HEX0)
);

endmodule