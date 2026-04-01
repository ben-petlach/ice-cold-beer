module number_driver (
    input [3:0] digit,       // digit to display: 0-9
    output reg [14:0] bitmap  // 15-bit pixel map for the 3x5 character cell
);
    always @(*) begin
        case (digit)
            //              row0 row1 row2 row3 row4
            4'd0: bitmap = 15'b111_101_101_101_111;
            4'd1: bitmap = 15'b010_110_010_010_111;
            4'd2: bitmap = 15'b111_001_111_100_111;
            4'd3: bitmap = 15'b111_001_111_001_111;
            4'd4: bitmap = 15'b101_101_111_001_001;
            4'd5: bitmap = 15'b111_100_111_001_111;
            4'd6: bitmap = 15'b111_100_111_101_111;
            4'd7: bitmap = 15'b111_001_001_001_001;
            4'd8: bitmap = 15'b111_101_111_101_111;
            4'd9: bitmap = 15'b111_101_111_001_001;
            default: bitmap = 15'b000_000_000_000_000;
        endcase
    end

endmodule
