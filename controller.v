`timescale 1ns / 1ps

module ov7670_controller(
    input clk,             
    input resend,          
    output reg config_finished, 
    output sioc,           
    inout siod,            
   
    output reset,          
    output pwdn,           
    output xclk            
);
    assign reset = 1'b1; 
    assign pwdn = 1'b0;  

    reg [1:0] xclk_div;
    reg [8:0] sccb_div;
    reg clk_sccb;
    reg xclk_reg;
    
    always @(posedge clk) begin
        xclk_div <= xclk_div + 1;
        xclk_reg <= xclk_div[0]; 
        
        sccb_div <= sccb_div + 1;
        if (sccb_div == 9'd249) begin 
            sccb_div <= 0;
            clk_sccb <= ~clk_sccb;
        end
    end
    assign xclk = xclk_reg;

    reg [15:0] sccb_data_in;
    reg [7:0] reg_index;

    always @(*) begin
        case(reg_index)
            8'd0  : sccb_data_in = 16'h1280; // COM7: Reset
            
            // 1. Mandatory Core Setup - QVGA
            8'd1  : sccb_data_in = 16'h1214; // COM7: QVGA mode + RGB
            8'd2  : sccb_data_in = 16'h40d0; // COM15: RGB565
            8'd3  : sccb_data_in = 16'h1100; // CLKRC: Use XCLK directly

            // 2. Enable scaling for stable 12.5MHz PCLK
            8'd4  : sccb_data_in = 16'h8c00; 
            8'd5  : sccb_data_in = 16'h0c04; // COM3: Enable scaling
            8'd6  : sccb_data_in = 16'h3e19; // COM14: Enable manual scaling, PCLK/2
            8'd7  : sccb_data_in = 16'h703A; 
            8'd8  : sccb_data_in = 16'h7135; 
            8'd9  : sccb_data_in = 16'h7211; // SCALING_DCWCTR
            8'd10 : sccb_data_in = 16'h73f0; // SCALING_PCLK_DIV

            8'd11 : sccb_data_in = 16'h13e7; 
            8'd12 : sccb_data_in = 16'h0000; 
            8'd13 : sccb_data_in = 16'h1000; 

            8'd14 : sccb_data_in = 16'h1713; 
            8'd15 : sccb_data_in = 16'h1801; 
            8'd16 : sccb_data_in = 16'h32b6; 
            8'd17 : sccb_data_in = 16'h1902; 
            8'd18 : sccb_data_in = 16'h1a7a; 
            8'd19 : sccb_data_in = 16'h030a; 

            8'd20 : sccb_data_in = 16'h1520; 
            8'd21 : sccb_data_in = 16'h3db4; 

            8'd22 : sccb_data_in = 16'hB084; 
            8'd23 : sccb_data_in = 16'h4fe3; 
            8'd24 : sccb_data_in = 16'h5003; 
            8'd25 : sccb_data_in = 16'h5100; 
            8'd26 : sccb_data_in = 16'h5201; 
            8'd27 : sccb_data_in = 16'h5394; 
            8'd28 : sccb_data_in = 16'h54b8; 
            8'd29 : sccb_data_in = 16'h581e; 

            8'd30 : sccb_data_in = 16'h13ef; 
            8'd31 : sccb_data_in = 16'h2495; 
            8'd32 : sccb_data_in = 16'h2533; 
            8'd33 : sccb_data_in = 16'h26e3; 

            8'd34 : sccb_data_in = 16'h2d00; 
            8'd35 : sccb_data_in = 16'h2e00; 
            8'd36 : sccb_data_in = 16'h2f3d; 
            8'd37 : sccb_data_in = 16'h30a5; 
            8'd38 : sccb_data_in = 16'h31d5; 
            8'd39 : sccb_data_in = 16'h3613; 
            8'd40 : sccb_data_in = 16'h6900; 
            8'd41 : sccb_data_in = 16'h6b0a; 
            8'd42 : sccb_data_in = 16'h3c78; 

            8'd43 : sccb_data_in = 16'h7A10; 
            8'd44 : sccb_data_in = 16'h7B10; 
            8'd45 : sccb_data_in = 16'h7C1A; 

            8'd46 : sccb_data_in = 16'hFFFF;
            default: sccb_data_in = 16'hFFFF;
        endcase
    end

    reg [3:0] state;
    reg [7:0] data_sr;    
    reg [5:0] bit_count;
    reg sda_out;
    reg sda_dir;          
    
    assign sioc = clk_sccb;
    assign siod = sda_dir ? sda_out : 1'bz;
    wire [7:0] cam_addr = 8'h42;

    localparam IDLE = 0, START = 1, WRITE_DEV = 2, WRITE_REG = 3, WRITE_DAT = 4, STOP = 5, DONE = 6;

    always @(negedge clk_sccb or posedge resend) begin
        if (resend) begin
            state <= IDLE;
            reg_index <= 0;
            config_finished <= 0;
            sda_dir <= 1;
            sda_out <= 1;
        end else begin
            case (state)
                IDLE: begin
                    sda_dir <= 1;
                    sda_out <= 1;
                    if (sccb_data_in != 16'hFFFF) begin
                        state <= START;
                    end else begin
                        state <= DONE;
                        config_finished <= 1;
                    end
                end
                
                START: begin
                    sda_out <= 0;
                    data_sr <= cam_addr;
                    bit_count <= 8;
                    state <= WRITE_DEV;
                end
                
                WRITE_DEV: begin
                    if (bit_count > 0) begin
                        sda_out <= data_sr[7];
                        data_sr <= {data_sr[6:0], 1'b0};
                        bit_count <= bit_count - 1;
                    end else begin
                        sda_dir <= 0; 
                        bit_count <= 8;
                        data_sr <= sccb_data_in[15:8]; 
                        state <= WRITE_REG;
                    end
                end
                
                WRITE_REG: begin
                    sda_dir <= 1;
                    if (bit_count > 0) begin
                        sda_out <= data_sr[7];
                        data_sr <= {data_sr[6:0], 1'b0};
                        bit_count <= bit_count - 1;
                    end else begin
                        sda_dir <= 0; 
                        bit_count <= 8;
                        data_sr <= sccb_data_in[7:0]; 
                        state <= WRITE_DAT;
                    end
                end
                
                WRITE_DAT: begin
                    sda_dir <= 1;
                    if (bit_count > 0) begin
                        sda_out <= data_sr[7];
                        data_sr <= {data_sr[6:0], 1'b0};
                        bit_count <= bit_count - 1;
                    end else begin
                        sda_dir <= 0; 
                        state <= STOP;
                    end
                end
                
                STOP: begin
                    sda_dir <= 1;
                    sda_out <= 1;
                    reg_index <= reg_index + 1;
                    state <= IDLE;
                end
                
                DONE: begin
                    config_finished <= 1;
                end
            endcase
        end
    end
endmodule