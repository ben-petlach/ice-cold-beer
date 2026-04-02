module ball_physics (
    input  wire       clk,
    input  wire       rst,
    input  wire       ball_event,   
    input  wire       tick_60hz,
    input  wire [2:0] game_state,
    input  wire [6:0] bar_left_y,
    input  wire [6:0] bar_right_y,
    output wire [7:0] ball_x,
    output wire [6:0] ball_y
);

localparam S_PLAYING = 3'b001;

localparam [15:0] POS_INIT = 16'd20224;  // 79  * 256  bar centre
localparam [15:0] POS_MIN  = 16'd10752;  // 42  * 256  left  clamp (3 px from wall at 39)
localparam [15:0] POS_MAX  = 16'd29696;  // 116 * 256  right clamp (3 px from wall at 119)

reg [15:0]        pos_x;
reg signed [15:0] vel_x;

assign ball_x = pos_x[15:8];

// Ball Y: bar surface at ball_x, minus 3 (sprite centre above bar)
wire signed [7:0] bp_slope = $signed({1'b0, bar_right_y}) - $signed({1'b0, bar_left_y});
wire signed [8:0] bp_offset = $signed({1'b0, ball_x}) - 9'sd39;
wire signed [31:0] bp_raw = bp_slope * bp_offset * 32'sd205;
wire signed [15:0] bp_y_off = (bp_raw + 32'sd8192) >>> 14;
wire signed [15:0] bp_surf = $signed({1'b0, bar_left_y}) + bp_y_off;
assign ball_y = bp_surf[6:0] - 7'd3;

// Bar slope: positive = right side lower = ball rolls right
wire signed [7:0] bar_slope = $signed({1'b0, bar_right_y}) - $signed({1'b0, bar_left_y});

// Acceleration from tilt
wire [7:0] abs_bar_slope = bar_slope[7] ? -bar_slope : bar_slope;
wire signed [7:0] effective_bar_slope = (abs_bar_slope <= 3) ? 8'sd0 : bar_slope;

wire signed [15:0] vel_acc = vel_x + {{8{effective_bar_slope[7]}}, effective_bar_slope};

// Friction
wire signed [15:0] vel_damped = vel_acc - (vel_acc >>> 3);
// Hard stop for very low speeds to prevent creeping when bar is level
wire signed [15:0] vel_fric = (effective_bar_slope == 8'sd0 && vel_damped > -8 && vel_damped < 8) ? 16'sd0 : vel_damped;

// Clamp velocity to +-1 game pixel/tick
wire signed [15:0] vel_new = (vel_fric > 16'sd256) ? 16'sd256 :
                               (vel_fric < -16'sd256) ? -16'sd256 :
                                                         vel_fric;

wire signed [16:0] pos_next = {1'b0, pos_x} + {{1{vel_new[15]}}, vel_new};

// Wall detection
wire hit_left  = (pos_next <= $signed({1'b0, POS_MIN}));
wire hit_right = (pos_next >= $signed({1'b0, POS_MAX}));

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
