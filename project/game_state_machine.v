module game_state_machine (
    input  wire        clk,
    input  wire        rst,
    input  wire        key_hole,        // active-high; edge-detected: simulate target hole sunk
    input  wire        key_ball_lost,   // active-high; edge-detected: simulate ball lost
    input  wire [7:0]  ball_x,          // ball centre, game coords
    input  wire [6:0]  ball_y,
    input  wire        ball_lost,       // active-high pulse: ball fell past bar
    output reg  [2:0]  game_state,
    output reg  [3:0]  level,
    output reg  [3:0]  current_step,
    output reg  [2:0]  balls_remaining,
    output reg  [15:0] score,
    output wire [5:0]  target_hole_id,
    output wire        ball_event       
);

`include "hole_positions.vh"
`include "level_holes.vh"

localparam S_PLAYING    = 3'b001;
localparam S_GAME_OVER  = 3'b010;

assign target_hole_id = LEVEL_HOLES[level[1:0]][current_step];

// Collision detection — ball centre in 4×4 minus corners of each hole
// Sensitive area: [HOLE_X+2..HOLE_X+5] x [HOLE_Y+2..HOLE_Y+5], corners excluded (12 pixels)
wire [36:0] ball_in_hole;
genvar j;
generate
    for (j = 0; j < 37; j = j + 1) begin : hole_col
        assign ball_in_hole[j] =
            (ball_x >= {1'b0, HOLE_X[j]} + 8'd2) && (ball_x <= {1'b0, HOLE_X[j]} + 8'd5) &&
            (ball_y >= HOLE_Y[j] + 7'd2)          && (ball_y <= HOLE_Y[j] + 7'd5) &&
            !(  (ball_x == {1'b0, HOLE_X[j]} + 8'd2 || ball_x == {1'b0, HOLE_X[j]} + 8'd5) &&
                (ball_y == HOLE_Y[j] + 7'd2         || ball_y == HOLE_Y[j] + 7'd5)  );
    end
endgenerate

wire in_hole       = ball_in_hole[target_hole_id];
wire in_non_target = |(ball_in_hole & ~(37'b1 << target_hole_id));

reg in_hole_prev;
reg in_non_target_prev;
wire hole_entered      = in_hole       && !in_hole_prev;
wire non_target_entered = in_non_target && !in_non_target_prev;

assign ball_event = (game_state == S_PLAYING) &&
                    (hole_entered || key_hole_edge || ball_lost || key_ball_lost_edge || non_target_entered);

reg key_hole_prev, key_ball_lost_prev;
wire key_hole_edge      = key_hole      && !key_hole_prev;
wire key_ball_lost_edge = key_ball_lost && !key_ball_lost_prev;

// State machine
always @(posedge clk) begin
    if (rst) begin
        game_state           <= S_PLAYING;
        level                <= 4'd0;
        current_step         <= 4'd0;
        balls_remaining      <= 3'd6;
        score                <= 16'd0;
        in_hole_prev         <= 1'b0;
        in_non_target_prev   <= 1'b0;
        key_hole_prev        <= 1'b0;
        key_ball_lost_prev   <= 1'b0;
    end else begin
        in_hole_prev       <= in_hole;
        in_non_target_prev <= in_non_target;
        key_hole_prev      <= key_hole;
        key_ball_lost_prev <= key_ball_lost;

        case (game_state)

            S_PLAYING: begin
                if (hole_entered || key_hole_edge) begin
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
                end else if (ball_lost || key_ball_lost_edge || non_target_entered) begin
                    if (balls_remaining == 3'd1) begin
                        balls_remaining <= 3'd0;
                        game_state      <= S_GAME_OVER;
                    end else begin
                        balls_remaining <= balls_remaining - 3'd1;
                    end
                end
            end

            S_GAME_OVER: begin
                // Exit via SW[9] hard reset only
            end

            default: game_state <= S_PLAYING;

        endcase
    end
end

endmodule
