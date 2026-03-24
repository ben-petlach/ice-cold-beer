// =============================================================================
// ball_physics.v
//
// Simulates the ball rolling on the tilted bar at 60 Hz.
// The ball always rests on the bar and cannot fall off.
//
// Physics model (8.8 fixed-point, units of 1/256 game pixel):
//   velocity += bar_slope              (acceleration from tilt)
//   velocity -= velocity >> 3          (friction: ~12.5% damping per tick)
//   velocity  = clamp(vel, +-256)      (max speed: 1 game pixel / tick)
//   position += velocity
//   position  = clamp(pos, 40, 118)    (hard walls: ball stops, velocity zeroed)
//
// Terminal velocity at max slope (20): 8*20 = 160 frac units = 0.625 px/tick
// Ball crosses the 80-px bar in ~2 seconds at full tilt.
// =============================================================================

module ball_physics (
    input  wire       clk,
    input  wire       rst,
    input  wire       ball_event,   // 1-cycle pulse: reset ball to centre
    input  wire       tick_60hz,
    input  wire [2:0] game_state,
    input  wire [6:0] bar_left_y,
    input  wire [6:0] bar_right_y,
    output wire [7:0] ball_x,
    output wire       ball_lost     // reserved; always 0 (ball cannot fall off)
);

localparam S_PLAYING = 3'b001;

// 8.8 fixed-point position constants
localparam [15:0] POS_INIT = 16'd20224;  // 79  * 256  bar centre
localparam [15:0] POS_MIN  = 16'd10752;  // 42  * 256  left  clamp (3 px from wall at 39)
localparam [15:0] POS_MAX  = 16'd29696;  // 116 * 256  right clamp (3 px from wall at 119)

reg [15:0]        pos_x;
reg signed [15:0] vel_x;

assign ball_x   = pos_x[15:8];
assign ball_lost = 1'b0;

// Bar slope: positive = right side lower = ball rolls right
wire signed [7:0] bar_slope = $signed({1'b0, bar_right_y}) - $signed({1'b0, bar_left_y});

// ---------------------------------------------------------------------------
// Physics pipeline (combinational)
// ---------------------------------------------------------------------------

// 1. Acceleration from tilt
// Apply a deadzone so the ball stops when the bar is nearly level (pixel distance <= 5)
wire [7:0] abs_bar_slope = bar_slope[7] ? -bar_slope : bar_slope;
wire signed [7:0] effective_bar_slope = (abs_bar_slope <= 3) ? 8'sd0 : bar_slope;

wire signed [15:0] vel_acc  = vel_x + {{8{effective_bar_slope[7]}}, effective_bar_slope};

// 2. Friction: reduce by 1/8 per tick (arithmetic right shift preserves sign)
wire signed [15:0] vel_damped = vel_acc - (vel_acc >>> 3);
// Hard stop for very low speeds to prevent creeping when bar is level
wire signed [15:0] vel_fric = (effective_bar_slope == 8'sd0 && vel_damped > -8 && vel_damped < 8) ? 16'sd0 : vel_damped;

// 3. Clamp velocity to +-1 game pixel/tick
wire signed [15:0] vel_new  = (vel_fric >  16'sd256) ?  16'sd256 :
                               (vel_fric < -16'sd256) ? -16'sd256 :
                                                         vel_fric;

// 4. Candidate new position (17-bit catches overflow)
wire signed [16:0] pos_next = {1'b0, pos_x} + {{1{vel_new[15]}}, vel_new};

// 5. Wall detection
wire hit_left  = (pos_next <= $signed({1'b0, POS_MIN}));
wire hit_right = (pos_next >= $signed({1'b0, POS_MAX}));

// ---------------------------------------------------------------------------
// Sequential update
// ---------------------------------------------------------------------------
always @(posedge clk) begin
    if (rst || ball_event || game_state != S_PLAYING) begin
        pos_x <= POS_INIT;
        vel_x <= 16'sd0;
    end else if (tick_60hz) begin
        if (hit_left) begin
            pos_x <= POS_MIN;
            vel_x <= 16'sd0;
        end else if (hit_right) begin
            pos_x <= POS_MAX;
            vel_x <= 16'sd0;
        end else begin
            pos_x <= pos_next[15:0];
            vel_x <= vel_new;
        end
    end
end

endmodule
