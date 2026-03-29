// =============================================================================
// joystick_adc_reader.v
//
// Reads ADC channels 0 and 1 via the joystick_adc Avalon-MM slave interface
// and converts each reading to a 2-bit joystick direction signal.
//
// Threshold voltages (Vref = 3.3 V, 12-bit ADC, full-scale = 4095):
//   > 2.7 V  →  code 3352  →  joy = 2'b01  (DOWN)
//   < 2.0 V  →  code 2482  →  joy = 2'b10  (UP)
//   else     →              →  joy = 2'b00  (center / no move)
//
// Avalon-MM register map (from joystick_adc IP):
//   addr 0 : command register (write channel index to start conversion)
//   addr 1 : result register  (read 12-bit result in bits [11:0])
//
// Sequencer FSM:
//   IDLE → WR_CMD → WAIT_RD → RD_RESULT → IDLE
//   Alternates between channel 0 and channel 1 on each pass.
// =============================================================================

module joystick_adc_reader #(
    parameter THRESH_HIGH = 12'd3352,   // > 2.7 V  → DOWN (joy = 01)
    parameter THRESH_LOW  = 12'd2482    // < 2.0 V  → UP   (joy = 10)
)(
    input  wire        clk,
    input  wire        rst,

    // Avalon-MM master port → connects to joystick_adc slave
    output reg         adc_write,
    output reg  [31:0] adc_writedata,
    output reg  [2:0]  adc_address,
    output reg         adc_read,
    input  wire [31:0] adc_readdata,
    input  wire        adc_waitrequest,

    // Decoded joystick outputs
    output reg  [1:0]  joy_left,    // channel 0
    output reg  [1:0]  joy_right    // channel 1
);

// ---------------------------------------------------------------------------
// FSM states
// ---------------------------------------------------------------------------
localparam S_IDLE      = 3'd0;
localparam S_WR_CMD    = 3'd1;   // write channel index to addr 0
localparam S_WAIT_WR   = 3'd2;   // hold write until waitrequest deasserts
localparam S_RD_REQ    = 3'd3;   // assert read to address based on channel
localparam S_WAIT_RD   = 3'd4;   // hold read until waitrequest deasserts, sample data

reg [2:0] state;
reg       current_ch;   // 0 = left joystick (ADC Address 1), 1 = right (ADC Address 2)

// ---------------------------------------------------------------------------
// Decode 12-bit ADC reading → 2-bit direction
// ---------------------------------------------------------------------------
function automatic [1:0] decode_joy;
    input [11:0] adc_val;
    begin
        if (adc_val > THRESH_HIGH)
            decode_joy = 2'b01;   // DOWN
        else if (adc_val < THRESH_LOW)
            decode_joy = 2'b10;   // UP
        else
            decode_joy = 2'b00;   // center
    end
endfunction

// ---------------------------------------------------------------------------
// FSM
// ---------------------------------------------------------------------------
always @(posedge clk) begin
    if (rst) begin
        state         <= S_IDLE;
        current_ch    <= 1'b0;
        adc_write     <= 1'b0;
        adc_read      <= 1'b0;
        adc_writedata <= 32'd0;
        adc_address   <= 3'd0;
        joy_left      <= 2'b00;
        joy_right     <= 2'b00;
    end else begin
        case (state)

            // -----------------------------------------------------------------
            S_IDLE: begin
                adc_write  <= 1'b0;
                adc_read   <= 1'b0;
                state      <= S_WR_CMD;
            end

            // -----------------------------------------------------------------
            // Write the channel index to address 0 to start a conversion.
            // The IP starts a conversion when it receives a write with the
            // channel number in writedata[2:0].
            // -----------------------------------------------------------------
            S_WR_CMD: begin
                adc_write     <= 1'b1;
                adc_address   <= 3'd0;
                adc_writedata <= {29'd0, 2'b0, current_ch};  // channel 0 or 1
                state         <= S_WAIT_WR;
            end

            // -----------------------------------------------------------------
            S_WAIT_WR: begin
                if (!adc_waitrequest) begin
                    adc_write <= 1'b0;
                    state     <= S_RD_REQ;
                end
            end

            // -----------------------------------------------------------------
            // Issue a read to the appropriate channel address to retrieve the result.
            // Address 1 corresponds to Channel 1 (Arduino A0).
            // Address 2 corresponds to Channel 2 (Arduino A1).
            // -----------------------------------------------------------------
            S_RD_REQ: begin
                adc_read    <= 1'b1;
                adc_address <= current_ch ? 3'd2 : 3'd1; // Address 1 or 2
                state       <= S_WAIT_RD;
            end

            // -----------------------------------------------------------------
            // Wait for waitrequest=0, latch data, then switch channel.
            // -----------------------------------------------------------------
            S_WAIT_RD: begin
                if (!adc_waitrequest) begin
                    adc_read <= 1'b0;
                    if (current_ch == 1'b0)
                        joy_left  <= decode_joy(adc_readdata[11:0]);
                    else
                        joy_right <= decode_joy(adc_readdata[11:0]);

                    current_ch <= ~current_ch; // alternate channels
                    state      <= S_IDLE;
                end
            end

            default: state <= S_IDLE;

        endcase
    end
end

endmodule