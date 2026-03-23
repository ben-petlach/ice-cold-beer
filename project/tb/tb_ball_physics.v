`timescale 1ns/1ps

module tb_ball_physics;
    reg clk;
    reg rst;
    reg tick_60hz;
    reg init_ball;
    reg en_physics;
    
    reg [9:0] bar_left_y;
    reg [9:0] bar_right_y;
    
    wire [9:0] ball_x;
    wire [9:0] ball_y;
    
    ball_physics uut (
        .clk(clk),
        .rst(rst),
        .tick_60hz(tick_60hz),
        .init_ball(init_ball),
        .en_physics(en_physics),
        .bar_left_y(bar_left_y),
        .bar_right_y(bar_right_y),
        .ball_x(ball_x),
        .ball_y(ball_y)
    );
    
    always #20 clk = ~clk; // 25MHz

    task tick_wait(input integer n);
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
        clk = 0;
        rst = 1;
        tick_60hz = 0;
        init_ball = 0;
        en_physics = 0;
        bar_left_y = 440;
        bar_right_y = 440;
        
        #100;
        @(negedge clk);
        rst = 0;
        en_physics = 1;
        
        $display("Test 1: Initialization");
        tick_wait(1);
        if (ball_x !== 320 || ball_y !== 436) $error("Initialization failed: x=%d y=%d", ball_x, ball_y);
        
        $display("Test 2: Free fall");
        // Move bar away so ball can fall
        bar_left_y = 460;
        bar_right_y = 460;
        // Gravity = 16 (0.5 px/tick)
        // pos_y = 440. After 1 tick: vel=0.5. pos = 440.5
        // After 2 ticks: vel=1.0. pos = 441.5
        tick_wait(5);
        if (ball_y === 440) $error("Gravity not working: y=%d", ball_y);
        
        $display("Test 3: Resting on bar");
        // Let it fall until it hits 460
        // Wait 100 ticks just to be sure
        tick_wait(100);
        // It should stop at bar_Y (460) - BALL_RADIUS (4) = 456
        if (ball_y !== 456) $error("Bar resting failed: y=%d (expected 456)", ball_y);
        
        $display("Test 4: Rolling right");
        // Tilt the bar: right side lower
        bar_left_y = 450;
        bar_right_y = 470;
        // Center is 320. Surface at 320 will be 450 + (20 * 164)/320 = 460
        // Give it some ticks to roll right
        tick_wait(50);
        if (ball_x <= 320) $error("Roll right failed: x=%d", ball_x);
        
        $display("Test 5: Left wall constraint");
        // Tilt the bar hard left
        bar_left_y = 470;
        bar_right_y = 420;
        // Roll left for a long time
        tick_wait(300);
        if (ball_x !== 156) $error("Left boundary clip failed: x=%d, expected 156", ball_x);
        
        $display("Test 6: Right wall constraint");
        // Tilt the bar hard right
        bar_left_y = 420;
        bar_right_y = 470;
        tick_wait(500);
        if (ball_x !== 476) $error("Right boundary clip failed: x=%d, expected 476", ball_x);
        
        $display("All physics tests passed.");
        $finish;
    end
endmodule
