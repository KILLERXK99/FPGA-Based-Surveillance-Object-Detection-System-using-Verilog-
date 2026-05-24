`timescale 1ns / 1ps

module top_module(
    input sys_clock,       // 100MHz Nexys 4 Clock
    input i,               // Reset/Resend button
    // Camera interface (PMOD pins)
    input pclk,
    input vsync,
    input href,
    input [7:0] d,
    output sioc,
    inout siod,
    output reset,
    output pwdn,
    output xclk,
    // VGA output to monitor
    output [3:0] vga_red,
    output [3:0] vga_green,
    output [3:0] vga_blue,
    output vga_hsync,
    output vga_vsync,
    output config_finished
);

    wire clk_50, clk_25;
    wire resend_debounced;
    
    // BRAM Signals
    wire [18:0] write_addr, read_addr;
    wire [3:0] write_data, read_data;
    wire we_bram;

    // Buffer the incoming PCLK. Essential for stability when using Pmods.
    wire pclk_buf;
    BUFG pclk_buffer (
        .I(pclk),
        .O(pclk_buf)
    );

    // 1. Clocking Wizard (50MHz for controller, 25MHz for VGA read)
    clk_wiz_0 clock_gen (
        .clk_in1(sys_clock),
        .clk_out1(clk_50),
        .clk_out2(clk_25)
    );

    // 2. Debounce reset button
    debounce db_inst (
        .clk(clk_50),
        .i(i),
        .o(resend_debounced)
    );

    // 3. Controller (Provides full RGB565 configuration list)
    ov7670_controller ctrl_inst (
        .clk(clk_50),
        .resend(resend_debounced),
        .config_finished(config_finished),
        .sioc(sioc),
        .siod(siod),
        .reset(reset),
        .pwdn(pwdn),
        .xclk(xclk)
    );

    // 4. Capture (UPDATED TIMING to fix diagonal roll)
    ov7670_capture cap_inst (
        .pclk(pclk_buf), // Use the buffered clock
        .vsync(vsync),
        .href(href),
        .d(d),
        .addr(write_addr),
        .dout(write_data),
        .we(we_bram)
    );

    // 5. Block Memory Generator (BRAM stores RGB444 pixels)
    blk_mem_gen_0 bram_inst (
        .clka(pclk_buf), // Write clock is buffered PCLK
        .wea(we_bram),
        .addra(write_addr),
        .dina(write_data),
        .clkb(clk_25),   // Read clock is stable internal 25MHz
        .addrb(read_addr),
        .doutb(read_data)
    );

    // 6. VGA (UPDATED robust 640x480 timing for 1080p compatibility)
    ov7670_vga vga_inst (
        .clk25(clk_25),
        .frame_pixel(read_data),
        .vga_red(vga_red),
        .vga_green(vga_green),
        .vga_blue(vga_blue),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .frame_addr(read_addr)
    );

endmodule