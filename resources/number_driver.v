// number_driver.v
// Outputs a 15-bit bitmap for a single digit (0-9) using a 3x5 pixel font.
//
// Bit layout of bitmap (15 bits):
//   [14:12] = row 0 (top)
//   [11:9]  = row 1
//   [8:6]   = row 2
//   [5:3]   = row 3
//   [2:0]   = row 4 (bottom)
//
//   Within each 3-bit row: bit 2 = left column, bit 0 = right column
//
// Usage in renderer:
//   1. Instantiate this module and connect your digit value to 'digit'.
//   2. Compute the local pixel offset within the 3x5 character cell:
//        wire [1:0] char_x = gx - DRAW_X;  // 0, 1, or 2
//        wire [2:0] char_y = gy - DRAW_Y;  // 0 to 4
//   3. Check if the current pixel is inside the character cell:
//        wire in_cell = (gx >= DRAW_X) && (gx < DRAW_X + 3) &&
//                       (gy >= DRAW_Y) && (gy < DRAW_Y + 5);
//   4. Look up whether that pixel is lit:
//        wire pixel_on = bitmap[(4 - char_y) * 3 + (2 - char_x)];
//   5. In your pixel output logic:
//        if (in_cell && pixel_on) -> draw white
//        if (in_cell && !pixel_on) -> draw black (digit background)
//
// For two digits side by side (e.g. level "12"):
//   - Place tens digit at DRAW_X, ones digit at DRAW_X + 4 (3px + 1px gap)
//   - wire [3:0] tens = value / 10;
//   - wire [3:0] ones = value % 10;
//   - Instantiate number_driver twice, one for tens and one for ones.

module number_driver (
    input  [3:0] digit,       // digit to display: 0-9
    output reg [14:0] bitmap  // 15-bit pixel map for the 3x5 character cell
);
    always @(*) begin
        case (digit)
            //              row0 row1 row2 row3 row4
            4'd0: bitmap = 15'b010_101_101_101_010;
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
