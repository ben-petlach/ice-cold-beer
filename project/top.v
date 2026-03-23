//Kind of abstract right now, adjust accordingly when the time gets to it

module top (
    input  wire        MAX10_CLK1_50,
    input  wire [1:0]  KEY,
    input  wire [9:0]  SW,
    output wire [3:0]  VGA_R,
    output wire [3:0]  VGA_G,
    output wire [3:0]  VGA_B,
    output wire        VGA_HS,
    output wire        VGA_VS,
    output wire        VGA_CLK,
    output wire        VGA_BLANK_N,
    output wire        VGA_SYNC_N
);

    localparam integer GAME_TICK_DIV = 19'd416_666; // 25 MHz / 60 Hz

    wire rst = ~KEY[0]; // KEY is active-low on DE10-Lite

    wire clk_25;
    wire pll_locked;
    wire sync_reset;

    wire blank_n;
    wire [10:0] h_cnt;
    wire [9:0]  v_cnt;

    // Inter-module signals
    wire [9:0] ball_x;
    wire [9:0] ball_y;
    wire [9:0] bar_left_y;
    wire [9:0] bar_right_y;
    wire [2:0] game_state;
    wire [3:0] level;
    wire [2:0] balls_remaining;
    wire [15:0] score;
    wire [5:0] target_hole_id;

    wire hole_entered;
    wire [5:0] hole_id;
    wire bottom_hit;

    // Driven by vga_renderer (e.g. from screen interaction)
    wire start_btn;
    wire play_again_btn;

    // Game tick signals
    reg [18:0] game_tick_counter;
    reg game_tick;

    wire [1:0] left_stick  = SW[9:8];
    wire [1:0] right_stick = SW[1:0];

    assign sync_reset = rst | ~pll_locked;

    vga_pll u_vga_pll (
        .areset(sync_reset),
        .inclk0(MAX10_CLK1_50),
        .c0(clk_25),
        .locked(pll_locked)
    );

    video_sync_generator u_sync (
        .reset(sync_reset),
        .vga_clk(clk_25),
        .blank_n(blank_n),
        .HS(VGA_HS),
        .VS(VGA_VS),
        .h_cnt(h_cnt),
        .v_cnt(v_cnt)
    );

    assign VGA_CLK     = clk_25;
    assign VGA_BLANK_N = blank_n;
    assign VGA_SYNC_N  = 1'b0;

    always @(posedge clk_25 or posedge sync_reset) begin
        if (sync_reset) begin
            game_tick_counter <= 19'd0;
            game_tick <= 1'b0;
        end else if (game_tick_counter == GAME_TICK_DIV - 1) begin
            game_tick_counter <= 19'd0;
            game_tick <= 1'b1;
        end else begin
            game_tick_counter <= game_tick_counter + 19'd1;
            game_tick <= 1'b0;
        end
    end

    // ===========================================
    // Core Game Modules
    // ===========================================

    bar_controller u_bar_controller (
        .clk        (clk_25),
        .rst        (sync_reset),
        .en         (1'b1), // Keep enabled
        .tick_60hz  (game_tick),
        .joy_left   (left_stick),
        .joy_right  (right_stick),
        .bar_left_y (bar_left_y),
        .bar_right_y(bar_right_y)
    );

    ball_physics u_ball_physics (
        .clk        (clk_25),
        .rst        (sync_reset),
        .tick_60hz  (game_tick),
        .init_ball  (1'b0),
        .en_physics (game_state != 3'd0),
        .bar_left_y (bar_left_y),
        .bar_right_y(bar_right_y),
        .ball_x     (ball_x),
        .ball_y     (ball_y)
    );

    collision_detect u_collision_detect (
        .clk_25      (clk_25),
        .rst         (sync_reset),
        .ball_x      (ball_x),
        .ball_y      (ball_y),
        .bar_left_y  (bar_left_y),
        .bar_right_y (bar_right_y),
        .hole_entered(hole_entered),
        .hole_id     (hole_id),
        .bottom_hit  (bottom_hit)
    );

    level_data u_level_data (
        .clk_25        (clk_25),
        .rst           (sync_reset),
        .level         (level),
        .target_hole_id(target_hole_id)
    );

    game_fsm u_game_fsm (
        .clk_25         (clk_25),
        .rst            (sync_reset),
        .start_btn      (start_btn),
        .play_again_btn (play_again_btn),
        .hole_entered   (hole_entered),
        .hole_id        (hole_id),
        .bottom_hit     (bottom_hit),
        .target_hole_id (target_hole_id),
        .game_state     (game_state),
        .level          (level),
        .score          (score),
        .balls_remaining(balls_remaining)
    );

    wire vga_r_out, vga_g_out, vga_b_out;

    vga_renderer u_vga_renderer (
        .clk            (clk_25),
        .rst            (sync_reset),
        .blank_n        (blank_n),
        .h_cnt          (h_cnt),
        .v_cnt          (v_cnt),
        .ball_x         (ball_x[9:2]),
        .ball_y         (ball_y[9:2]),
        .bar_left_y     (bar_left_y[9:2]),
        .bar_right_y    (bar_right_y[9:2]),
        .game_state     (game_state),
        .level          (level),
        .balls_remaining(balls_remaining),
        .score          (score),
        .target_hole_id (target_hole_id),
        .vga_r          (vga_r_out),
        .vga_g          (vga_g_out),
        .vga_b          (vga_b_out)
    );

    // Replicate 1-bit color to 4-bit VGA signals for max brightness
    assign VGA_R = {4{vga_r_out}};
    assign VGA_G = {4{vga_g_out}};
    assign VGA_B = {4{vga_b_out}};

    // Stub these buttons for now until UI screens are added
    assign start_btn = 1'b0;
    assign play_again_btn = 1'b0;

endmodule
