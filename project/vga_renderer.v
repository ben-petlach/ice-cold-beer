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
    input  wire [2:0]  balls_remaining,
    input  wire [15:0] score,
    input  wire [5:0]  target_hole_id,
    output reg         vga_r,
    output reg         vga_g,
    output reg         vga_b
);

`include "hole_positions.vh"

// Game state encoding
localparam S_START_MENU = 3'b000;
localparam S_PLAYING    = 3'b001;
localparam S_GAME_OVER  = 3'b010;

// Screen coordinate conversion (VGA hardware signals — unchanged)
// H: h_cnt active region starts at H_SYNC_PULSE + H_BACK_PORCH = 96+48 = 144
// V: v_cnt active region starts at V_SYNC_PULSE + V_BACK_PORCH =  2+33 = 35
wire [9:0] screen_x = h_cnt[9:0] - 10'd144;
wire [9:0] screen_y = v_cnt      - 10'd35;

// Game coordinate conversion (convert once here; all logic below uses game coords)
wire [7:0] game_x = screen_x[9:2];  // 0-159  (>>2 = /4)
wire [6:0] game_y = screen_y[8:2];  // 0-119  (>>2 = /4)

// ---------------------------------------------------------------------------
// Bar interpolation (game space)
// Bar spans game_x 39-119 (width=80). Divide by 80 approximated as >>6 (/64).
// ~25% error at far end — identical quality to previous >>8 ≈ /256 ≈ /320.
// ---------------------------------------------------------------------------
wire signed [7:0]  bar_slope  = $signed({1'b0, bar_right_y}) - $signed({1'b0, bar_left_y});
wire        [6:0]  bar_offset = game_x[6:0] - 7'd39;          // 0-80 when in bar X range
wire signed [14:0] bar_interp = $signed({1'b0, bar_left_y, 6'b0}) +
                                 bar_slope * $signed({1'b0, bar_offset});
wire        [6:0]  bar_y_here = bar_interp[12:6];              // >>6 ≈ /64 ≈ /80

// ---------------------------------------------------------------------------
// Ball circle test (game space)
// r²=2 → 3×3 diamond (orthogonal neighbours + center); each game px = 4×4 screen px
// ---------------------------------------------------------------------------
wire signed [8:0] bdx       = $signed({1'b0, game_x}) - $signed({1'b0, ball_x});
wire signed [7:0] bdy       = $signed({1'b0, game_y}) - $signed({1'b0, ball_y});
wire        [17:0] ball_dist2 = bdx * bdx + bdy * bdy;
wire               in_ball   = (ball_dist2 <= 18'd2);

// ---------------------------------------------------------------------------
// Hole rendering (game space) — generate per-hole wires, OR-reduced outside
// Hole tiles are 8×8 game pixels; 3-pixel diagonal corner cut per corner.
// ---------------------------------------------------------------------------
wire [36:0] hole_active;
wire [36:0] hole_border;
wire [36:0] hole_is_target;

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
        wire corner        = (dx + dy             < 3'd2) ||
                             (dx + (3'd7 - dy)    < 3'd2) ||
                             ((3'd7 - dx) + dy    < 3'd2) ||
                             ((3'd7 - dx) + (3'd7 - dy) < 3'd2);
        assign hole_active[i]    = in_bounds && !corner;
        assign hole_border[i]    = hole_active[i] &&
                                   (dx == 3'd0 || dx == 3'd7 ||
                                    dy == 3'd0 || dy == 3'd7 ||
                                    (dx == 3'd1 && dy == 3'd1) ||
                                    (dx == 3'd6 && dy == 3'd1) ||
                                    (dx == 3'd1 && dy == 3'd6) ||
                                    (dx == 3'd6 && dy == 3'd6));
        assign hole_is_target[i] = hole_active[i] && (i[5:0] == target_hole_id);
    end
endgenerate

wire any_hole      = |hole_active;
wire any_border    = |hole_border;
wire target_border = |(hole_border & hole_is_target);

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
// Combinational pixel logic — priority: first match wins
// ---------------------------------------------------------------------------
reg r_next, g_next, b_next;

always @(*) begin
    // Default: black
    r_next = 1'b0;
    g_next = 1'b0;
    b_next = 1'b0;

    if (!blank_n) begin
        // Layer 1: blanking interval
        r_next = 1'b0; g_next = 1'b0; b_next = 1'b0;

    end else if (game_state == S_START_MENU) begin
        // Layer 2: start menu — dark blue
        r_next = 1'b0; g_next = 1'b0; b_next = 1'b1;

    end else if (game_state == S_GAME_OVER) begin
        // Layer 2: game over — dark red
        r_next = 1'b1; g_next = 1'b0; b_next = 1'b0;

    end else begin
        // S_PLAYING: black playfield by default, then layers on top

        if (game_x == 8'd39 || game_x == 8'd119) begin
            // Layer 3: side walls — white
            // (screen_x 156 → game_x 39 ; screen_x 476 → game_x 119)
            r_next = 1'b1; g_next = 1'b1; b_next = 1'b1;

        end else if (any_hole) begin
            // Layer 4: holes
            if (target_border) begin
                // Target hole border — yellow
                r_next = 1'b1; g_next = 1'b1; b_next = 1'b0;
            end else if (any_border) begin
                // Normal hole border — white
                r_next = 1'b1; g_next = 1'b1; b_next = 1'b1;
            end
            // else: hole interior stays black (default)

        end else if ((game_x >= 8'd39) && (game_x <= 8'd119) &&
                     (game_y >= bar_y_here) && (game_y < bar_y_here + 7'd1)) begin
            // Layer 5: bar — white (1 game-pixel thick = 4 screen rows)
            r_next = 1'b1; g_next = 1'b1; b_next = 1'b1;

        end else if ((balls_remaining > 3'b0) && in_ball) begin
            // Layer 6: ball — white
            r_next = 1'b1; g_next = 1'b1; b_next = 1'b1;

        end else if (game_y < 7'd5) begin
            // Layer 7: HUD strip stub — green (game_y<5 → screen rows 0-19)
            r_next = 1'b0; g_next = 1'b1; b_next = 1'b0;

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
        vga_r <= 1'b0;
        vga_g <= 1'b0;
        vga_b <= 1'b0;
    end else begin
        vga_r <= r_next;
        vga_g <= g_next;
        vga_b <= b_next;
    end
end

endmodule
