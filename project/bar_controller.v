module bar_controller #(
    parameter Y_MIN = 60,            // Highest point the bar can reach (minimum Y)
    parameter Y_MAX = 460,           // Lowest point the bar can reach (maximum Y)
    parameter MAX_DY = 20,           // Maximum allowable height difference
    parameter BAR_SPEED = 2,         // Screen pixels to move per tick
    parameter START_Y = 440          // Initial starting height
)(
    input  wire        clk,          // 25 MHz system clock
    input  wire        rst,          // Synchronous active-high reset
    input  wire        en,           // Enable movement
    input  wire        tick_60hz,    // 1-cycle enable pulse at 60Hz
    input  wire [1:0]  joy_left,     // 2-bit left joystick (10=UP, 01=DOWN)
    input  wire [1:0]  joy_right,    // 2-bit right joystick (10=UP, 01=DOWN)
    
    output reg  [9:0]  bar_left_y,   // Screen Y coordinate of left end
    output reg  [9:0]  bar_right_y   // Screen Y coordinate of right end
);

    wire move_l_up   = (joy_left  == 2'b10);
    wire move_l_down = (joy_left  == 2'b01);
    wire move_r_up   = (joy_right == 2'b10);
    wire move_r_down = (joy_right == 2'b01);

    wire [9:0] next_left_y;
    wire [9:0] next_right_y;

    assign next_left_y = move_l_up ? (bar_left_y > (Y_MIN + BAR_SPEED) ? bar_left_y - BAR_SPEED : Y_MIN) :
                         move_l_down ? (bar_left_y < (Y_MAX - BAR_SPEED) ? bar_left_y + BAR_SPEED : Y_MAX) :
                         bar_left_y;

    assign next_right_y = move_r_up ? (bar_right_y > (Y_MIN + BAR_SPEED) ? bar_right_y - BAR_SPEED : Y_MIN) :
                          move_r_down ? (bar_right_y < (Y_MAX - BAR_SPEED) ? bar_right_y + BAR_SPEED : Y_MAX) :
                          bar_right_y;

    wire [10:0] diff_both = (next_left_y > next_right_y) ? (next_left_y - next_right_y) : (next_right_y - next_left_y);
    wire [10:0] diff_left_only = (next_left_y > bar_right_y) ? (next_left_y - bar_right_y) : (bar_right_y - next_left_y);
    wire [10:0] diff_right_only = (bar_left_y > next_right_y) ? (bar_left_y - next_right_y) : (next_right_y - bar_left_y);

    wire both_valid = (diff_both <= MAX_DY);
    wire left_valid = (diff_left_only <= MAX_DY);
    wire right_valid = (diff_right_only <= MAX_DY);

    always @(posedge clk) begin
        if (rst) begin
            bar_left_y <= START_Y;
            bar_right_y <= START_Y;
        end else if (tick_60hz && en) begin
            if (both_valid) begin
                bar_left_y <= next_left_y;
                bar_right_y <= next_right_y;
            end else begin
                // If moving both is invalid, see if we can move just one
                if (left_valid) bar_left_y <= next_left_y;
                if (right_valid) bar_right_y <= next_right_y;
            end
        end
    end

endmodule
