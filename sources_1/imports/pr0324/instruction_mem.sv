`timescale 1ns / 1ps

module instruction_mem (
    input  [31:0] instr_addr,
    output [31:0] instr_data
);

    logic [31:0] rom[0:127];

    initial begin
        $readmemh("U_APB_BRAM.mem",rom);
        //rom[0] = 32'h004182b3;  // ADD X5, X3, X4
        //rom[1] = 32'h00812123;  // SW x2, 2(x8), SW x2,x8,2
        //rom[2] = 32'h00212383;  // LW x7, X2, 2 ( daddress = x2 + 2)
        //rom[3] = 32'h00438413;  // ADDi X8, X7, 4
        //rom[4] = 32'h00840463;  // BEQ X8, X8, 8
        //rom[5] = 32'h004182b3;  // ADD X5, X3, X4
        //rom[6] = 32'h00812123;  // SW x2, 2(x8), SW x2,x8,2
        ////rom[1] = 32'h005201b3;
    end

    assign instr_data = rom[instr_addr[31:2]];

endmodule
