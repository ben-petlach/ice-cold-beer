module seven_segment_driver (
    input  wire [2:0] game_state,
    input  wire [2:0] balls_remaining,
    output reg  [7:0] HEX5,
    output reg  [7:0] HEX4,
    output reg  [7:0] HEX3,
    output reg  [7:0] HEX2,
    output reg  [7:0] HEX1,
    output reg  [7:0] HEX0
);

    // Game states (match game_state_machine.v)
    localparam S_PLAYING   = 3'b001;
    localparam S_GAME_OVER = 3'b010;

    localparam CHAR_U     = 8'b1100_0001;  
    localparam CHAR_W     = 8'b1001_0101;  
    localparam CHAR_I     = 8'b1111_1011;  
    localparam CHAR_N     = 8'b1010_1011;  
    localparam CHAR_L     = 8'b1100_0111;  
    localparam CHAR_O     = 8'b1010_0011;  
    localparam CHAR_S     = 8'b1001_0010;  
    localparam CHAR_E     = 8'b1000_0110;  
    localparam CHAR_BLANK = 8'b1111_1111;  

    // Win condition: game over with balls remaining > 0
    wire is_win = (game_state == S_GAME_OVER) && (balls_remaining > 3'd0);

    always @(*) begin
        if (game_state == S_GAME_OVER) begin
            if (is_win) begin
                // Display "u  win" on HEX5..HEX0
                HEX5 = CHAR_U;      
                HEX4 = CHAR_BLANK;  
                HEX3 = CHAR_BLANK;  
                HEX2 = CHAR_W;      
                HEX1 = CHAR_I;      
                HEX0 = CHAR_N;      
            end else begin
                // Display "u lose" on HEX5..HEX0
                HEX5 = CHAR_U;      
                HEX4 = CHAR_BLANK;  
                HEX3 = CHAR_L;      
                HEX2 = CHAR_O;      
                HEX1 = CHAR_S;      
                HEX0 = CHAR_E;      
            end
        end else begin
            // Not in game-over state — blank all displays
            HEX5 = CHAR_BLANK;
            HEX4 = CHAR_BLANK;
            HEX3 = CHAR_BLANK;
            HEX2 = CHAR_BLANK;
            HEX1 = CHAR_BLANK;
            HEX0 = CHAR_BLANK;
        end
    end

endmodule
