module video_sync_generator(
    input reset,
    input vga_clk,
    output reg blank_n,
    output reg HS,
    output reg VS,
    output reg [10:0] h_cnt, // Exposed horizontal counter
    output reg [9:0] v_cnt   // Exposed vertical counter
);

    parameter H_TOTAL = 800;
    parameter H_SYNC_PULSE = 96;
    parameter H_BACK_PORCH = 48;
    parameter H_ACTIVE = 640;
    parameter H_FRONT_PORCH = 16;

    parameter V_TOTAL = 525;
    parameter V_SYNC_PULSE = 2;
    parameter V_BACK_PORCH = 33;
    parameter V_ACTIVE = 480;
    parameter V_FRONT_PORCH = 10;

    // Horizontal and vertical counters
    always @(posedge vga_clk or posedge reset)
    begin
        if (reset)
        begin
            h_cnt <= 0;
            v_cnt <= 0;
        end
        else
        begin
            if (h_cnt == H_TOTAL - 1)
            begin
                h_cnt <= 0;
                if (v_cnt == V_TOTAL - 1)
                    v_cnt <= 0;
                else
                    v_cnt <= v_cnt + 1;
            end
            else
                h_cnt <= h_cnt + 1;
        end
    end

    // Generate sync signals
    always @(posedge vga_clk)
    begin
        // Horizontal sync
        HS <= (h_cnt < H_SYNC_PULSE) ? 1'b0 : 1'b1;

        // Vertical sync
        VS <= (v_cnt < V_SYNC_PULSE) ? 1'b0 : 1'b1;

        // Blanking
   if ((h_cnt >= (H_SYNC_PULSE + H_BACK_PORCH)) && (h_cnt < (H_SYNC_PULSE + H_BACK_PORCH + H_ACTIVE)) && (v_cnt >= (V_SYNC_PULSE + V_BACK_PORCH)) && (v_cnt < (V_SYNC_PULSE + V_BACK_PORCH + V_ACTIVE))) 
		blank_n <= 1'b1; 
	else
       blank_n <= 1'b0;
    end

endmodule
