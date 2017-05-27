//Subject:     CO project 4
//--------------------------------------------
//Student: 0411276 Chen Yi An
//Student: 0413335 Kuo Yi Lin
//--------------------------------------------
module Pipe_CPU_1(
                clk_i,
                rst_i
                );
/****************************************
I/O ports
****************************************/
input         clk_i;
input         rst_i;


/****************************************
Internal signal
****************************************/

/**** 
IF stage 
****/
wire [32-1:0] pc_next,    pc_data ;
wire [32-1:0] pc_add4_IF;
wire PCSrc; 

/**** 
ID stage 
****/

//control signal
wire RW_ID_muxOut,MR_ID_muxOut,MW_ID_muxOut;
    //EX
wire AluSrc_c_ID;
wire [4-1:0] AluOp_c_ID;
wire RegDst_c_ID;
    //MEM
wire Branch_c_ID;
wire MemRead_c_ID,   MemWrite_c_ID;  
wire MemToReg_c_ID;
    //WB
wire RegWrite_c_ID ;

/**** 
EX stage 
****/
wire RW_EX_muxOut,MR_EX_muxOut,MW_EX_muxOut;
//control signal
    //EX
wire AluSrc_c_EX;
wire [4-1:0]AluOp_c_EX;
wire RegDst_c_EX;
    //MEM
wire Branch_c_EX;
wire MemRead_c_EX,   MemWrite_c_EX;  
wire MemToReg_c_EX;
    //WB
wire RegWrite_c_EX ;

/**** 
MEM stage 
****/

//control signal
//MEM
wire MemRead_c_MEM,   MemWrite_c_MEM; 
wire MemToReg_c_MEM; 
//EX
wire Branch_c_MEM;
//WB
wire RegWrite_c_MEM;

/**** 
WB stage 
****/

//control signal
//MEM
wire MemToReg_c_WB;
//WB
wire RegWrite_c_WB ;


//grouped by usage 
wire [32-1:0]   regWB_data,     //The data writed back to RegisterFile, if any. 
                MemRead_data_MEM, MemRead_data_WB, 
                aluResult_EX, aluResult_MEM,aluResult_WB,
                aluSrc1,        aluSrc2, //input for alu. 
                aluSrc2_reg_EX, aluSrc2_reg_MEM,  
                shiftout; 

wire [32-1:0] pc_add4_ID,pc_add4_EX;
wire [32-1:0] pc_add4_MEM,pc_add4_WB;//For debug usage 
wire [32-1:0] branch_addr_EX,branch_addr_MEM;//Mux_PC_Source's input
wire [32-1:0] RF_outRS_ID, RF_outRS_EX;
wire [32-1:0] RF_outRT_ID, RF_outRT_EX, RF_outRT_MEM;
wire [32-1:0] immdt16_SE32_ID, immdt16_SE32_EX; 

wire [32-1:0] instr_ID;//values from instruction memory according to it's address
wire [1:0]	ForwardA, ForwardB; 
wire 		pcWrite,	alu_zero_EX,	alu_zero_MEM; 

wire [4-1:0]      aluOpCode_EX;      //The operation code that ALU get from ALU_Control  
wire [5-1:0]      writeReg_addr_EX,writeReg_addr_MEM, writeReg_addr_WB ;  //The address of the reg that need to be write back, if any.

//Indicate the meaning of the sub-sections in the instruction field     
wire    [32-1:0] instr_IF; 
wire    [5-1:0] instr_rs_ID,  instr_rt_ID,  instr_rd_ID, instr_shamt_ID;
wire    [5-1:0] instr_rs_EX,  instr_rt_EX,  instr_rd_EX, instr_shamt_EX;
wire    [6-1:0] instr_op,instr_funct_ID, instr_funct_EX;
wire    [16-1:0] instr_immdt;
wire 	IF_Flush, ID_Flush, EX_Flush ; 

assign { instr_op, instr_rs_ID, instr_rt_ID, instr_rd_ID, instr_shamt_ID, instr_funct_ID } = instr_ID;
assign instr_immdt = instr_ID[15:0];

/**
IF stage: Instruction Fetch
*/

MUX_2to1 #(.size(32)) Mux_PC_Source(
    .data0_i(pc_add4_IF),
    .data1_i(branch_addr_MEM),
    .select_i(PCSrc),
    .data_o(pc_next)
);

ProgramCounter PC(
        .clk_i(clk_i),      
        .rst_i (rst_i),
        .pcWrite(pcWrite),
        .pc_in_i(pc_next),
        .pc_out_o(pc_data) 
        );

