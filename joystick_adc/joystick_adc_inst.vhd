	component joystick_adc is
		port (
			adc_0_adc_slave_write       : in  std_logic                     := 'X';             -- write
			adc_0_adc_slave_readdata    : out std_logic_vector(31 downto 0);                    -- readdata
			adc_0_adc_slave_writedata   : in  std_logic_vector(31 downto 0) := (others => 'X'); -- writedata
			adc_0_adc_slave_address     : in  std_logic_vector(2 downto 0)  := (others => 'X'); -- address
			adc_0_adc_slave_waitrequest : out std_logic;                                        -- waitrequest
			adc_0_adc_slave_read        : in  std_logic                     := 'X';             -- read
			clk_clk                     : in  std_logic                     := 'X';             -- clk
			reset_reset_n               : in  std_logic                     := 'X'              -- reset_n
		);
	end component joystick_adc;

	u0 : component joystick_adc
		port map (
			adc_0_adc_slave_write       => CONNECTED_TO_adc_0_adc_slave_write,       -- adc_0_adc_slave.write
			adc_0_adc_slave_readdata    => CONNECTED_TO_adc_0_adc_slave_readdata,    --                .readdata
			adc_0_adc_slave_writedata   => CONNECTED_TO_adc_0_adc_slave_writedata,   --                .writedata
			adc_0_adc_slave_address     => CONNECTED_TO_adc_0_adc_slave_address,     --                .address
			adc_0_adc_slave_waitrequest => CONNECTED_TO_adc_0_adc_slave_waitrequest, --                .waitrequest
			adc_0_adc_slave_read        => CONNECTED_TO_adc_0_adc_slave_read,        --                .read
			clk_clk                     => CONNECTED_TO_clk_clk,                     --             clk.clk
			reset_reset_n               => CONNECTED_TO_reset_reset_n                --           reset.reset_n
		);

