`timescale 1ns / 1ps

module debounce(
    input clk,
    input i,
    output o
);
    reg [21:0] count;
    reg i_reg;
    reg out_reg;

    always @(posedge clk) begin
        if (i != i_reg) begin
            count <= 0;
            i_reg <= i;
        end else if (count == 22'd2500000) begin // 50ms at 50MHz
            out_reg <= i_reg;
            count <= count;
        end else begin
            count <= count + 1;
        end
    end

    assign o = out_reg;
endmodule