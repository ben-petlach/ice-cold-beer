module vga_rectangle(
    output reg red,
    output reg green,
    output reg blue,
    input [6:0] grid_x,
    input [5:0] grid_y,
    input blank,
    input clk,
    input [5:0] appleX,
    input [4:0] appleY,
    input [10:0] snake0,
    input [10:0] snake1,
    input [10:0] snake2,
    input [10:0] snake3,
    input [10:0] snake4,
    input [10:0] snake5,
    input [10:0] snake6,
    input [10:0] snake7,
    input [10:0] snake8,
    input [10:0] snake9,
    input reset,
    output reg [5:0] CurAppleX,
    output reg [4:0] CurAppleY
);

    reg [5:0] snake_x [0:9];
    reg [4:0] snake_y [0:9];
    integer i;

    // Assign snake positions to arrays for easier handling
    always @(*)
    begin
        snake_x[0] = snake0[5:0];
        snake_y[0] = snake0[10:6];
        snake_x[1] = snake1[5:0];
        snake_y[1] = snake1[10:6];
		  snake_x[2] = snake2[5:0];
        snake_y[2] = snake2[10:6];
		  snake_x[3] = snake3[5:0];
        snake_y[3] = snake3[10:6];
		  snake_x[4] = snake4[5:0];
        snake_y[4] = snake4[10:6];
		  snake_x[5] = snake5[5:0];
        snake_y[5] = snake5[10:6];
		  snake_x[6] = snake6[5:0];
        snake_y[6] = snake6[10:6];
		  snake_x[7] = snake7[5:0];
        snake_y[7] = snake7[10:6];
		  snake_x[8] = snake8[5:0];
        snake_y[8] = snake8[10:6];
		  snake_x[9] = snake9[5:0];
        snake_y[9] = snake9[10:6];
        // ... Repeat for all snake segments up to snake31

    end

    // Render the grid
    always @(posedge clk)
    begin
        if (blank)
        begin
            red <= 0;
            green <= 0;
            blue <= 0;
        end
        else
        begin
            // Draw walls (blue)
            if (grid_x == 18 || grid_y == 6)
            begin
                red <= 0;
                green <= 0;
                blue <= 1;
            end
            // Draw apple (red)
            else if (grid_x == CurAppleX && grid_y == CurAppleY)
            begin
                red <= 1;
                green <= 0;
                blue <= 0;
            end
            // Draw snake head (green)
            else if (grid_x == snake_x[0] && grid_y == snake_y[0])
            begin
                red <= 0;
                green <= 1;
                blue <= 0;
            end
            // Draw snake body (cyan)
            else
            begin
                red <= 0;
                green <= 0;
                blue <= 0;
                for (i = 1; i < 10; i = i + 1)
                begin
                    if (snake_x[i] == grid_x && snake_y[i] == grid_y)
                    begin
                        red <= 0;
                        green <= 1;
                        blue <= 1;
                    end
                end
            end
        end
    end

    // Update apple position when eaten
    always @(posedge clk or posedge reset)
    begin
        if (reset)
        begin
            CurAppleX <= appleX;
            CurAppleY <= appleY;
        end
        else if (snake_x[0] == CurAppleX && snake_y[0] == CurAppleY)
        begin
            CurAppleX <= appleX;
            CurAppleY <= appleY;
        end
    end

endmodule
