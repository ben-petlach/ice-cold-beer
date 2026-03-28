	joystick_adc u0 (
		.adc_0_adc_slave_write       (<connected-to-adc_0_adc_slave_write>),       // adc_0_adc_slave.write
		.adc_0_adc_slave_readdata    (<connected-to-adc_0_adc_slave_readdata>),    //                .readdata
		.adc_0_adc_slave_writedata   (<connected-to-adc_0_adc_slave_writedata>),   //                .writedata
		.adc_0_adc_slave_address     (<connected-to-adc_0_adc_slave_address>),     //                .address
		.adc_0_adc_slave_waitrequest (<connected-to-adc_0_adc_slave_waitrequest>), //                .waitrequest
		.adc_0_adc_slave_read        (<connected-to-adc_0_adc_slave_read>),        //                .read
		.clk_clk                     (<connected-to-clk_clk>),                     //             clk.clk
		.reset_reset_n               (<connected-to-reset_reset_n>)                //           reset.reset_n
	);

