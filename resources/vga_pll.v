
// vga_pll.v
// PLL configuration for VGA clock generation

module vga_pll (
    areset,
    inclk0,
    c0,
    locked
);

    input   areset;
    input   inclk0;
    output  c0;
    output  locked;

    // PLL configuration parameters
    // This configuration divides the input clock by 2 to get 25 MHz
    altpll altpll_component (
        .areset (areset),
        .inclk ({1'b0, inclk0}),
        .clk (c0),
        .locked (locked)
        // Additional configuration parameters can be set here
    );

    defparam
        altpll_component.bandwidth_type = "AUTO",
        altpll_component.clk0_divide_by = 2,
        altpll_component.clk0_duty_cycle = 50,
        altpll_component.clk0_multiply_by = 1,
        altpll_component.clk0_phase_shift = "0",
        altpll_component.inclk0_input_frequency = 20000,
        altpll_component.intended_device_family = "MAX 10",
        altpll_component.operation_mode = "NORMAL";

endmodule

