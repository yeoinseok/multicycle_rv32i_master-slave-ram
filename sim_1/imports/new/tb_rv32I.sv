`timescale 1ns / 1ps



module tb_rv32I();

    logic clk,rst;

     rv32I_mcu dut (
        .clk(clk),
        .rst(rst)
     );

    always #5 clk = ~clk;

    initial begin
        clk=0;
        rst =1;

        @(negedge clk);
        @(negedge clk);
        rst = 0;

        repeat(2000) @(negedge clk);
        $stop;
    end
endmodule
