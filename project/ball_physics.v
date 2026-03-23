module ball_physics #(
    parameter BALL_RADIUS = 4,

    parameter X_MIN = 156,           // Left boundary
    parameter X_MAX = 476,           // Right boundary
    
    parameter SPAWN_X = 320,
    parameter SPAWN_Y = 440,
    
    parameter GRAVITY = 16,          // Q11.5 format (0.5 px/tick^2)
    parameter DAMPING_FACTOR_NUM = 250, // 250/256 = ~0.976 friction
    parameter DAMPING_FACTOR_DEN = 256
)(
    input  wire        clk,
    input  wire        rst,          // Global FSM reset
    input  wire        tick_60hz,    // 60Hz physics tick
    input  wire        init_ball,    // Pulse from FSM to spawn/reset ball
    input  wire        en_physics,   // High when game_state == S_PLAYING
    
    input  wire [9:0]  bar_left_y,   // Current bar left pos
    input  wire [9:0]  bar_right_y,  // Current bar right pos
    
    output wire [9:0]  ball_x,       // Screen X, fed to VGA
    output wire [9:0]  ball_y        // Screen Y, fed to VGA
);

    // Note for Future Tuning:
    // Internal position and velocity use Q11.5 fixed-point format.
    // This provides 11 bits of integer precision (up to 2047) and 5 bits of fractional precision (1/32px).
    // If different speeds/precision are needed, you can transition to Q10.6 or similar.
    reg signed [15:0] pos_x;
    reg signed [15:0] pos_y;
    reg signed [15:0] vel_x;
    reg signed [15:0] vel_y;
    
    assign ball_x = pos_x[15:5];
    assign ball_y = pos_y[15:5];
    
    // Convert inputs to signed internal wires to prevent sign-extension glitches
    wire signed [15:0] signed_bar_left = {1'b0, bar_left_y};
    wire signed [15:0] signed_bar_right = {1'b0, bar_right_y};
    
    // dx = ball_x - X_MIN
    wire signed [15:0] signed_x_int = {1'b0, ball_x};
    wire signed [15:0] dx = signed_x_int - X_MIN;
    
    // Interpolate bar_y at current ball_x
    // dy_bar = right_y - left_y
    wire signed [15:0] dy_bar = signed_bar_right - signed_bar_left;
    
    // surface_y = bar_left_y + (dy_bar * dx / 320)
    // Using approximation: division by 320 is roughly (val * 205) >> 16
    wire signed [31:0] y_offset = (dy_bar * dx * 205) >>> 16;
    wire signed [15:0] surface_y = signed_bar_left + y_offset[15:0];
    
    // Convert surface_y to Q11.5 for comparison with pos_y
    wire signed [15:0] surface_y_q11_5 = {surface_y[10:0], 5'b00000};
    
    // Calculate ball resting logic (taking BALL_RADIUS into account)
    // Ball rests on the surface if the bottom of the ball touches or exceeds the surface line
    wire signed [15:0] ball_bottom_q11_5 = pos_y + (BALL_RADIUS << 5);
    wire is_resting = (ball_bottom_q11_5 >= surface_y_q11_5);
    
    // Horizontal rolling acceleration proportional to bar slope (dy_bar)
    // Using approx for (dy_bar * scaling_factor / 320)
    // Choose scaling factor = 16 for reasonable acceleration
    wire signed [15:0] roll_accel_approx = (dy_bar * 3280) >>> 16;
    
    always @(posedge clk) begin
        if (rst || init_ball) begin
            pos_x <= SPAWN_X << 5;
            pos_y <= SPAWN_Y << 5;
            vel_x <= 0;
            vel_y <= 0;
        end else if (tick_60hz && en_physics) begin
        
            // 1. Base positional update
            pos_x <= pos_x + vel_x;
            pos_y <= pos_y + vel_y;
            
            // 2. Default Gravity
            vel_y <= vel_y + GRAVITY;
            
            // 3. Wall collisions
            if (pos_x + vel_x <= (X_MIN << 5)) begin
                pos_x <= X_MIN << 5;
                vel_x <= 0;
            end else if (pos_x + vel_x >= (X_MAX << 5)) begin
                pos_x <= X_MAX << 5;
                vel_x <= 0;
            end
            
            // 4. Ground collisions & interaction
            if (is_resting) begin
                // Snap to bar surface
                pos_y <= surface_y_q11_5 - (BALL_RADIUS << 5);
                vel_y <= 0;
                
                // Roll logic
                if ((pos_x + vel_x <= (X_MIN << 5)) && (roll_accel_approx < 0)) begin
                    // Pushing left into wall, keep velocity 0
                    vel_x <= 0;
                end else if ((pos_x + vel_x >= (X_MAX << 5)) && (roll_accel_approx > 0)) begin
                    // Pushing right into wall, keep velocity 0
                    vel_x <= 0;
                end else begin
                    // Apply acceleration and friction using arithmetic shift
                    vel_x <= vel_x + roll_accel_approx - (vel_x >>> 6);
                end
            end
        end
    end

endmodule
