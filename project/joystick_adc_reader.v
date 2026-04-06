module joystick_adc_reader #(
    parameter THRESH_HIGH = 12'd3352,   // > 2.0 V  → DOWN (joy = 01)
    parameter THRESH_LOW  = 12'd2482    // < 1.3 V  → UP   (joy = 10)
)(
    input  wire        clk,
    input  wire        rst,

    output reg         adc_write,
    output reg  [31:0] adc_writedata,
    output reg  [2:0]  adc_address,
    output reg         adc_read,
    input  wire [31:0] adc_readdata,
    input  wire        adc_waitrequest,

    output reg  [1:0]  joy_left,    // channel 1
    output reg  [1:0]  joy_right,   // channel 2

    // Raw 12-bit ADC sample outputs (for debug display)
    output reg [11:0]  adc_raw_left,
    output reg [11:0]  adc_raw_right
);

// FSM States
localparam S_IDLE      = 3'd0;
localparam S_WR_CMD    = 3'd1;   // write channel index to addr 0
localparam S_WAIT_WR   = 3'd2;   // hold write until waitrequest deasserts
localparam S_RD_REQ    = 3'd3;   // assert read to address based on channel
localparam S_WAIT_RD   = 3'd4;   // hold read until waitrequest deasserts, sample data

reg [2:0] state;
reg       current_ch;   // 0 = left joystick (ADC Address 1), 1 = right (ADC Address 2)

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

// FSM
always @(posedge clk) begin
    if (rst) begin
        state <= S_IDLE;
        current_ch <= 1'b0;
        adc_write <= 1'b0;
        adc_read <= 1'b0;
        adc_writedata <= 32'd0;
        adc_address <= 3'd0;
        joy_left <= 2'b00;
        joy_right <= 2'b00;
        adc_raw_left  <= 12'd0;
        adc_raw_right <= 12'd0;
    end else begin
        case (state)

            S_IDLE: begin
                adc_write <= 1'b0;
                adc_read <= 1'b0;
                state <= S_WR_CMD;
            end

            S_WR_CMD: begin
                adc_write <= 1'b1;
                adc_address <= 3'd0;
                adc_writedata <= {29'd0, 2'b0, current_ch};  // channel 1 or 2
                state <= S_WAIT_WR;
            end

            S_WAIT_WR: begin
                if (!adc_waitrequest) begin
                    adc_write <= 1'b0;
                    state <= S_RD_REQ;
                end
            end

            S_RD_REQ: begin
                adc_read <= 1'b1;
                adc_address <= current_ch ? 3'd2 : 3'd1; // Address 1 or 2
                state <= S_WAIT_RD;
            end

            S_WAIT_RD: begin
                if (!adc_waitrequest) begin
                    adc_read <= 1'b0;
                    if (current_ch == 1'b0) begin
                        joy_left     <= decode_joy(adc_readdata[11:0]);
                        adc_raw_left <= adc_readdata[11:0];
                    end else begin
                        joy_right     <= decode_joy(adc_readdata[11:0]);
                        adc_raw_right <= adc_readdata[11:0];
                    end

                    current_ch <= ~current_ch;
                    state <= S_IDLE;
                end
            end

            default: state <= S_IDLE;

        endcase
    end
end

endmodule