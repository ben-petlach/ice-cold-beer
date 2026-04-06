// ============================================================================
// adc_hex_debug.v — ADC debug display on seven-segment HEX displays
// 
// Based on de10lite-hello-adc-dev reference project.
// When debug_sw is high, displays the selected raw 12-bit ADC value
// across HEX3..HEX1 (3 hex digits) and the channel indicator on HEX4.
// When debug_sw is low, outputs are all blank (0xFF) so the normal 
// seven_segment_driver output can be used instead.
//
// Attribution: ADC display concept from de10lite-hello-adc-dev project
//              (Intel/Terasic DE10-Lite ADC example, modified for Verilog)
// ============================================================================

module adc_hex_debug (
    input  wire        debug_sw,       // SW to enable debug display
    input  wire        ch_sel,         // 0 = left ADC, 1 = right ADC
    input  wire [11:0] adc_raw_left,   // raw 12-bit left joystick ADC
    input  wire [11:0] adc_raw_right,  // raw 12-bit right joystick ADC

    output reg  [7:0]  HEX5,           // blank
    output reg  [7:0]  HEX4,           // channel label: "L" or "r"
    output reg  [7:0]  HEX3,           // ADC[11:8]  (most significant hex digit)
    output reg  [7:0]  HEX2,           // ADC[7:4]
    output reg  [7:0]  HEX1,           // ADC[3:0]   (least significant hex digit)
    output reg  [7:0]  HEX0            // blank
);

    // Channel label characters (active-low seven-segment)
    localparam CHAR_L     = 8'b1100_0111;  // "L"  — segments 5,4,3
    localparam CHAR_R     = 8'b1010_1111;  // "r"  — segments 6,4
    localparam CHAR_BLANK = 8'b1111_1111;  // all off

    // Select the active ADC channel
    wire [11:0] adc_val = ch_sel ? adc_raw_right : adc_raw_left;

    // Split 12-bit value into three 4-bit hex nibbles
    wire [3:0] nib_hi  = adc_val[11:8];
    wire [3:0] nib_mid = adc_val[7:4];
    wire [3:0] nib_lo  = adc_val[3:0];

    // Decoded seven-segment patterns for each nibble
    reg [7:0] seg_hi, seg_mid, seg_lo;

    // 4-bit hex to seven-segment decoder (active-low, bit 7 = DP off)
    always @(*) begin
        case (nib_hi)
            4'h0: seg_hi = 8'b1100_0000;
            4'h1: seg_hi = 8'b1111_1001;
            4'h2: seg_hi = 8'b1010_0100;
            4'h3: seg_hi = 8'b1011_0000;
            4'h4: seg_hi = 8'b1001_1001;
            4'h5: seg_hi = 8'b1001_0010;
            4'h6: seg_hi = 8'b1000_0010;
            4'h7: seg_hi = 8'b1111_1000;
            4'h8: seg_hi = 8'b1000_0000;
            4'h9: seg_hi = 8'b1001_0000;
            4'hA: seg_hi = 8'b1000_1000;
            4'hB: seg_hi = 8'b1000_0011;
            4'hC: seg_hi = 8'b1100_0110;
            4'hD: seg_hi = 8'b1010_0001;
            4'hE: seg_hi = 8'b1000_0110;
            4'hF: seg_hi = 8'b1000_1110;
            default: seg_hi = 8'b1111_1111;
        endcase
    end

    always @(*) begin
        case (nib_mid)
            4'h0: seg_mid = 8'b1100_0000;
            4'h1: seg_mid = 8'b1111_1001;
            4'h2: seg_mid = 8'b1010_0100;
            4'h3: seg_mid = 8'b1011_0000;
            4'h4: seg_mid = 8'b1001_1001;
            4'h5: seg_mid = 8'b1001_0010;
            4'h6: seg_mid = 8'b1000_0010;
            4'h7: seg_mid = 8'b1111_1000;
            4'h8: seg_mid = 8'b1000_0000;
            4'h9: seg_mid = 8'b1001_0000;
            4'hA: seg_mid = 8'b1000_1000;
            4'hB: seg_mid = 8'b1000_0011;
            4'hC: seg_mid = 8'b1100_0110;
            4'hD: seg_mid = 8'b1010_0001;
            4'hE: seg_mid = 8'b1000_0110;
            4'hF: seg_mid = 8'b1000_1110;
            default: seg_mid = 8'b1111_1111;
        endcase
    end

    always @(*) begin
        case (nib_lo)
            4'h0: seg_lo = 8'b1100_0000;
            4'h1: seg_lo = 8'b1111_1001;
            4'h2: seg_lo = 8'b1010_0100;
            4'h3: seg_lo = 8'b1011_0000;
            4'h4: seg_lo = 8'b1001_1001;
            4'h5: seg_lo = 8'b1001_0010;
            4'h6: seg_lo = 8'b1000_0010;
            4'h7: seg_lo = 8'b1111_1000;
            4'h8: seg_lo = 8'b1000_0000;
            4'h9: seg_lo = 8'b1001_0000;
            4'hA: seg_lo = 8'b1000_1000;
            4'hB: seg_lo = 8'b1000_0011;
            4'hC: seg_lo = 8'b1100_0110;
            4'hD: seg_lo = 8'b1010_0001;
            4'hE: seg_lo = 8'b1000_0110;
            4'hF: seg_lo = 8'b1000_1110;
            default: seg_lo = 8'b1111_1111;
        endcase
    end

    // Drive HEX outputs
    always @(*) begin
        if (debug_sw) begin
            HEX5 = CHAR_BLANK;
            HEX4 = ch_sel ? CHAR_R : CHAR_L;
            HEX3 = seg_hi;
            HEX2 = seg_mid;
            HEX1 = seg_lo;
            HEX0 = CHAR_BLANK;
        end else begin
            HEX5 = CHAR_BLANK;
            HEX4 = CHAR_BLANK;
            HEX3 = CHAR_BLANK;
            HEX2 = CHAR_BLANK;
            HEX1 = CHAR_BLANK;
            HEX0 = CHAR_BLANK;
        end
    end

endmodule
