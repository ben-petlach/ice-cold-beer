module vga_renderer(
    input clk,
    input blank_n, 
    input [10:0] h_cnt, // Horizontal counter from sync generator
    input [9:0] v_cnt,  // Vertical counter from sync generator

    input [9:0] ball_x,
    input [9:0] ball_y,
    input [9:0] bar_left_y,
    input [9:0] bar_right_y,
    
)