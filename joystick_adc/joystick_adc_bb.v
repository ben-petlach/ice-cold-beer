
module joystick_adc (
	adc_0_adc_slave_write,
	adc_0_adc_slave_readdata,
	adc_0_adc_slave_writedata,
	adc_0_adc_slave_address,
	adc_0_adc_slave_waitrequest,
	adc_0_adc_slave_read,
	clk_clk,
	reset_reset_n);	

	input		adc_0_adc_slave_write;
	output	[31:0]	adc_0_adc_slave_readdata;
	input	[31:0]	adc_0_adc_slave_writedata;
	input	[2:0]	adc_0_adc_slave_address;
	output		adc_0_adc_slave_waitrequest;
	input		adc_0_adc_slave_read;
	input		clk_clk;
	input		reset_reset_n;
endmodule
