// =============================================================================
// game_state_machine.v
//
// Tracks game state, level, step, score, and target hole.
// Uses level_holes.vh for the fixed per-level hole sequences and
// hole_positions.vh for collision coordinates.
//
// Inputs
//   key_start  — active-high edge: start game (from START_MENU) or restart (from GAME_OVER)
//   ball_x/y   — ball centre in game coordinates (0-159 / 0-119)
//   ball_lost  — active-high pulse: ball fell past the bar (from ball_physics)
//
// Outputs
//   game_state      — S_START_MENU / S_PLAYING / S_GAME_OVER
//   level           — current level (0-3)
//   balls_remaining — balls left (0-3)
//   score           — number of holes sunk this game
//   target_hole_id  — index into HOLE_X/HOLE_Y for the current target hole
// =============================================================================

module game_state_machine (
    input  wire        clk,
    input  wire        rst,
    input  wire        key_start,       // active-high; edge-detected internally
    input  wire [7:0]  ball_x,          // ball centre, game coords
    input  wire [6:0]  ball_y,
    input  wire        ball_lost,       // active-high pulse: ball fell past bar
    output reg  [2:0]  game_state,
    output reg  [3:0]  level,
    output reg  [3:0]  current_step,
    output reg  [2:0]  balls_remaining,
    output reg  [15:0] score,
    output wire [5:0]  target_hole_id
);

`include "hole_positions.vh"
`include "level_holes.vh"

localparam S_START_MENU = 3'b000;
localparam S_PLAYING    = 3'b001;
localparam S_GAME_OVER  = 3'b010;

// ---------------------------------------------------------------------------
// Target hole lookup (combinational ROM)
// ---------------------------------------------------------------------------
assign target_hole_id = LEVEL_HOLES[level[1:0]][current_step];

// ---------------------------------------------------------------------------
// Collision detection — ball centre inside target hole window
// Hole collision window: [HOLE_X+2 .. HOLE_X+5] x [HOLE_Y+2 .. HOLE_Y+5]
// ---------------------------------------------------------------------------
wire [7:0] tgt_x = {1'b0, HOLE_X[target_hole_id]};
wire [6:0] tgt_y = HOLE_Y[target_hole_id];

wire in_hole = (ball_x >= tgt_x + 8'd2) && (ball_x <= tgt_x + 8'd5) &&
               (ball_y >= tgt_y + 7'd2) && (ball_y <= tgt_y + 7'd5);

// Edge detect: fire only once per ball entry
reg in_hole_prev;
wire hole_entered = in_hole && !in_hole_prev;

// Edge detect on key_start to avoid holding button triggering multiple transitions
reg key_prev;
wire key_edge = key_start && !key_prev;

// ---------------------------------------------------------------------------
// State machine
// ---------------------------------------------------------------------------
always @(posedge clk) begin
    if (rst) begin
        game_state      <= S_START_MENU;
        level           <= 4'd0;
        current_step    <= 4'd0;
        balls_remaining <= 3'd6;
        score           <= 16'd0;
        in_hole_prev    <= 1'b0;
        key_prev        <= 1'b0;
    end else begin
        in_hole_prev <= in_hole;
        key_prev     <= key_start;

        case (game_state)

            S_START_MENU: begin
                if (key_edge) begin
                    game_state      <= S_PLAYING;
                    level           <= 4'd0;
                    current_step    <= 4'd0;
                    balls_remaining <= 3'd6;
                    score           <= 16'd0;
                end
            end

            S_PLAYING: begin
                if (hole_entered) begin
                    score <= score + 16'd1;
                    if (current_step == 4'd9) begin
                        // Completed all 10 holes in this level
                        current_step <= 4'd0;
                        if (level == 4'd3)
                            game_state <= S_GAME_OVER;  // all levels done
                        else
                            level <= level + 4'd1;
                    end else begin
                        current_step <= current_step + 4'd1;
                    end
                end else if (ball_lost) begin
                    if (balls_remaining == 3'd1) begin
                        balls_remaining <= 3'd0;
                        game_state      <= S_GAME_OVER;
                    end else begin
                        balls_remaining <= balls_remaining - 3'd1;
                    end
                end
            end

            S_GAME_OVER: begin
                if (key_edge)
                    game_state <= S_START_MENU;
            end

            default: game_state <= S_START_MENU;

        endcase
    end
end

endmodule
