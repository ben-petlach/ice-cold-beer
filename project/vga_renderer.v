module vga_renderer (
    input  wire clk,
    input  wire rst,
    input  wire blank_n,
    input  wire [10:0] h_cnt,       // full timing counter 0-799; active pixels begin at h=144
    input  wire [9:0] v_cnt,        // full timing counter 0-524; active pixels begin at v=35
    input  wire [7:0] ball_x,       // ball center X in game coordinates, 0-159
    input  wire [6:0] ball_y,       // ball center Y in game coordinates, 0-119; not used directly for rendering
    input  wire [6:0] bar_left_y,   // bar height at the left wall, game X=39
    input  wire [6:0] bar_right_y,  // bar height at the right wall, game X=119
    input  wire [2:0] game_state,
    input  wire [3:0] level,
    input  wire [3:0] current_step,
    input  wire [2:0] balls_remaining,
    input  wire [15:0] score,
    input  wire [5:0] target_hole_id,
    output reg vga_r,
    output reg vga_g,
    output reg vga_b,
    output reg ball_gray  // when high, top entity overrides RGB to 4'h6 (gray) instead of full white
);

`include "hole_positions.vh"

// the renderer only checks for S_GAME_OVER; all other states render the game normally
localparam S_PLAYING    = 3'b001;
localparam S_GAME_OVER  = 3'b010;

// strip sync and porch offsets to get 0-based screen coordinates
// H offset is 160 rather than 144 to align the subtraction with the 160-game-pixel-wide grid
wire [9:0] screen_x = h_cnt[9:0] - 10'd160;
wire [9:0] screen_y = v_cnt - 10'd35;

// divide by 4: each game pixel covers a 4x4 block of screen pixels, giving a 160x120 game grid
wire [7:0] game_x = screen_x[9:2];
wire [6:0] game_y = screen_y[8:2];

// linear interpolation of bar height at the current pixel X
// dividing by 80 (the bar span) is approximated as multiplying by 205 then right-shifting by 14
// because 205/16384 = 0.01251 ≈ 1/80 = 0.01250
wire signed [7:0] bar_slope = $signed({1'b0, bar_right_y}) - $signed({1'b0, bar_left_y});
wire [6:0] bar_offset = game_x[6:0] - 7'd39;

wire signed [31:0] raw_offset = bar_slope * $signed({1'b0, bar_offset}) * 32'sd205;
wire signed [15:0] y_offset = (raw_offset + 32'sd8192) >>> 14; // +8192 rounds instead of truncating
wire signed [15:0] surface_y = $signed({1'b0, bar_left_y}) + y_offset;
wire [6:0] bar_y_here = surface_y[6:0];

// the ball draw position is not taken from ball_y; instead it is computed by finding the bar
// surface height at the ball's X, then offsetting upward so the ball sits on top of the rod
wire [7:0] draw_ball_x = ball_x;
wire signed [8:0] ball_bar_offset = $signed({1'b0, draw_ball_x}) - 9'sd39;
wire signed [31:0] ball_raw_offset = bar_slope * ball_bar_offset * 32'sd205;
wire signed [15:0] ball_y_offset = (ball_raw_offset + 32'sd8192) >>> 14;
wire signed [15:0] ball_surface_y = $signed({1'b0, bar_left_y}) + ball_y_offset;
wire [6:0] draw_ball_y = ball_surface_y[6:0] - 7'd3; // center the 7-pixel sprite 3 rows above the bar surface

// each row of the 7x7 sprite is a 7-bit bitmask; bit 6 is the leftmost pixel, bit 0 is the rightmost
wire [7:0] ball_spr_x0 = draw_ball_x - 8'd3;
wire [6:0] ball_spr_y0 = draw_ball_y - 7'd3;
wire in_ball_spr = (game_x >= ball_spr_x0) && (game_x <= ball_spr_x0 + 8'd6) &&
                          (game_y >= ball_spr_y0) && (game_y <= ball_spr_y0 + 7'd6);
wire [2:0] ball_spr_col = game_x[2:0] - ball_spr_x0[2:0];
wire [2:0] ball_spr_row = game_y[2:0] - ball_spr_y0[2:0];

reg [6:0] ball_spr_body;
always @(*) case (ball_spr_row)
    3'd0: ball_spr_body = 7'b0011100;
    3'd1: ball_spr_body = 7'b0111110;
    3'd2: ball_spr_body = 7'b1111111;
    3'd3: ball_spr_body = 7'b1111111;
    3'd4: ball_spr_body = 7'b1111111;
    3'd5: ball_spr_body = 7'b0111110;
    3'd6: ball_spr_body = 7'b0011100;
    default: ball_spr_body = 7'b0000000;
endcase
wire ball_spr_px = in_ball_spr && ball_spr_body[3'd6 - ball_spr_col];

// two-pixel specular highlight in the upper-right of the sprite to give the ball a 3D appearance
// highlight pixels are rendered white while the rest of the body is rendered gray via ball_gray
reg [6:0] ball_spr_hi_row;
always @(*) case (ball_spr_row)
    3'd1: ball_spr_hi_row = 7'b0000100;
    3'd2: ball_spr_hi_row = 7'b0000010;
    default: ball_spr_hi_row = 7'b0000000;
endcase
wire ball_spr_hi_px = in_ball_spr && ball_spr_hi_row[3'd6 - ball_spr_col];

// 37 holes are generated in parallel; each produces one bit in hole_active, hole_border, etc.
// OR-reduction at the end collapses all 37 bits into a single flag for the priority mux
wire [36:0] hole_active;
wire [36:0] hole_border;
wire [36:0] hole_is_target;
wire [36:0] ball_in_center;

genvar i;
generate
    for (i = 0; i < 37; i = i + 1) begin : hole_render
        wire [7:0] hsx = {1'b0, HOLE_X[i]};
        wire [6:0] hsy = HOLE_Y[i];
        wire [2:0] dx = game_x[2:0] - hsx[2:0];
        wire [2:0] dy = game_y[2:0] - hsy[2:0];
        wire in_bounds = (game_x >= hsx) && (game_x < hsx + 8'd8) &&
                             (game_y >= hsy) && (game_y < hsy + 7'd8);
        // clip the four corners of the 8x8 tile using Manhattan distance to give a rounded look
        wire corner        = (({1'b0, dx} + {1'b0, dy}) < 4'd2) ||
                             (({1'b0, dx} + {1'b0, 3'd7 - dy}) < 4'd2) ||
                             (({1'b0, 3'd7 - dx} + {1'b0, dy}) < 4'd2) ||
                             (({1'b0, 3'd7 - dx} + {1'b0, 3'd7 - dy}) < 4'd2);
        assign hole_active[i] = in_bounds && !corner;
        assign hole_border[i] = hole_active[i] &&
                                   (dx == 3'd0 || dx == 3'd7 ||
                                    dy == 3'd0 || dy == 3'd7 ||
                                    (dx == 3'd1 && dy == 3'd1) ||
                                    (dx == 3'd6 && dy == 3'd1) ||
                                    (dx == 3'd1 && dy == 3'd6) ||
                                    (dx == 3'd6 && dy == 3'd6));
        assign hole_is_target[i] = hole_active[i] && (i[5:0] == target_hole_id);
        // ball is considered inside the hole when its draw position falls within the inner 4x4 zone, corners excluded
        assign ball_in_center[i] =
            (draw_ball_x >= {1'b0, HOLE_X[i]} + 8'd2) && (draw_ball_x <= {1'b0, HOLE_X[i]} + 8'd5) &&
            (draw_ball_y >= HOLE_Y[i] + 7'd2) && (draw_ball_y <= HOLE_Y[i] + 7'd5) &&
            !((draw_ball_x == {1'b0, HOLE_X[i]} + 8'd2 || draw_ball_x == {1'b0, HOLE_X[i]} + 8'd5) &&
            (draw_ball_y == HOLE_Y[i] + 7'd2 || draw_ball_y == HOLE_Y[i] + 7'd5));
    end
endgenerate

wire any_hole = |hole_active;
wire any_border = |hole_border;
wire target_border = |(hole_border & hole_is_target);
wire ball_in_hole_border = |(hole_border & ball_in_center);

// 160x120 monochrome background bitmap stored in LUTs rather than block RAM (ramstyle=logic)
// to avoid the 1-cycle read latency of M9K that would misalign the pixel output with the sync signals
(* ramstyle = "logic" *) reg [159:0] bg_rows [0:119];
initial $readmemh("ice_cold_beer_mono.hex", bg_rows);

wire [159:0] bg_row_cur = bg_rows[game_y];
wire bg_pixel = bg_row_cur[game_x];

// HUD occupies game_x 120-159; contains round number, step number, and ball life indicators

// round number displayed as level+1 so the player sees rounds 1-4 instead of 0-3
wire [3:0] hud_round_val = {2'b0, level[1:0]} + 4'd1;
wire [14:0] hud_round_bmp;
number_driver nd_round (.digit(hud_round_val), .bitmap(hud_round_bmp));
wire hud_in_round = (game_x >= 8'd149) && (game_x <= 8'd151) &&
                              (game_y >= 7'd1) && (game_y <= 7'd5);
wire [6:0] hud_round_cy = game_y - 7'd1;
wire [7:0] hud_round_cx = game_x - 8'd149;
wire [3:0] hud_round_idx = {1'b0, hud_round_cy[2:0]} * 4'd3 + {2'b0, hud_round_cx[1:0]};
wire hud_round_px = hud_in_round && hud_round_bmp[hud_round_idx];

// current hole step within the level, shown as a single digit
wire [14:0] hud_lvl_ones_bmp;
number_driver nd_lvl_ones (.digit(current_step), .bitmap(hud_lvl_ones_bmp));
wire hud_in_lvl_ones = (game_x >= 8'd140) && (game_x <= 8'd142) &&
                              (game_y >= 7'd8) && (game_y <= 7'd12);
wire [6:0] hud_lvl_ones_cy = game_y - 7'd8;
wire [7:0] hud_lvl_ones_cx = game_x - 8'd140;
wire [3:0] hud_lvl_ones_idx = {1'b0, hud_lvl_ones_cy[2:0]} * 4'd3 + {2'b0, hud_lvl_ones_cx[1:0]};
wire hud_lvl_ones_px = hud_in_lvl_ones && hud_lvl_ones_bmp[hud_lvl_ones_idx];

// tens digit is reserved but unused; step count never exceeds 9
wire hud_in_lvl_tens = 1'b0;
wire hud_lvl_tens_px = 1'b0;

// 5 life indicator balls in the HUD; b0-b3 are in a row, b4 is below b0
// each indicator is filled when balls_remaining exceeds its threshold, otherwise shown as a hollow ring
wire hud_in_b0 = (game_x>=8'd122)&&(game_x<=8'd128)&&(game_y>=7'd23)&&(game_y<=7'd29);
wire hud_in_b1 = (game_x>=8'd130)&&(game_x<=8'd136)&&(game_y>=7'd23)&&(game_y<=7'd29);
wire hud_in_b2 = (game_x>=8'd138)&&(game_x<=8'd144)&&(game_y>=7'd23)&&(game_y<=7'd29);
wire hud_in_b3 = (game_x>=8'd146)&&(game_x<=8'd152)&&(game_y>=7'd23)&&(game_y<=7'd29);
wire hud_in_b4 = (game_x>=8'd122)&&(game_x<=8'd128)&&(game_y>=7'd31)&&(game_y<=7'd37);
wire hud_in_any_ball = hud_in_b0|hud_in_b1|hud_in_b2|hud_in_b3|hud_in_b4;

// local pixel coordinates within whichever indicator ball contains the current pixel
wire [7:0] hud_bdx = hud_in_b0 ? (game_x - 8'd122) :
                     hud_in_b1 ? (game_x - 8'd130) :
                     hud_in_b2 ? (game_x - 8'd138) :
                     hud_in_b3 ? (game_x - 8'd146) :
                                 (game_x - 8'd122);
wire [6:0] hud_bdy = (hud_in_b4) ? (game_y - 7'd31) : (game_y - 7'd23);

// filled indicator: solid 7x7 circle, same shape as the main ball sprite
reg [6:0] hud_ball_filled_row;
always @(*) case (hud_bdy)
    7'd0: hud_ball_filled_row = 7'b0011100;
    7'd1: hud_ball_filled_row = 7'b0111110;
    7'd2: hud_ball_filled_row = 7'b1111111;
    7'd3: hud_ball_filled_row = 7'b1111111;
    7'd4: hud_ball_filled_row = 7'b1111111;
    7'd5: hud_ball_filled_row = 7'b0111110;
    7'd6: hud_ball_filled_row = 7'b0011100;
    default: hud_ball_filled_row = 7'b0000000;
endcase

// hollow indicator: only the outer ring of pixels is set, interior is black
reg [6:0] hud_ball_hollow_row;
always @(*) case (hud_bdy)
    7'd0: hud_ball_hollow_row = 7'b0011100;
    7'd1: hud_ball_hollow_row = 7'b0100010;
    7'd2: hud_ball_hollow_row = 7'b1000001;
    7'd3: hud_ball_hollow_row = 7'b1000001;
    7'd4: hud_ball_hollow_row = 7'b1000001;
    7'd5: hud_ball_hollow_row = 7'b0100010;
    7'd6: hud_ball_hollow_row = 7'b0011100;
    default: hud_ball_hollow_row = 7'b0000000;
endcase

// the ball currently in play is not represented here; indicators show only future balls
wire hud_b0_fill = (balls_remaining >= 3'd2);
wire hud_b1_fill = (balls_remaining >= 3'd3);
wire hud_b2_fill = (balls_remaining >= 3'd4);
wire hud_b3_fill = (balls_remaining >= 3'd5);
wire hud_b4_fill = (balls_remaining >= 3'd6);

wire hud_cur_ball_fill = (hud_in_b0 & hud_b0_fill) | (hud_in_b1 & hud_b1_fill) |
                         (hud_in_b2 & hud_b2_fill) | (hud_in_b3 & hud_b3_fill) |
                         (hud_in_b4 & hud_b4_fill);

wire [6:0] hud_ball_row = hud_cur_ball_fill ? hud_ball_filled_row : hud_ball_hollow_row;
wire hud_ball_px = hud_ball_row[3'd6 - hud_bdx[2:0]];

// two-pixel specular highlight matching the main ball sprite; only applied to filled indicators
wire hud_ball_hi_px = hud_cur_ball_fill && hud_ball_px &&
                      ((hud_bdx == 8'd4 && hud_bdy == 7'd1) ||
                       (hud_bdx == 8'd5 && hud_bdy == 7'd2));

// combinational priority mux: the first matching condition wins; all others are skipped
// outputs are written to intermediates and registered on the clock edge below
reg r_next, g_next, b_next, ball_gray_next;

always @(*) begin
    // default to black so unmatched pixels (hole interiors, empty HUD space) stay dark
    r_next = 1'b0;
    g_next = 1'b0;
    b_next = 1'b0;
    ball_gray_next = 1'b0;

    if (!blank_n) begin
        r_next = 1'b0; g_next = 1'b0; b_next = 1'b0;

    end else if (game_state == S_GAME_OVER) begin
        // entire screen turns red when the game ends
        r_next = 1'b1; g_next = 1'b0; b_next = 1'b0;

    end else begin

        if (game_x == 8'd39 || game_x == 8'd119) begin
            // left and right boundary walls
            r_next = 1'b1; g_next = 1'b1; b_next = 1'b1;

        end else if ((game_x >= 8'd39) && (game_x <= 8'd119) &&
                     (game_y >= bar_y_here) && (game_y < bar_y_here + 7'd1)) begin
            // bar rod, 1 pixel tall at the interpolated height for this X
            r_next = 1'b1; g_next = 1'b1; b_next = 1'b1;

        end else if ((balls_remaining > 3'b0) && ball_spr_px) begin
            // ball body is gray; the two highlight pixels are white; ball_gray drives the distinction
            r_next = 1'b1; g_next = 1'b1; b_next = 1'b1;
            ball_gray_next = !ball_spr_hi_px;

        end else if (any_hole) begin
            // hole color depends on whether the ball is entering and whether this is the target hole
            if (ball_in_hole_border) begin
                // ball center is overlapping this hole's border, indicating the ball is entering
                r_next = 1'b1; g_next = 1'b0; b_next = 1'b0;
            end else if (target_border) begin
                // this hole is the current target; highlight its border in yellow
                r_next = 1'b1; g_next = 1'b1; b_next = 1'b0;
            end else if (any_border) begin
                // non-target hole border
                r_next = 1'b1; g_next = 1'b1; b_next = 1'b1;
            end
            // hole interior stays black (default)

        end else if (hud_in_round) begin
            // round number digit
            r_next = hud_round_px; g_next = hud_round_px; b_next = hud_round_px;

        end else if (hud_in_lvl_tens) begin
            // step tens digit (unused)
            r_next = hud_lvl_tens_px; g_next = hud_lvl_tens_px; b_next = hud_lvl_tens_px;

        end else if (hud_in_lvl_ones) begin
            // step ones digit
            r_next = hud_lvl_ones_px; g_next = hud_lvl_ones_px; b_next = hud_lvl_ones_px;

        end else if (hud_in_any_ball) begin
            // life indicator: filled solid circle with highlight, or hollow ring
            r_next = hud_ball_px; g_next = hud_ball_px; b_next = hud_ball_px;
            ball_gray_next = hud_cur_ball_fill && hud_ball_px && !hud_ball_hi_px;

        end else if (bg_pixel) begin
            // background artwork from the hex bitmap
            r_next = 1'b1; g_next = 1'b1; b_next = 1'b1;
        end
    end
end

// register outputs to prevent combinational glitches from reaching the VGA pins
always @(posedge clk) begin
    if (rst) begin
        vga_r <= 1'b0;
        vga_g <= 1'b0;
        vga_b <= 1'b0;
        ball_gray <= 1'b0;
    end else begin
        vga_r <= r_next;
        vga_g <= g_next;
        vga_b <= b_next;
        ball_gray <= ball_gray_next;
    end
end

endmodule
