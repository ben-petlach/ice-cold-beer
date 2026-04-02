// ============================================================================
// Seven-Segment Driver for Ice-Cold Beer
// Displays "u  win" (win) or "u lose" (lose) on HEX5..HEX0
// Active-low outputs: 0 = segment ON, 1 = segment OFF
// Bit 7 = decimal point (always OFF = 1)
//
// Segment layout:
//    --0--
//   |     |
//   5     1
//   |     |
//    --6--
//   |     |
//   4     2
//   |     |
//    --3--
// ============================================================================

module seven_segment_driver (
    input  wire [2:0] game_state,
    input  wire [2:0] balls_remaining,
    output reg  [7:0] HEX5,
    output reg  [7:0] HEX4,
    output reg  [7:0] HEX3,
    output reg  [7:0] HEX2,
    output reg  [7:0] HEX1,
    output reg  [7:0] HEX0
);

    // Game states (match game_state_machine.v)
    localparam S_PLAYING   = 3'b001;
    localparam S_GAME_OVER = 3'b010;

    // Character patterns (active-low: 0 = ON, 1 = OFF, bit[7] = DP always OFF)
    // u: segments 5,4,3,2,1 ON
    localparam CHAR_U     = 8'b1100_0001;  // 8'hC1
    // w: segments 5,6,1,3 ON
    localparam CHAR_W     = 8'b1001_0101;  // 8'h95
    // i: segment 2 ON
    localparam CHAR_I     = 8'b1111_1011;  // 8'hFB
    // n: segments 4,6,2 ON
    localparam CHAR_N     = 8'b1010_1011;  // 8'hAB
    // l: segments 5,4,3 ON
    localparam CHAR_L     = 8'b1100_0111;  // 8'hC7
    // o: segments 6,4,3,2 ON
    localparam CHAR_O     = 8'b1010_0011;  // 8'hA3
    // s: segments 0,5,6,2,3 ON
    localparam CHAR_S     = 8'b1001_0010;  // 8'h92
    // e: segments 0,5,6,4,3 ON
    localparam CHAR_E     = 8'b1000_0110;  // 8'h86
    // blank: all segments OFF
    localparam CHAR_BLANK = 8'b1111_1111;  // 8'hFF

    // Win condition: game over with balls remaining > 0
    wire is_win = (game_state == S_GAME_OVER) && (balls_remaining > 3'd0);

    always @(*) begin
        if (game_state == S_GAME_OVER) begin
            if (is_win) begin
                // Display "u  win" on HEX5..HEX0
                HEX5 = CHAR_U;      // u
                HEX4 = CHAR_BLANK;  // (space)
                HEX3 = CHAR_BLANK;  // (space)
                HEX2 = CHAR_W;      // w
                HEX1 = CHAR_I;      // i
                HEX0 = CHAR_N;      // n
            end else begin
                // Display "u lose" on HEX5..HEX0
                HEX5 = CHAR_U;      // u
                HEX4 = CHAR_BLANK;  // (space)
                HEX3 = CHAR_L;      // l
                HEX2 = CHAR_O;      // o
                HEX1 = CHAR_S;      // s
                HEX0 = CHAR_E;      // e
            end
        end else begin
            // Not in game-over state — blank all displays
            HEX5 = CHAR_BLANK;
            HEX4 = CHAR_BLANK;
            HEX3 = CHAR_BLANK;
            HEX2 = CHAR_BLANK;
            HEX1 = CHAR_BLANK;
            HEX0 = CHAR_BLANK;
        end
    end

endmodule
