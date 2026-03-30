module vga_renderer (
    input  wire        clk,
    input  wire        rst,
    input  wire        blank_n,
    input  wire [10:0] h_cnt,        // 0-799 (active: 144-783 -> screen X 0-639)
    input  wire [9:0]  v_cnt,        // 0-524 (active: 35-514  -> screen Y 0-479)
    input  wire [7:0]  ball_x,       // game coords (0-159), center
    input  wire [6:0]  ball_y,       // game coords (0-119), center
    input  wire [6:0]  bar_left_y,   // game Y at left wall  (game X=39)
    input  wire [6:0]  bar_right_y,  // game Y at right wall (game X=119)
    input  wire [2:0]  game_state,
    input  wire [3:0]  level,
    input  wire [3:0]  current_step,
    input  wire [2:0]  balls_remaining,
    input  wire [15:0] score,
    input  wire [5:0]  target_hole_id,
    output reg         vga_r,
    output reg         vga_g,
    output reg         vga_b,
    output reg         ball_gray   // 1 = render this pixel at ~38% brightness (gray body)
);

`include "hole_positions.vh"

// Game state encoding
localparam S_PLAYING    = 3'b001;
localparam S_GAME_OVER  = 3'b010;

// Screen coordinate conversion (VGA hardware signals — unchanged)
// H: h_cnt active region starts at H_SYNC_PULSE + H_BACK_PORCH = 96+48 = 144
// V: v_cnt active region starts at V_SYNC_PULSE + V_BACK_PORCH =  2+33 = 35
wire [9:0] screen_x = h_cnt[9:0] - 10'd160;
wire [9:0] screen_y = v_cnt      - 10'd35;

// Game coordinate conversion (convert once here; all logic below uses game coords)
wire [7:0] game_x = screen_x[9:2];  // 0-159  (>>2 = /4)
wire [6:0] game_y = screen_y[8:2];  // 0-119  (>>2 = /4)

// ---------------------------------------------------------------------------
// Bar interpolation (game space)
// Bar spans game_x 39-119 (width=80). Divide by 80 using * 205 >> 14 multiplier.
// ---------------------------------------------------------------------------
wire signed [7:0]  bar_slope  = $signed({1'b0, bar_right_y}) - $signed({1'b0, bar_left_y});
wire        [6:0]  bar_offset = game_x[6:0] - 7'd39;          // 0-80 when in bar X range

wire signed [31:0] raw_offset = bar_slope * $signed({1'b0, bar_offset}) * 32'sd205;
wire signed [15:0] y_offset   = (raw_offset + 32'sd8192) >>> 14;
wire signed [15:0] surface_y  = $signed({1'b0, bar_left_y}) + y_offset;
wire        [6:0]  bar_y_here = surface_y[6:0];

// ---------------------------------------------------------------------------
// Ball circle test (game space)
// r²=2 → 3×3 diamond (orthogonal neighbours + center); each game px = 4×4 screen px
// ---------------------------------------------------------------------------
wire [7:0] draw_ball_x = ball_x; // driven by ball_physics
wire signed [8:0] ball_bar_offset = $signed({1'b0, draw_ball_x}) - 9'sd39;
wire signed [31:0] ball_raw_offset = bar_slope * ball_bar_offset * 32'sd205;
wire signed [15:0] ball_y_offset   = (ball_raw_offset + 32'sd8192) >>> 14;
wire signed [15:0] ball_surface_y  = $signed({1'b0, bar_left_y}) + ball_y_offset;
wire [6:0] draw_ball_y = ball_surface_y[6:0] - 7'd3; // center: 3 rows above bar surface

// Sprite test — 7×7 game pixels, centered at (draw_ball_x, draw_ball_y)
// ball.png: black=transparent, gray/white=ball body
wire [7:0] ball_spr_x0  = draw_ball_x - 8'd3;
wire [6:0] ball_spr_y0  = draw_ball_y - 7'd3;
wire       in_ball_spr  = (game_x >= ball_spr_x0) && (game_x <= ball_spr_x0 + 8'd6) &&
                          (game_y >= ball_spr_y0) && (game_y <= ball_spr_y0 + 7'd6);
wire [2:0] ball_spr_col = game_x[2:0] - ball_spr_x0[2:0];   // 0-6 when in_ball_spr
wire [2:0] ball_spr_row = game_y[2:0] - ball_spr_y0[2:0];   // 0-6 when in_ball_spr

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

// Highlight pixels from ball.png: sprite (col=4,row=1) and (col=5,row=2)
reg [6:0] ball_spr_hi_row;
always @(*) case (ball_spr_row)
    3'd1:    ball_spr_hi_row = 7'b0000100;
    3'd2:    ball_spr_hi_row = 7'b0000010;
    default: ball_spr_hi_row = 7'b0000000;
endcase
wire ball_spr_hi_px = in_ball_spr && ball_spr_hi_row[3'd6 - ball_spr_col];

// ---------------------------------------------------------------------------
// Hole rendering (game space) — generate per-hole wires, OR-reduced outside
// Hole tiles are 8×8 game pixels; 3-pixel diagonal corner cut per corner.
// ---------------------------------------------------------------------------
wire [36:0] hole_active;
wire [36:0] hole_border;
wire [36:0] hole_is_target;
wire [36:0] ball_in_center;

genvar i;
generate
    for (i = 0; i < 37; i = i + 1) begin : hole_render
        wire [7:0] hsx     = {1'b0, HOLE_X[i]};       // game coords (zero-extended to 8 bits)
        wire [6:0] hsy     = HOLE_Y[i];
        wire [2:0] dx      = game_x[2:0] - hsx[2:0];  // 0-7 within tile (valid when in_bounds)
        wire [2:0] dy      = game_y[2:0] - hsy[2:0];
        wire in_bounds     = (game_x >= hsx)           && (game_x < hsx + 8'd8) &&
                             (game_y >= hsy)           && (game_y < hsy + 7'd8);
        // Diagonal corner cut: 3 game pixels per corner (as specified in hole_positions.vh)
        wire corner        = (({1'b0, dx} + {1'b0, dy})              < 4'd2) ||
                             (({1'b0, dx} + {1'b0, 3'd7 - dy})        < 4'd2) ||
                             (({1'b0, 3'd7 - dx} + {1'b0, dy})        < 4'd2) ||
                             (({1'b0, 3'd7 - dx} + {1'b0, 3'd7 - dy}) < 4'd2);
        assign hole_active[i]    = in_bounds && !corner;
        assign hole_border[i]    = hole_active[i] &&
                                   (dx == 3'd0 || dx == 3'd7 ||
                                    dy == 3'd0 || dy == 3'd7 ||
                                    (dx == 3'd1 && dy == 3'd1) ||
                                    (dx == 3'd6 && dy == 3'd1) ||
                                    (dx == 3'd1 && dy == 3'd6) ||
                                    (dx == 3'd6 && dy == 3'd6));
        assign hole_is_target[i] = hole_active[i] && (i[5:0] == target_hole_id);
        // Ball centre in 4×4 minus corners: dx=[2..5], dy=[2..5], excluding (2,2)(2,5)(5,2)(5,5)
        assign ball_in_center[i] =
            (draw_ball_x >= {1'b0, HOLE_X[i]} + 8'd2) && (draw_ball_x <= {1'b0, HOLE_X[i]} + 8'd5) &&
            (draw_ball_y >= HOLE_Y[i] + 7'd2)          && (draw_ball_y <= HOLE_Y[i] + 7'd5) &&
            !(  (draw_ball_x == {1'b0, HOLE_X[i]} + 8'd2 || draw_ball_x == {1'b0, HOLE_X[i]} + 8'd5) &&
                (draw_ball_y == HOLE_Y[i] + 7'd2         || draw_ball_y == HOLE_Y[i] + 7'd5)  );
    end
endgenerate

wire any_hole           = |hole_active;
wire any_border         = |hole_border;
wire target_border      = |(hole_border & hole_is_target);
wire ball_in_hole_border = |(hole_border & ball_in_center);

// ---------------------------------------------------------------------------
// Background ROM — "ice-cold-beer-monochrome"
// 160 wide x 120 tall, 1 bit per game pixel, stored row-major.
// Each row is a 160-bit word; pixel at game_x is bit[game_x] (LSB = x=0).
// ramstyle "logic" forces LUT-based ROM (combinational read, no pipeline
// stage) because MAX 10 M9K blocks only support registered reads.
// Resource cost: ~1200 LEs (~2.4% of 10M50).
// File "ice_cold_beer_mono.hex" must be in the Quartus project directory.
// ---------------------------------------------------------------------------
(* ramstyle = "logic" *) reg [159:0] bg_rows [0:119];
initial $readmemh("ice_cold_beer_mono.hex", bg_rows);

wire [159:0] bg_row_cur = bg_rows[game_y];
wire         bg_pixel   = bg_row_cur[game_x];

// ---------------------------------------------------------------------------
// HUD — right panel overlays (game_x 120-159)
// All digits use number_driver's 3×5 font.
// ---------------------------------------------------------------------------

// --- ROUND digit (level+1, 1-4) at game (149, 1) ---
wire [3:0]  hud_round_val = {2'b0, level[1:0]} + 4'd1;
wire [14:0] hud_round_bmp;
number_driver nd_round (.digit(hud_round_val), .bitmap(hud_round_bmp));
wire        hud_in_round    = (game_x >= 8'd149) && (game_x <= 8'd151) &&
                              (game_y >= 7'd1)   && (game_y <= 7'd5);
wire [6:0]  hud_round_cy    = game_y - 7'd1;
wire [7:0]  hud_round_cx    = game_x - 8'd149;
wire [3:0]  hud_round_row   = 4'd4 - {1'b0, hud_round_cy[2:0]};
wire [3:0]  hud_round_col   = 4'd2 - {2'b0, hud_round_cx[1:0]};
wire [3:0]  hud_round_idx   = hud_round_row * 3 + hud_round_col;
wire        hud_round_px    = hud_in_round && hud_round_bmp[hud_round_idx];

// --- LVL digit at game (140, 8) — shows current_step 0-9 ---
// "/10" suffix is already in the background ROM image
wire [14:0] hud_lvl_ones_bmp;
number_driver nd_lvl_ones (.digit(current_step), .bitmap(hud_lvl_ones_bmp));
wire        hud_in_lvl_ones = (game_x >= 8'd140) && (game_x <= 8'd142) &&
                              (game_y >= 7'd8)   && (game_y <= 7'd12);
wire [6:0]  hud_lvl_ones_cy  = game_y - 7'd8;
wire [7:0]  hud_lvl_ones_cx  = game_x - 8'd140;
wire [3:0]  hud_lvl_ones_row = 4'd4 - {1'b0, hud_lvl_ones_cy[2:0]};
wire [3:0]  hud_lvl_ones_col = 4'd2 - {2'b0, hud_lvl_ones_cx[1:0]};
wire [3:0]  hud_lvl_ones_idx = hud_lvl_ones_row * 3 + hud_lvl_ones_col;
wire        hud_lvl_ones_px  = hud_in_lvl_ones && hud_lvl_ones_bmp[hud_lvl_ones_idx];

// Tens digit removed — range is 0-9, never two digits
wire        hud_in_lvl_tens = 1'b0;
wire        hud_lvl_tens_px = 1'b0;

// --- Ball graphics: 5 × 7×7 game-pixel balls ---
// Positions (top-left): (122,23),(130,23),(138,23),(146,23),(122,31)
// Ball i is filled (spare) when balls_remaining >= i+2; last ball = all hollow.
wire hud_in_b0 = (game_x>=8'd122)&&(game_x<=8'd128)&&(game_y>=7'd23)&&(game_y<=7'd29);
wire hud_in_b1 = (game_x>=8'd130)&&(game_x<=8'd136)&&(game_y>=7'd23)&&(game_y<=7'd29);
wire hud_in_b2 = (game_x>=8'd138)&&(game_x<=8'd144)&&(game_y>=7'd23)&&(game_y<=7'd29);
wire hud_in_b3 = (game_x>=8'd146)&&(game_x<=8'd152)&&(game_y>=7'd23)&&(game_y<=7'd29);
wire hud_in_b4 = (game_x>=8'd122)&&(game_x<=8'd128)&&(game_y>=7'd31)&&(game_y<=7'd37);
wire hud_in_any_ball = hud_in_b0|hud_in_b1|hud_in_b2|hud_in_b3|hud_in_b4;

wire [7:0] hud_bdx = hud_in_b0 ? (game_x - 8'd122) :
                     hud_in_b1 ? (game_x - 8'd130) :
                     hud_in_b2 ? (game_x - 8'd138) :
                     hud_in_b3 ? (game_x - 8'd146) :
                                 (game_x - 8'd122);
wire [6:0] hud_bdy = (hud_in_b4) ? (game_y - 7'd31) : (game_y - 7'd23);

// Filled ball pattern (7 rows × 7 bits; bit 6 = leftmost pixel x=0)
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

// Hollow ball pattern (outer ring only)
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

wire hud_b0_fill = (balls_remaining >= 3'd2);
wire hud_b1_fill = (balls_remaining >= 3'd3);
wire hud_b2_fill = (balls_remaining >= 3'd4);
wire hud_b3_fill = (balls_remaining >= 3'd5);
wire hud_b4_fill = (balls_remaining >= 3'd6);

wire hud_cur_ball_fill = (hud_in_b0 & hud_b0_fill) | (hud_in_b1 & hud_b1_fill) |
                         (hud_in_b2 & hud_b2_fill) | (hud_in_b3 & hud_b3_fill) |
                         (hud_in_b4 & hud_b4_fill);

wire [6:0] hud_ball_row = hud_cur_ball_fill ? hud_ball_filled_row : hud_ball_hollow_row;
wire       hud_ball_px  = hud_ball_row[3'd6 - hud_bdx[2:0]];

// HUD filled ball highlight at same relative position: (dx=4,dy=1) and (dx=5,dy=2)
wire hud_ball_hi_px = hud_cur_ball_fill && hud_ball_px &&
                      ((hud_bdx == 8'd4 && hud_bdy == 7'd1) ||
                       (hud_bdx == 8'd5 && hud_bdy == 7'd2));

// ---------------------------------------------------------------------------
// Combinational pixel logic — priority: first match wins
// ---------------------------------------------------------------------------
reg r_next, g_next, b_next, ball_gray_next;

always @(*) begin
    // Default: black
    r_next = 1'b0;
    g_next = 1'b0;
    b_next = 1'b0;
    ball_gray_next = 1'b0;

    if (!blank_n) begin
        // Layer 1: blanking interval
        r_next = 1'b0; g_next = 1'b0; b_next = 1'b0;

    end else if (game_state == S_GAME_OVER) begin
        // Layer 2: game over — dark red
        r_next = 1'b1; g_next = 1'b0; b_next = 1'b0;

    end else begin
        // S_PLAYING: black playfield by default, then layers on top

        if (game_x == 8'd39 || game_x == 8'd119) begin
            // Layer 3: side walls — white
            // (screen_x 156 → game_x 39 ; screen_x 476 → game_x 119)
            r_next = 1'b1; g_next = 1'b1; b_next = 1'b1;

        end else if ((game_x >= 8'd39) && (game_x <= 8'd119) &&
                     (game_y >= bar_y_here) && (game_y < bar_y_here + 7'd1)) begin
            // Layer 4: bar — white (1 game-pixel thick = 4 screen rows)
            r_next = 1'b1; g_next = 1'b1; b_next = 1'b1;

        end else if ((balls_remaining > 3'b0) && ball_spr_px) begin
            // Layer 5: ball — gray body (ball.png gray), white highlight
            r_next = 1'b1; g_next = 1'b1; b_next = 1'b1;
            ball_gray_next = !ball_spr_hi_px;

        end else if (any_hole) begin
            // Layer 6: holes
            if (ball_in_hole_border) begin
                // Ball entering this hole — red (overrides target yellow)
                r_next = 1'b1; g_next = 1'b0; b_next = 1'b0;
            end else if (target_border) begin
                // Target hole border — yellow
                r_next = 1'b1; g_next = 1'b1; b_next = 1'b0;
            end else if (any_border) begin
                // Normal hole border — white
                r_next = 1'b1; g_next = 1'b1; b_next = 1'b1;
            end
            // else: hole interior stays black (default)

        end else if (hud_in_round) begin
            // Layer 7: ROUND digit
            r_next = hud_round_px; g_next = hud_round_px; b_next = hud_round_px;

        end else if (hud_in_lvl_tens) begin
            // Layer 7: LVL tens digit (only when step=9, showing "10")
            r_next = hud_lvl_tens_px; g_next = hud_lvl_tens_px; b_next = hud_lvl_tens_px;

        end else if (hud_in_lvl_ones) begin
            // Layer 7: LVL ones digit
            r_next = hud_lvl_ones_px; g_next = hud_lvl_ones_px; b_next = hud_lvl_ones_px;

        end else if (hud_in_any_ball) begin
            // Layer 7: ball graphics — gray filled body (with white highlight) or hollow ring
            r_next = hud_ball_px; g_next = hud_ball_px; b_next = hud_ball_px;
            ball_gray_next = hud_cur_ball_fill && hud_ball_px && !hud_ball_hi_px;

        end else if (bg_pixel) begin
            // Layer 8: static background — white where image pixel is set
            r_next = 1'b1; g_next = 1'b1; b_next = 1'b1;
        end
    end
end

// ---------------------------------------------------------------------------
// Registered output (one flip-flop to meet VGA timing)
// ---------------------------------------------------------------------------
always @(posedge clk) begin
    if (rst) begin
        vga_r     <= 1'b0;
        vga_g     <= 1'b0;
        vga_b     <= 1'b0;
        ball_gray <= 1'b0;
    end else begin
        vga_r     <= r_next;
        vga_g     <= g_next;
        vga_b     <= b_next;
        ball_gray <= ball_gray_next;
    end
end

endmodule
