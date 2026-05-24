`timescale 1ns / 1ps

module ov7670_vga(
    input clk25,               
    input [11:0] frame_pixel,  
    output reg [3:0] vga_red,
    output reg [3:0] vga_green,
    output reg [3:0] vga_blue,
    output reg vga_hsync,
    output reg vga_vsync,
    output [17:0] frame_addr   
);
    localparam hRez = 640, hFP = 16, hSync = 96, hBP = 48, hTotal = 800;
    localparam vRez = 480, vFP = 10, vSync = 2,  vBP = 33, vTotal = 525;
    
    localparam hSyncStart = hRez + hFP; 
    localparam hSyncEnd   = hSyncStart + hSync;
    localparam vSyncStart = vRez + vFP;
    localparam vSyncEnd   = vSyncStart + vSync;

    reg [9:0] hCount = 0;
    reg [9:0] vCount = 0;
    wire blank = (hCount >= hRez || vCount >= vRez);
    
    // Divide counters by 2 to upscale 320x240 -> 640x480
    wire [8:0] hAddr = hCount[9:1];
    wire [7:0] vAddr = vCount[9:1];

    // Read Address math: vAddr * 320 + hAddr
    assign frame_addr = {vAddr, 8'b0} + {vAddr, 6'b0} + hAddr;

    always @(posedge clk25) begin
        if (hCount == hTotal - 1) begin
            hCount <= 0;
            if (vCount == vTotal - 1)
                vCount <= 0;
            else
                vCount <= vCount + 1;
        end else begin
            hCount <= hCount + 1;
        end

        vga_hsync <= (hCount >= hSyncStart && hCount < hSyncEnd) ? 1'b0 : 1'b1;
        vga_vsync <= (vCount >= vSyncStart && vCount < vSyncEnd) ? 1'b0 : 1'b1;

        if (blank) begin
            vga_red   <= 4'h0;
            vga_green <= 4'h0;
            vga_blue  <= 4'h0;
        end else begin
            vga_red   <= frame_pixel[11:8];
            vga_green <= frame_pixel[7:4];
            vga_blue  <= frame_pixel[3:0];
        end
    end
endmodule