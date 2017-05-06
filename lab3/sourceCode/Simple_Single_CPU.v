//Subject:     CO project 3 - ALU Controller
//--------------------------------------------
//Student: 0411276 Chen Yi An
//Student: 0413335 Kuo Yi Lin
//--------------------------------------------
module Simple_Single_CPU(
                clk_i,
		rst_i,

		);
		
//I/O port
input         clk_i;
input         rst_i;


//Internal Signles

                //Control signals generated by Decoder 
wire            RegWrite_ctrl,  RegDst_ctrl,
                AluSrc_ctrl,    Branch_ctrl;  
wire [2:0]      AluOp_ctrl; 

wire [31:0]     regWB_data,     //The data writed back to RegisterFile, if any.  
                aluSrc1,        aluSrc2_reg,   aluSrc2, //input for alu.
                instruction_data,       //values from instruction memory according to it's address   
                branch_addr,            //Mux_PC_Source's input                
                pc_next,        pc_data,        pc_shft4, 
                immdt16_SE32,   //32bit Signed Extened value derived from the 16bit immediate one    
                shiftout;
        
wire            alu_zero,       //Indicate the value of alu is zero or not (for branch usage )  
                pcBranch_sel;   //Selecting value for Mux_PC_Source 

wire [3:0]      aluOpCode;      //The operation code that ALU get from ALU_Control  
wire [4:0]      writeReg_addr;  //The address of the reg that need to be write back, if any.
    
//New control lines --------
//MemToReg_o
//BranchType_o
//MemRead_o
//MemWrite_o
//--------------------------     

//Indicate the meaning of the sub-sections in the instruction field     
wire    [4:0] instr_rs,  instr_rt,  instr_rd, instr_shamt;
wire    [5:0] instr_op,instr_funct;
wire    [15:0] instr_immdt;

assign { instr_op, instr_rs, instr_rt, instr_rd, instr_shamt, instr_funct } = instruction_data;
assign instr_immdt = instruction_data[15:0];
assign pcBranch_sel = alu_zero & Branch_ctrl;

//Greate componentes
ProgramCounter PC(
        .clk_i(clk_i),      
        .rst_i (rst_i),     
        .pc_in_i(pc_next) ,   
        .pc_out_o(pc_data) 
        );

Adder Adder1(
        .src1_i(32'd4),     
        .src2_i(pc_data),     
        .sum_o(pc_shft4)    
        );

Instr_Memory IM(
        .pc_addr_i(pc_data),  
        .instr_o(instruction_data)    
        );

MUX_2to1 #(.size(5)) Mux_Write_Reg(
        .data0_i(instr_rt),
        .data1_i(instr_rd),
        .select_i(RegDst_ctrl),
        .data_o(writeReg_addr)
        );	
	
Reg_File RF(
        .clk_i(clk_i),      
	.rst_i(rst_i) ,     
        .RSaddr_i(instr_rs) ,  
        .RTaddr_i(instr_rt) ,  
        .RDaddr_i(writeReg_addr) ,  
        .RDdata_i(regWB_data)  , 
        .RegWrite_i (RegWrite_ctrl),
        .RSdata_o(aluSrc1) ,  
        .RTdata_o(aluSrc2_reg)   
        );
	
Decoder Decoder(
        //input 
        .instr_op_i(instr_op), 
        //output 
        .RegWrite_o(RegWrite_ctrl), 
        .ALU_op_o(AluOp_ctrl),   
        .ALUSrc_o(AluSrc_ctrl),   
        .RegDst_o(RegDst_ctrl),   
        .Branch_o(Branch_ctrl)   
        );

ALU_Ctrl AC(
        .funct_i(instr_funct),   
        .ALUOp_i(AluOp_ctrl),   
        .ALUCtrl_o(aluOpCode) 
        );
	
Sign_Extend SE(
        .data_i(instr_immdt),
        .data_o(immdt16_SE32)
        );

MUX_2to1 #(.size(32)) Mux_ALUSrc(
        .data0_i(aluSrc2_reg),
        .data1_i(immdt16_SE32),
        .select_i(AluSrc_ctrl),
        .data_o(aluSrc2)
        );	
		
ALU ALU(
        .src1_i(aluSrc1),
        .src2_i(aluSrc2),
        .ctrl_i(aluOpCode),
        .result_o(regWB_data),
        .shamt( instr_shamt ),
        .zero_o(alu_zero)
        );

Adder Adder2(
        .src1_i(pc_shft4),     
        .src2_i(shiftout),     
        .sum_o(branch_addr)      
        );
		            
Shift_Left_Two_32 Shifter(
        .data_i(immdt16_SE32),
        .data_o(shiftout)
        ); 		
		
MUX_2to1 #(.size(32)) Mux_PC_Source(
        .data0_i(pc_shft4),
        .data1_i(branch_addr),
        .select_i(pcBranch_sel),
        .data_o(pc_next)
        );	

endmodule
		  


