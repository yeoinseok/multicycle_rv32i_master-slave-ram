`timescale 1ns / 1ps
`include "define.vh"
module rv32i_cpu (
    input         clk,
    input         rst,
    input  [31:0] instr_data,
    input  [31:0] bus_rdata,
    input         bus_ready,
    output [31:0] instr_addr,
    output        bus_wreq,
    output        bus_rreq,
    output [ 2:0] o_funct3,
    output [31:0] bus_addr,
    output [31:0] bus_wdata
);

    logic pc_en, rf_we, branch, alu_src, jal, jalr;
    logic [2:0] rfwd_src;
    logic [3:0] alu_control;
    control_unit U_CONTROL_UNIT (
        .clk        (clk),
        .rst        (rst),
        .funct7     (instr_data[31:25]),
        .funct3     (instr_data[14:12]),
        .ready      (bus_ready),
        .opcode     (instr_data[6:0]),
        .pc_en      (pc_en),              // for multi cycle Fetch : pc
        .rf_we      (rf_we),
        .jal        (jal),
        .jalr       (jalr),
        .branch     (branch),
        .alu_src    (alu_src),
        .alu_control(alu_control),
        .rfwd_src   (rfwd_src),
        .o_funct3   (o_funct3),
        .dwe        (bus_wreq),
        .dre        (bus_rreq)
    );
    rv32i_datapath U_DATAPATH (.*);
