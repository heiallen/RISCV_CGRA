

wire [31:0] rv32_imm = ({32{rv32_imm_sel_i}} & rv32_i_imm)
                    |   ({32{rv32_imm_sel_s}} & rv32_s_imm)
                    |   ({32{rv32_imm_sel_b}} & rv32_b_imm)
                    |   ({32{rv32_imm_sel_u}} & rv32_u_imm)
                    |   ({32{rv32_imm_sel_j}} & rv32_j_imm);