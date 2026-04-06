// ============================================================================
// adc_hex_debug.v — ADC debug display on seven-segment HEX displays
// 
// Based on de10lite-hello-adc-dev reference project.
// When debug_sw is high, displays the selected raw 12-bit ADC value
// across HEX2..HEX0 (3 hex digits) and the channel indicator on HEX3.
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

    output wire [7:0]  HEX5,           // channel label high nibble (blank)
    output wire [7:0]  HEX4,           // channel label: "L" or "r"
    output wire [7:0]  HEX3,           // ADC[11:8]  (most significant hex digit)
    output wire [7:0]  HEX2,           // ADC[7:4]
    output wire [7:0]  HEX1,           // ADC[3:0]   (least significant hex digit)
    output wire [7:0]  HEX0            // blank
);

    // Select the active ADC channel
    wire [11:0] adc_val = ch_sel ? adc_raw_right : adc_raw_left;

    // Split 12-bit value into three 4-bit hex nibbles
    wire [3:0] nib_hi  = adc_val[11:8];
    wire [3:0] nib_mid = adc_val[7:4];
    wire [3:0] nib_lo  = adc_val[3:0];

    // 4-bit hex to seven-segment decoder (active-low, bit 7 = DP off)
    function automatic [7:0] hex_to_seg;
        input [3:0] hex;
        begin
            case (hex)
                4'h0: hex_to_seg = 8'b1100_0000;
                4'h1: hex_to_seg = 8'b1111_1001;
                4'h2: hex_to_seg = 8'b1010_0100;
                4'h3: hex_to_seg = 8'b1011_0000;
                4'h4: hex_to_seg = 8'b1001_1001;
                4'h5: hex_to_seg = 8'b1001_0010;
                4'h6: hex_to_seg = 8'b1000_0010;
                4'h7: hex_to_seg = 8'b1111_1000;
                4'h8: hex_to_seg = 8'b1000_0000;
                4'h9: hex_to_seg = 8'b1001_0000;
                4'hA: hex_to_seg = 8'b1000_1000;
                4'hB: hex_to_seg = 8'b1000_0011;
                4'hC: hex_to_seg = 8'b1100_0110;
                4'hD: hex_to_seg = 8'b1010_0001;
                4'hE: hex_to_seg = 8'b1000_0110;
                4'hF: hex_to_seg = 8'b1000_1110;
                default: hex_to_seg = 8'b1111_1111;
            endcase
        end
    endfunction

    // Channel label characters (active-low seven-segment)
    localparam CHAR_L     = 8'b1100_0111;  // "L"  — segments 5,4,3
    localparam CHAR_R     = 8'b1010_1111;  // "r"  — segments 6,4
    localparam CHAR_BLANK = 8'b1111_1111;  // all off

    // Drive outputs
    assign HEX5 = debug_sw ? CHAR_BLANK            : 8'hFF;
    assign HEX4 = debug_sw ? (ch_sel ? CHAR_R : CHAR_L) : 8'hFF;
    assign HEX3 = debug_sw ? hex_to_seg(nib_hi)    : 8'hFF;
    assign HEX2 = debug_sw ? hex_to_seg(nib_mid)   : 8'hFF;
    assign HEX1 = debug_sw ? hex_to_seg(nib_lo)    : 8'hFF;
    assign HEX0 = debug_sw ? CHAR_BLANK            : 8'hFF;

endmodule
