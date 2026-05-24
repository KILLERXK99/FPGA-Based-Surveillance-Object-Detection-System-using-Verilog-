`timescale 1ns / 1ps

module ov7670_capture(
    input pclk,
    input vsync,
    input href,
    input [7:0] d,
    output reg [17:0] addr,
    output reg [11:0] dout,
    output reg we
);
    reg [15:0] d_latch;
    reg href_latch;
    reg vsync_latch;
    reg writing;
    
    // Explicit X/Y tracking
    reg [9:0] col;
    reg [8:0] row;

    always @(posedge pclk) begin
        href_latch <= href;
        vsync_latch <= vsync;
        d_latch[7:0] <= d; 
        
        if (vsync_latch == 1'b1) begin
            col <= 0;
            row <= 0;
            addr <= 18'd0;
            we <= 1'b0;
            writing <= 1'b0;
                
        end else if (href_latch == 1'b1) begin
            if (writing == 1'b1) begin
                // Assemble to 12-bit RGB444 (Latched to prevent color noise)
                dout <= { d_latch[15:12], d_latch[10:7], d_latch[4:1] };
                
                // Write only valid QVGA pixels
                if (col < 320 && row < 240) begin
                    // Math: row * 320 + col  ==> (row * 256) + (row * 64) + col
                    addr <= {row[7:0], 8'b0} + {row[7:0], 6'b0} + col[8:0];
                    we <= 1'b1;
                end else begin
                    we <= 1'b0;
                end
                
                col <= col + 1;
                writing <= 1'b0; 
            end else begin
                d_latch[15:8] <= d_latch[7:0]; 
                writing <= 1'b1;               
                we <= 1'b0;
            end
        end else begin
            // We are in H-Blank. Advance the row counter safely.
            we <= 1'b0;
            writing <= 1'b0; 
            if (col > 0) begin
                row <= row + 1;
                col <= 0;
            end
        end
    end
endmodule