Adder PC4_adder(
        .src1_i(32'd4),     
        .src2_i(pc_data),     
        .sum_o(pc_add4_IF)    
        );

Instr_Memory IM(
        .addr_i(pc_data),  
        .instr_o(instr_IF)    
        );

//IF stage END

Pipe_Reg #(.size(64)) IF_ID(
    .clk_i(clk_i),
	.rst_i( rst_i),
    //.rst_i( rst_i | ~IF_Flush), //connect to IF flush
    .data_i({   
        pc_add4_IF,
        instr_IF
    }),
    .data_o({
        pc_add4_ID,
        instr_ID
    })
);


Hazard_detection_Unit Hazard_detection_Unit(
	.EX_MemRead(MemRead_c_EX),
	.ID_RegisterRs(instr_rs_ID),
	.ID_RegisterRt(instr_rt_ID),
	.EX_RegisterRt(instr_rt_EX),
	.MEM_Branch(Branch_c_MEM),
	.PCWrite(pcWrite),
	.IF_Flush(IF_Flush),
	.ID_Flush(ID_Flush),
	.EX_Flush(EX_Flush)
);


/**
ID stage : Instruction Decoding
*/
Reg_File RF(
        .clk_i(clk_i),      
        .rst_i(rst_i) ,     
        .RSaddr_i(instr_rs_ID) ,  
        .RTaddr_i(instr_rt_ID) ,  
        .RDaddr_i(writeReg_addr_WB) ,  
        .RDdata_i(regWB_data)  , 
        .RegWrite_i (RegWrite_c_WB),
        .RSdata_o(RF_outRS_ID) ,  
        .RTdata_o(RF_outRT_ID)   
        );
        
Decoder Control(
        //input 
        .instr_op_i(instr_op),

        //output 
        .ALU_op_o(AluOp_c_ID),   
        .ALUSrc_o(AluSrc_c_ID),   
        .RegDst_o(RegDst_c_ID),   
        .Branch_o(Branch_c_ID),//need change width to 1-bit
        .MemToReg_o(MemToReg_c_ID),
        .RegWrite_o(RegWrite_c_ID), 
        .MemRead_o(MemRead_c_ID),
        .MemWrite_o(MemWrite_c_ID)   
        );

Sign_Extend Sign_Extend(
        .data_i(instr_immdt),
        .data_o(immdt16_SE32_ID)
        );

//ID stage END

//The instructions berecome nop 
//after clear these three control signal
MUX_2to1 #(.size(3)) ID_EX_pipeLineSrc(
    .data0_i({
        RegWrite_c_ID,
        MemRead_c_ID,
        MemWrite_c_ID
    }),
    .data1_i(3'b0),
	.select_i(1'b0),
    //.select_i(ID_Flush),
    .data_o({
        RW_ID_muxOut,
        MR_ID_muxOut,
        MW_ID_muxOut
    })
);

Pipe_Reg #(.size(165)) ID_EX(
    .clk_i(clk_i),
    .rst_i(rst_i),//connect to hazard detection unit after implemented it
    .data_i({   
        //control signals
        AluSrc_c_ID,            //1
        AluOp_c_ID,             //4
        RegDst_c_ID,            //1
        Branch_c_ID,            //1
        MemToReg_c_ID,          //1
        
        RW_ID_muxOut,           //1
        MR_ID_muxOut,           //1
        MW_ID_muxOut,           //1

        //data fields 
        pc_add4_ID,             //32
        RF_outRS_ID,            //32
        RF_outRT_ID,            //32
        immdt16_SE32_ID,        //32
        instr_rs_ID,            //5
        instr_rt_ID,            //5
        instr_rd_ID,            //5
        instr_funct_ID,         //6
        instr_shamt_ID          //5            
    }),
    .data_o({
        /*control signal*/
        AluSrc_c_EX,
        AluOp_c_EX,
        RegDst_c_EX,
        Branch_c_EX,
        MemToReg_c_EX,

        RegWrite_c_EX,
        MemRead_c_EX,
        MemWrite_c_EX,
        
        pc_add4_EX,
        RF_outRS_EX,
        RF_outRT_EX,
        immdt16_SE32_EX,
        instr_rs_EX,
        instr_rt_EX,
        instr_rd_EX,
        instr_funct_EX,
        instr_shamt_EX
    })
);



/**
EX stage : Execution  
*/
MUX_2to1 #( .size(5)) Mux_Write_Reg(
    .data0_i(instr_rt_EX),
    .data1_i(instr_rd_EX),
    .select_i( RegDst_c_EX ),
    .data_o( writeReg_addr_EX)
);

Shift_Left_Two_32 Shifter(
        .data_i(immdt16_SE32_EX),
        .data_o(shiftout)
        ); 		

Adder Branch_adder(
        .src1_i(pc_add4_EX),     
        .src2_i(shiftout),     
        .sum_o(branch_addr_EX)      
        );