endmodule
module control_unit (
    input              clk,
    input              rst,
    input              ready,
    input        [6:0] funct7,
    input        [2:0] funct3,
    input        [6:0] opcode,
    output logic       pc_en,
    output logic       rf_we,
    output logic       jal,
    output logic       jalr,
    output logic       branch,
    output logic       alu_src,
    output logic [3:0] alu_control,
    output logic [2:0] rfwd_src,
    output logic [2:0] o_funct3,
    output logic       dwe,
    output logic       dre

);
    // Control unit Multi cycle Stage
    typedef enum {
        FETCH,
        DECOCE,
        EXECUTE,
        EXE_R,
        EXE_I,
        EXE_S,
        EXE_B,
        EXE_L,
        EXE_J,
        EXE_JL,
        EXE_U,
        EXE_UA,
        MEM,
        MEM_S,
        MEM_L,
        WB
    } state_e;

    state_e c_state, n_state;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= FETCH;
        end else begin
            c_state <= n_state;
        end
    end

    // next CL
    always_comb begin
        n_state = c_state;
        case (c_state)
            FETCH: begin
                n_state = DECOCE;
            end
            DECOCE: begin
                n_state = EXECUTE;
            end
            EXECUTE: begin
                case (opcode)
                    `JL_TYPE, `J_TYPE, `UA_TYPE, `UL_TYPE,`B_TYPE, `I_TYPE, `R_TYPE: begin
                        n_state = FETCH;
                    end
                    `S_TYPE: begin
                        n_state = MEM;
                    end
                    `IL_TYPE: begin
                        n_state = MEM;
                    end
                endcase
            end
            MEM: begin
                case (opcode)
                    `S_TYPE: begin
                        if (ready) begin
                            n_state = FETCH;
                        end
                    end
                    `IL_TYPE: n_state = WB;
                endcase
            end
            WB: begin
                if (ready) begin
                    n_state = FETCH;

                end
            end

        endcase
    end

    // output CL
    always_comb begin
        pc_en       = 1'b0;
        rf_we       = 1'b0;
        jal         = 1'b0;
        jalr        = 1'b0;
        branch      = 1'b0;
        alu_src     = 1'b0;
        alu_control = 4'b0000;
        rfwd_src    = 3'b000;
        o_funct3    = 3'b000;  // for S type , IL type
        dwe         = 1'b0;  // for s type, IL type
        dre         = 1'b0;
        case (c_state)
            FETCH: begin
                pc_en = 1'b1;
            end
            DECOCE: begin
            end
            EXECUTE: begin
                case (opcode)
                    `R_TYPE: begin
                        rf_we       = 1'b1;  // next state FETCH
                        alu_src     = 1'b0;
                        alu_control = {funct7[5], funct3};
                    end
                    `I_TYPE: begin
                        rf_we   = 1'b1;  // next state FETCH
                        alu_src = 1'b1;
                        if (funct3 == 3'b101)
                            alu_control = {funct7[5], funct3};  // SRL, SRA
                        else alu_control = {1'b0, funct3};
                    end
                    `B_TYPE: begin
                        branch      = 1'b1;
                        alu_src     = 1'b0;
                        alu_control = {1'b0, funct3};
                    end
                    `S_TYPE: begin
                        alu_src     = 1'b1;
                        alu_control = 4'b0000;  // add for dwaddr
                    end
                    `IL_TYPE: begin
                        alu_src     = 1'b1;
                        alu_control = 4'b0000;  // add for dwaddr
                    end
                    `UL_TYPE: begin
                        rf_we    = 1'b1;  // next state FETCH
                        rfwd_src = 3'b010;
                    end
                    `UA_TYPE: begin
                        rf_we    = 1'b1;  // next state FETCH
                        rfwd_src = 3'b011;
                    end
                    `JL_TYPE, `J_TYPE: begin
                        rf_we = 1'b1;  // next state FETCH
                        jal   = 1'b1;
                        if (opcode == `JL_TYPE) jalr = 1'b1;  // JALR
                        else jalr = 1'b0;  // JAL
                        rfwd_src = 3'b100;
                    end
                endcase
            end
            MEM: begin
                o_funct3 = funct3;
                if (opcode == `S_TYPE) dwe = 1'b1;
            end
            WB: begin
                // IL type
                rf_we    = 1'b1;  // next state FETCH
                rfwd_src = 3'b001;
                dre      = 1'b1;
            end
        endcase
    end

    //    always_comb begin
    //        rf_we       = 1'b0;
    //        jal         = 1'b0;
    //        jalr        = 1'b0;
    //        branch      = 1'b0;
    //        alu_src     = 1'b0;
    //        alu_control = 4'b0000;
    //        rfwd_src    = 3'b000;
    //        o_funct3    = 3'b000;
    //        dwe         = 1'b0;
    //        case (opcode)
    //            `R_TYPE: begin  // R-type, to write register file, alu_control == {funct7[5], funct3}
    //                rf_we       = 1'b1;
    //                jal         = 1'b0;
    //                jalr        = 1'b0;
    //                branch      = 1'b0;
    //                alu_src     = 1'b0;
    //                alu_control = {funct7[5], funct3};
    //                rfwd_src    = 3'b000;
    //                o_funct3    = 3'b000;
    //                dwe         = 1'b0;
    //            end
    //            `B_TYPE: begin
    //                rf_we       = 1'b0;
    //                jal         = 1'b0;
    //                jalr        = 1'b0;
    //                branch      = 1'b1;
    //                alu_src     = 1'b0;
    //                alu_control = {1'b0, funct3};
    //                rfwd_src    = 3'b000;
    //                o_funct3    = 3'b000;
    //                dwe         = 1'b0;
    //            end
    //            `S_TYPE: begin
    //                rf_we       = 1'b0;
    //                jal         = 1'b0;
    //                jalr        = 1'b0;
    //                branch      = 1'b0;
    //                alu_src     = 1'b1;
    //                alu_control = 4'b0000;
    //                rfwd_src    = 3'b000;
    //                o_funct3    = funct3;
    //                dwe         = 1'b1;
    //            end
    //            `IL_TYPE: begin
    //                rf_we       = 1'b1;
    //                jal         = 1'b0;
    //                jalr        = 1'b0;
    //                branch      = 1'b0;
    //                alu_src     = 1'b1;
    //                alu_control = 4'b0000;
    //                rfwd_src    = 3'b001;
    //                o_funct3    = funct3;
    //                dwe         = 1'b0;
    //            end
    //            `I_TYPE: begin
    //                rf_we   = 1'b1;
    //                jal     = 1'b0;
    //                jalr    = 1'b0;
    //                branch  = 1'b0;
    //                alu_src = 1'b1;
    //                if (funct3 == 3'b101) alu_control = {funct7[5], funct3};
    //                else alu_control = {1'b0, funct3};
    //                rfwd_src = 3'b000;
    //                o_funct3 = funct3;
    //                dwe      = 1'b0;
    //            end
    //            `UL_TYPE: begin
    //                rf_we       = 1'b1;
    //                jal         = 1'b0;
    //                jalr        = 1'b0;
    //                branch      = 1'b0;
    //                alu_src     = 1'b0;
    //                alu_control = 4'b0000;
    //                rfwd_src    = 3'b010;  // lui
    //                o_funct3    = 3'b000;
    //                dwe         = 1'b0;
    //            end
    //            `UA_TYPE: begin
    //                rf_we       = 1'b1;
    //                jal         = 1'b0;
    //                jalr        = 1'b0;
    //                branch      = 1'b0;
    //                alu_src     = 1'b0;
    //                alu_control = 4'b0000;
    //                rfwd_src    = 3'b011;  // auipc
    //                o_funct3    = 3'b000;
    //                dwe         = 1'b0;
    //            end
    //            `JL_TYPE, `J_TYPE: begin
    //                rf_we = 1'b1;
    //                jal   = 1'b1;
    //                if (opcode == `JL_TYPE) jalr = 1'b1;  // JALR
    //                else jalr = 1'b0;  // JAL
    //                branch      = 1'b0;
    //                alu_src     = 1'b0;
    //                alu_control = 4'b0000;
    //                rfwd_src    = 3'b100;
    //                o_funct3    = funct3;
    //                dwe         = 1'b0;
    //            end
    //        endcase
    //    end

endmodule
