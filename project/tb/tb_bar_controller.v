`timescale 1ns/1ps

module tb_bar_controller;

    reg clk;
    reg rst;
    reg en;
    reg tick_60hz;
    reg [1:0] joy_left;
    reg [1:0] joy_right;
    
    wire [9:0] bar_left_y;
    wire [9:0] bar_right_y;
    
    bar_controller uut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .tick_60hz(tick_60hz),
        .joy_left(joy_left),
        .joy_right(joy_right),
        .bar_left_y(bar_left_y),
        .bar_right_y(bar_right_y)
    );
    
    // Clock generation (25 MHz)
    always #20 clk = ~clk;
    
    task wait_ticks(input integer n);
        integer i;
        begin
            for (i=0; i<n; i=i+1) begin
                @(negedge clk);
                tick_60hz = 1;
                @(negedge clk);
                tick_60hz = 0;
            end
        end
    endtask
    
    initial begin
        // Setup
        clk = 0;
        rst = 1;
        en = 0;
        tick_60hz = 0;
        joy_left = 2'b00;
        joy_right = 2'b00;
        
        #100;
        @(negedge clk);
        rst = 0;
        en = 1;
        
        // Test 1: Reset checking
        $display("Testing init...");
        @(negedge clk);
        if (bar_left_y !== 440 || bar_right_y !== 440) $error("Initialization failed!");
        
        // Test 2: Move left UP
        $display("Testing left UP...");
        joy_left = 2'b10;
        wait_ticks(1);
        if (bar_left_y !== 438 || bar_right_y !== 440) $error("Left UP failed! l=%d", bar_left_y);
        
        // Test 3: Tilt constraint (move left UP 10 more times -> tilt 20, next move should be blocked)
        $display("Testing tilt constraint...");
        wait_ticks(15); // Wait 15 ticks, should be capped at 10 ticks (since 10*2=20 tilt max)
        if (bar_left_y !== 420) $error("Tilt constraint failed, left_y = %d", bar_left_y);
        
        // Test 4: Move both UP
        $display("Testing both UP...");
        joy_left = 2'b10;
        joy_right = 2'b10;
        wait_ticks(5);
        if (bar_left_y !== 410 || bar_right_y !== 430) $error("Both UP failed, l=%d r=%d", bar_left_y, bar_right_y);
        
        // Test 5: Boundary clipping (Y_MIN)
        $display("Testing Y_MIN boundary...");
        // move both UP significantly to hit 60
        wait_ticks(200);
        if (bar_left_y !== 60 || bar_right_y !== 60) $error("Y_MIN clip failed l=%d r=%d", bar_left_y, bar_right_y);
        
        $display("All tests passed.");
        $finish;
    end

endmodule