//Forwarding control 
Forwarding_Unit  Forwarding_Unit(
	.EX_RegisterRs(instr_rs_EX),
	.EX_RegisterRt(instr_rt_EX),
	.MEM_RegisterRd(writeReg_addr_MEM),
	.WB_RsgisterRd(writeReg_addr_WB),
	.MEM_RegWrite(RegWrite_c_MEM),
	.WB_RegWrite(RegWrite_c_WB),
	.ForwardA(ForwardA),
	.ForwardB(ForwardB)
);

MUX_3to1 #(.size(32)) Mux_ALUSrc1_forwarding(
    .data0_i( RF_outRS_EX),
    .data1_i( aluResult_MEM ),
    .data2_i( regWB_data ),
	.select_i(2'b00),
    //.select_i(ForwardA), //connedted from Frowarding Unit
	.data_o( aluSrc1)
);
MUX_3to1 #(.size(32)) Mux_ALUSrc2_forwarding(
    .data0_i( RF_outRT_EX ),
    .data1_i( aluResult_MEM),
    .data2_i( regWB_data ),
	.select_i(2'b00),
    //.select_i(ForwardB),//connedted from Frowarding Unit
	 .data_o( aluSrc2_reg_EX)
);
MUX_2to1 #(.size(32)) Mux_ALUSrc2(
    .data0_i(aluSrc2_reg_EX),
    .data1_i(immdt16_SE32_EX),
    .select_i(AluSrc_c_EX),
    .data_o(aluSrc2)
);

ALU_Ctrl AC(
        .funct_i(instr_funct_EX),   
        .ALUOp_i(AluOp_c_EX),   
        .ALUCtrl_o(aluOpCode_EX) 
        );


ALU ALU(//need to know PC +4 
        .src1_i(aluSrc1),
        .src2_i(aluSrc2),
        .ctrl_i(aluOpCode_EX),
        .result_o(aluResult_EX),
        .shamt( instr_shamt_EX),
        .zero_o(alu_zero_EX)
        );

//EX stage END 

MUX_2to1 #(.size(3)) EX_MEM_pipeLineSrc(
    .data0_i({
        RegWrite_c_EX,
        MemRead_c_EX,
        MemWrite_c_EX
    }),
    .data1_i(3'b0),
	.select_i(1'b0),
    //.select_i(EX_Flush),
    .data_o({
        RW_EX_muxOut,
        MR_EX_muxOut,
        MW_EX_muxOut
    })
);

Pipe_Reg #(.size(171)) EX_MEM(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .data_i({   
        //control signals
        Branch_c_EX,                //1
        MemToReg_c_EX,              //1
        
        RW_EX_muxOut,               //1
        MR_EX_muxOut,               //1
        MW_EX_muxOut,               //1

        //data fields 
		pc_add4_EX,				//32
        aluResult_EX,               //32
        alu_zero_EX,                //1
        writeReg_addr_EX,           //5
        aluSrc2_reg_EX,             //32
        branch_addr_EX,             //32
		RF_outRT_EX			//32
    }),
    .data_o({
        /*control signals*/
        Branch_c_MEM,
        MemToReg_c_MEM,

        RegWrite_c_MEM,
        MemRead_c_MEM,
        MemWrite_c_MEM,
        
		pc_add4_MEM,
        aluResult_MEM,
        alu_zero_MEM,
        writeReg_addr_MEM,
        aluSrc2_reg_MEM, 
        branch_addr_MEM,
		RF_outRT_MEM
    })
);


/**
MEM stage : Memory 
*/
assign PCSrc = Branch_c_MEM && alu_zero_MEM; 

Data_Memory DM(
        .clk_i(clk_i),
        .addr_i(aluResult_MEM),
        .data_i(RF_outRT_MEM),
        .MemRead_i( MemRead_c_MEM),
        .MemWrite_i(MemWrite_c_MEM),
        .data_o(MemRead_data_MEM)        
);

//MEM stage END 

Pipe_Reg #(.size(103)) MEM_WB(
    .clk_i(clk_i),
    .rst_i(rst_i),// not completed yet
	 .data_i({   
        //control signals
        MemToReg_c_MEM,             //1
		RegWrite_c_MEM,			//1

        //data fields
		pc_add4_MEM,			//32
        writeReg_addr_MEM,          //5
        MemRead_data_MEM,           //32
        aluResult_MEM               //32
       //There should be a signal that give data to forwarding unit,
       //But I forgot what exactly it is.    
		  }),
    .data_o({
        /*decoder control signal*/
        MemToReg_c_WB,
		RegWrite_c_WB,
        
        //data Fields 
		pc_add4_WB,
        writeReg_addr_WB,
        MemRead_data_WB, 
        aluResult_WB
    })
);


/**
WB stage : Write Back
*/

MUX_2to1 #(.size(32)) Mux_WriteBack(
    .data0_i(aluResult_WB),
    .data1_i(MemRead_data_WB),
    .select_i(MemToReg_c_WB),
    .data_o(regWB_data)
);

//WB stage END 

endmodule
                  
