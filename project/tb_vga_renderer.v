`timescale 1ns/1ps

// =============================================================================
// tb_vga_renderer.v  –  Self-contained testbench for vga_renderer.v
//
// 19 test cases covering every rendering layer.
// Run with Quartus ModelSim-Altera:
//   Compile: vlog -sv vga_renderer.v tb_vga_renderer.v
//   Simulate: vsim -c tb_vga_renderer -do "run -all"
//
// Run with Icarus Verilog:
//   iverilog -g2012 -o tb_vga_renderer tb_vga_renderer.v vga_renderer.v
//   vvp tb_vga_renderer
// =============================================================================

module tb_vga_renderer;

// ---------------------------------------------------------------------------
// DUT signals
// ---------------------------------------------------------------------------
reg         clk;
reg         rst;
reg         blank_n;
reg  [10:0] h_cnt;
reg  [9:0]  v_cnt;
reg  [7:0]  ball_x;
reg  [6:0]  ball_y;
reg  [6:0]  bar_left_y;
reg  [6:0]  bar_right_y;
reg  [2:0]  game_state;
reg  [3:0]  level;
reg  [2:0]  balls_remaining;
reg  [15:0] score;
reg  [5:0]  target_hole_id;
wire        vga_r, vga_g, vga_b;

// ---------------------------------------------------------------------------
// DUT instantiation
// ---------------------------------------------------------------------------
vga_renderer dut (
    .clk            (clk),
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
// 50 MHz clock (20 ns period)
// ---------------------------------------------------------------------------
initial clk = 0;
always #10 clk = ~clk;

// ---------------------------------------------------------------------------
// Test counters
// ---------------------------------------------------------------------------
integer pass_count;
integer fail_count;

// ---------------------------------------------------------------------------
// task: check_pixel
//   Drives h_cnt/v_cnt to game coordinate (gx, gy), waits one posedge so
//   the registered output captures the new combinational value, then
//   compares vga_r/g/b against expected values.
//
// Coordinate mapping (from vga_renderer.v):
//   h_cnt = gx*4 + 144   (H active region starts at H_SYNC + H_BACK = 144)
//   v_cnt = gy*4 + 35    (V active region starts at V_SYNC + V_BACK  =  35)
// ---------------------------------------------------------------------------
task check_pixel;
    input [7:0]   gx;
    input [6:0]   gy;
    input         exp_r, exp_g, exp_b;
    input [127:0] label;
    begin
        h_cnt = gx * 4 + 144;
        v_cnt = gy * 4 + 35;
        @(posedge clk);
        #1; // let non-blocking assignments settle past the clock edge
        if (vga_r === exp_r && vga_g === exp_g && vga_b === exp_b) begin
            $display("PASS [%s]  r=%b g=%b b=%b", label, vga_r, vga_g, vga_b);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [%s]  got r=%b g=%b b=%b  exp r=%b g=%b b=%b",
                     label, vga_r, vga_g, vga_b, exp_r, exp_g, exp_b);
            fail_count = fail_count + 1;
        end
    end
endtask

// ---------------------------------------------------------------------------
// Main test sequence
// ---------------------------------------------------------------------------
initial begin
    // Optional waveform dump (GTKWave / ModelSim VCD export)
    $dumpfile("tb_vga_renderer.vcd");
    $dumpvars(0, tb_vga_renderer);

    pass_count = 0;
    fail_count = 0;

    // --- Default inputs ---
    // game_state = S_PLAYING so the playfield is active by default.
    // bar at y=80, well below the pixels under test, so it won't interfere.
    rst             = 1;
    blank_n         = 1;
    h_cnt           = 11'd144;
    v_cnt           = 10'd35;
    ball_x          = 8'd79;
    ball_y          = 7'd60;
    bar_left_y      = 7'd80;
    bar_right_y     = 7'd80;
    game_state      = 3'b001;   // S_PLAYING
    level           = 4'd0;
    balls_remaining = 3'd3;
    score           = 16'd0;
    target_hole_id  = 6'd1;     // hole 1 is target; hole 0 is normal

    // 2-cycle synchronous reset
    @(posedge clk);
    @(posedge clk);
    rst = 0;
    @(posedge clk); // one extra cycle to settle out of reset

    // -----------------------------------------------------------------------
    // T01  Blanking interval — outputs must be 0 regardless of game coords
    // -----------------------------------------------------------------------
    blank_n = 0;
    check_pixel(8'd79, 7'd60, 1'b0, 1'b0, 1'b0, "T01 blanking        ");
    blank_n = 1;

    // -----------------------------------------------------------------------
    // T02  Start menu (game_state=000) — full screen dark blue (r=0,g=0,b=1)
    // -----------------------------------------------------------------------
    game_state = 3'b000;
    check_pixel(8'd79, 7'd60, 1'b0, 1'b0, 1'b1, "T02 start_menu      ");

    // -----------------------------------------------------------------------
    // T03  Game over (game_state=010) — full screen dark red (r=1,g=0,b=0)
    // -----------------------------------------------------------------------
    game_state = 3'b010;
    check_pixel(8'd79, 7'd60, 1'b1, 1'b0, 1'b0, "T03 game_over       ");

    // Restore PLAYING for all remaining tests
    game_state = 3'b001;

    // -----------------------------------------------------------------------
    // T04  Left wall — game_x=39 must render white
    // -----------------------------------------------------------------------
    check_pixel(8'd39, 7'd60, 1'b1, 1'b1, 1'b1, "T04 left_wall       ");

    // -----------------------------------------------------------------------
    // T05  Right wall — game_x=119 must render white
    // -----------------------------------------------------------------------
    check_pixel(8'd119, 7'd60, 1'b1, 1'b1, 1'b1, "T05 right_wall      ");

    // -----------------------------------------------------------------------
    // T06  Ball center — ball at (79,60), checking same game pixel
    //   bdx=0, bdy=0 → dist²=0 ≤ 2 → in_ball
    //   bar pushed to y=80 so it does not overlap
    // -----------------------------------------------------------------------
    ball_x = 8'd79; ball_y = 7'd60;
    balls_remaining = 3'd3;
    bar_left_y = 7'd80; bar_right_y = 7'd80;
    check_pixel(8'd79, 7'd60, 1'b1, 1'b1, 1'b1, "T06 ball_center     ");

    // -----------------------------------------------------------------------
    // T07  Ball diamond neighbour — game_x=80, game_y=60
    //   bdx=1, bdy=0 → dist²=1 ≤ 2 → in_ball
    // -----------------------------------------------------------------------
    check_pixel(8'd80, 7'd60, 1'b1, 1'b1, 1'b1, "T07 ball_neighbor   ");

    // -----------------------------------------------------------------------
    // T08  Ball just outside diamond — game_x=81, game_y=61
    //   bdx=2, bdy=1 → dist²=5 > 2 → not in_ball → black
    //   bar at y=80, game_y=61 < 80 → bar does not render
    // -----------------------------------------------------------------------
    check_pixel(8'd81, 7'd61, 1'b0, 1'b0, 1'b0, "T08 ball_outside    ");

    // -----------------------------------------------------------------------
    // T09  Flat bar midpoint — bar_left_y=bar_right_y=60, game_x=79, game_y=60
    //   bar_y_here = 60; game_y=60 ≥ 60 and < 61 → bar renders white
    //   ball hidden (balls_remaining=0) to avoid interference
    // -----------------------------------------------------------------------
    bar_left_y = 7'd60; bar_right_y = 7'd60;
    ball_x     = 8'd0;  ball_y = 7'd0;  // move ball away from test pixel
    balls_remaining = 3'd0;
    check_pixel(8'd79, 7'd60, 1'b1, 1'b1, 1'b1, "T09 flat_bar        ");

    // -----------------------------------------------------------------------
    // T10  Just above flat bar — game_y=59 < bar_y_here=60 → no bar → black
    // -----------------------------------------------------------------------
    check_pixel(8'd79, 7'd59, 1'b0, 1'b0, 1'b0, "T10 above_bar       ");

    // -----------------------------------------------------------------------
    // T11  Tilted bar left end — bar_left_y=50, bar_right_y=70, game_x=39
    //   bar_y_here at x=39 = 50; game_y=50 matches.
    //   game_x=39 is also the left wall, so priority gives white (correct).
    // -----------------------------------------------------------------------
    bar_left_y = 7'd50; bar_right_y = 7'd70;
    check_pixel(8'd39, 7'd50, 1'b1, 1'b1, 1'b1, "T11 bar_left_end    ");

    // -----------------------------------------------------------------------
    // T12  Tilted bar right end — game_x=119, game_y=70
    //   bar_y_here at x=119 = 70; game_y=70 matches.
    //   game_x=119 is also the right wall → white (correct).
    // -----------------------------------------------------------------------
    check_pixel(8'd119, 7'd70, 1'b1, 1'b1, 1'b1, "T12 bar_right_end   ");

    // Restore bar out of the way
    bar_left_y = 7'd80; bar_right_y = 7'd80;

    // -----------------------------------------------------------------------
    // T13  Normal hole border
    //   Hole 0: HOLE_X[0]=52, HOLE_Y[0]=7 (8×8 tile)
    //   game_x=55, game_y=7  →  dx=3, dy=0 (top border, no corner cut)
    //   target_hole_id=1 → hole 0 is non-target → white border
    // -----------------------------------------------------------------------
    target_hole_id = 6'd1;
    check_pixel(8'd55, 7'd7, 1'b1, 1'b1, 1'b1, "T13 normal_border   ");

    // -----------------------------------------------------------------------
    // T14  Target hole border — same pixel, target_hole_id=0 → yellow (r=1,g=1,b=0)
    // -----------------------------------------------------------------------
    target_hole_id = 6'd0;
    check_pixel(8'd55, 7'd7, 1'b1, 1'b1, 1'b0, "T14 target_border   ");

    // -----------------------------------------------------------------------
    // T15  Hole interior — hole 0, game_x=55, game_y=10  (dx=3, dy=3)
    //   Not a border pixel (dx≠0,7; dy≠0,7) → black interior
    // -----------------------------------------------------------------------
    target_hole_id = 6'd1;
    check_pixel(8'd55, 7'd10, 1'b0, 1'b0, 1'b0, "T15 hole_interior   ");

    // -----------------------------------------------------------------------
    // T16  Hole corner cut — hole 0, game_x=52, game_y=7  (dx=0, dy=0)
    //   dx+dy=0 < 2 → corner=1 → hole_active=0 → pixel is invisible (black)
    // -----------------------------------------------------------------------
    check_pixel(8'd52, 7'd7, 1'b0, 1'b0, 1'b0, "T16 hole_corner_cut ");

    // -----------------------------------------------------------------------
    // T17  HUD strip — game_y=2 < 5 → green (r=0,g=1,b=0)
    //   game_x=70 is not a wall; no hole overlaps this pixel;
    //   bar at y=80 does not reach y=2; balls_remaining=0 (no ball)
    // -----------------------------------------------------------------------
    check_pixel(8'd70, 7'd2, 1'b0, 1'b1, 1'b0, "T17 hud_strip       ");

    // -----------------------------------------------------------------------
    // T18  Below HUD, open field — game_x=70, game_y=20, no objects → black
    //   game_y=20 ≥ 5 (not HUD); no wall; no hole (nearest hole at x=70
    //   is HOLE_X[9]=70, HOLE_Y[9]=24 — game_y=20 < 24, not in range);
    //   bar at y=80 > 20; balls_remaining=0
    // -----------------------------------------------------------------------
    check_pixel(8'd70, 7'd20, 1'b0, 1'b0, 1'b0, "T18 open_field      ");

    // -----------------------------------------------------------------------
    // T19  balls_remaining=0 hides ball — ball geometry still at center but
    //   the guard `balls_remaining > 0` suppresses rendering → black
    // -----------------------------------------------------------------------
    balls_remaining = 3'd0;
    ball_x = 8'd79; ball_y = 7'd60;
    bar_left_y = 7'd80; bar_right_y = 7'd80;
    check_pixel(8'd79, 7'd60, 1'b0, 1'b0, 1'b0, "T19 no_balls_hidden ");

    // -----------------------------------------------------------------------
    // Summary
    // -----------------------------------------------------------------------
    $display("--------------------------------------------------");
    $display("Results: %0d PASS, %0d FAIL  (total %0d)",
             pass_count, fail_count, pass_count + fail_count);
    $display("--------------------------------------------------");
    $finish;
end

endmodule
