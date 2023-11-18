`timescale 1ns/1ns
////////////////////////////////////////////////////////////////////////////////
//Note that this is the template. You will need to make some changes, especially to verify
//the modifications you're doing in the lab (for MULT16 instruction, for the LEDs, for the HALT, etc.)
/////////////////////////////////////////////////////////////////////////////////
//Note this is your top module for simulation
////////////////////////////////////////////////////////////////////////////////
module MIPS_Testbench ();
    reg CLK;
    reg RST;
    wire CS;
    wire WE;
    wire [31:0] Mem_Bus;
    wire [6:0] Address;
    
    integer i;
    parameter N = 10;
    reg[31:0] expected[N:1];
    
    initial
    begin
        CLK = 0;
    end
    
	//This will need to change when you add more ports to the processor.
    Complete_MIPS uProc_Inst(CLK, RST, Address, Mem_Bus); 
    
    always
    begin
        #5 CLK = !CLK;
    end
    
    initial begin
		//Will need to change this as well depending upon the instructions you have in your instruction file
        expected[1] = 32'h00000006; // $1 content=6 decimal
        expected[2] = 32'h00000012; // $2 content=18 decimal
        expected[3] = 32'h00000018; // $3 content=24 decimal
        expected[4] = 32'h0000000C; // $4 content=12 decimal
        expected[5] = 32'h00000002; // $5 content=2
        expected[6] = 32'h00000016; // $6 content=22 decimal
        expected[7] = 32'h00000001; // $7 content=1
        expected[8] = 32'h00000120; // $8 content=288 decimal
        expected[9] = 32'h00000003; // $9 content=3
        expected[10] = 32'h00412022; // $10 content=5th instr
        CLK = 0;
    end
    
    
    always
    begin
        RST <= 1'b1; //reset the processor
    
        //Notice that the memory is initialized in the in the memory module not here (scroll down)    
        @(posedge CLK);
        @(posedge CLK);
        // driving reset low here puts processor in normal operating mode
        
		RST = 1'b0;
    
        /* add your testing code here */
        // you can add in a 'Halt' signal here as well to test Halt operation
        // you will be verifying your program operation using the
        // waveform viewer and/or self-checking operations
        for(i = 1; i <= N; i = i+1) 
        begin
            @(posedge uProc_Inst.WE); // When a store word is executed
            @(negedge CLK);
            if (Mem_Bus != expected[i])
            begin
                $display("Output mismatch: got %d, expect %d", Mem_Bus, expected[i]);
            end
        end
        
        $display("TEST COMPLETE");
        $stop;
    end
    
endmodule

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

module Complete_MIPS(CLK, RST, A_Out, D_Out);
  // Will need to be modified to add functionality like adding the HALT operation and exposing $1.
  // THIS IS YOUR TOP MODULE for implementation. YOU DEFINE WHAT SIGNALS YOU NEED TO INPUT AND OUTPUT
    input CLK;
    input RST;
    output [6:0] A_Out;
    output [31:0] D_Out;
    
    wire CS, WE;
    wire [6:0] ADDR;
    wire [31:0] Mem_Bus;
	
	assign A_Out = ADDR;
    assign D_Out = Mem_Bus;
    
    MIPS CPU(CLK, RST, CS, WE, ADDR, Mem_Bus);
    Memory MEM(CS, WE, CLK, ADDR, Mem_Bus);

endmodule

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

module Memory(CS, WE, CLK, ADDR, Mem_Bus);
    input CS;
    input WE;
    input CLK;
    input [6:0] ADDR;
    inout [31:0] Mem_Bus;
    
    reg [31:0] data_out;
    reg [31:0] RAM [0:127]; //128 location for 32bits each
    
    
    initial //is this synthesizable?
    begin
    /* Write your readmemh code here */
    $readmemh("C:\\Users\\kingh\\Downloads\\lab4_instruction.txt", RAM);
    end
    
	//Chip Select 1, 2 why?
    assign Mem_Bus = ((CS == 1'b0) || (WE == 1'b1)) ? 32'bZ : data_out;
    
	//Keep this negedge. Do not change it. it'sactually wrong, might cause timing issue.
    always @(negedge CLK)
    begin
        if((CS == 1'b1) && (WE == 1'b1))
            RAM[ADDR] <= Mem_Bus[31:0];
        
        data_out <= RAM[ADDR];
    end
endmodule

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
//Register file
module REG(CLK, RegW, DR, SR1, SR2, Reg_In, ReadReg1, ReadReg2); //DR:Destination Register1,2, SR: Source Register (Three Register the RF need)
    input CLK;
    input RegW;
    input [4:0] DR;
    input [4:0] SR1;
    input [4:0] SR2;
    input [31:0] Reg_In;
    output reg [31:0] ReadReg1;
    output reg [31:0] ReadReg2;
    
    reg [31:0] REG [0:31];
    
    /*
	initial begin
        ReadReg1 = 0;
        ReadReg2 = 0;
    end
	*/
    
    always @(posedge CLK)
    begin
        if(RegW == 1'b1) // write
            REG[DR] <= Reg_In[31:0]; //small memory will map out by LUT, memory block will be toot large
        
        ReadReg1 <= REG[SR1];
        ReadReg2 <= REG[SR2];
    end
endmodule


///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

`define opcode instr[31:26]
`define sr1 instr[25:21]
`define sr2 instr[20:16]
`define f_code instr[5:0]
`define numshift instr[10:6]

module MIPS (CLK, RST, CS, WE, ADDR, Mem_Bus);
    input CLK, RST;
    output reg CS, WE;
    output [6:0] ADDR;
    inout [31:0] Mem_Bus;
    
    //special instructions (opcode == 000000), values of F code (bits 5-0):
    parameter add = 6'b100000;
    parameter sub = 6'b100010;
    parameter xor1 = 6'b100110;
    parameter and1 = 6'b100100;
    parameter or1 = 6'b100101;
    parameter slt = 6'b101010;
    parameter srl = 6'b000010;
    parameter sll = 6'b000000;
    parameter jr = 6'b001000;
    
    //non-special instructions, values of opcodes:
    parameter addi = 6'b001000;
    parameter andi = 6'b001100;
    parameter ori = 6'b001101;
    parameter lw = 6'b100011;
    parameter sw = 6'b101011;
    parameter beq = 6'b000100;
    parameter bne = 6'b000101;
    parameter j = 6'b000010;
    
    //instruction format
    parameter R = 2'd0;
    parameter I = 2'd1;
    parameter J = 2'd2;
    
    //internal signals
    reg [5:0] op, opsave;
    wire [1:0] format;
    reg [31:0] instr;
    reg [6:0] pc, npc;
    wire [31:0] imm_ext, alu_in_A, alu_in_B, reg_in, readreg1, readreg2;
    wire [31:0] alu_result_save;
    reg alu_or_mem, alu_or_mem_save, regw, writing, reg_or_imm, reg_or_imm_save;
    reg fetchDorI;
    wire [4:0] dr;
    reg [2:0] state, nstate;
    
    //combinational (same as the block diagram)
    assign imm_ext = (instr[15] == 1)? {16'hFFFF, instr[15:0]} : {16'h0000, instr[15:0]};//Sign extend immediate field
    assign dr = (format == R)? instr[15:11] : instr[20:16]; //Destination Register MUX (MUX1)
    assign alu_in_A = readreg1;
    assign alu_in_B = (reg_or_imm_save)? imm_ext : readreg2; //ALU MUX (MUX2)
    assign reg_in = (alu_or_mem_save)? Mem_Bus : alu_result_save; //Data MUX (MUX3)
    assign format = (`opcode == 6'd0)? R : ((`opcode == 6'd2)? J : I);
    assign Mem_Bus = (writing)? readreg2 : 32'bZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ;
    
    //drive memory bus only during writes
    assign ADDR = (fetchDorI)? pc : alu_result_save[6:0]; //ADDR Mux
    
    //Register file instance
    REG Register(CLK, regw, dr, `sr1, `sr2, reg_in, readreg1, readreg2);
    
    //ALU instance
    ALU ALUnit(CLK, RST, opsave, instr, alu_in_A, alu_in_B, alu_result_save);
    
    /*
	initial begin
        op = and1; opsave = and1;
        state = 3'b0; nstate = 3'b0;
        alu_or_mem = 0;
        regw = 0;
        fetchDorI = 0;
        writing = 0;
        reg_or_imm = 0; reg_or_imm_save = 0;
        alu_or_mem_save = 0;
    end
	*/
    
    always @(*)
    begin
        fetchDorI = 0; CS = 0; WE = 0; regw = 0; writing = 0; //default assignments
        npc = pc; op = jr; reg_or_imm = 0; alu_or_mem = 0; nstate = 3'd0;
        
        case (state)
            0: 
            begin //Fetch
                npc = pc + 7'd1; CS = 1; nstate = 3'd1;
                fetchDorI = 1;
            end
            
            1: 
            begin //Decode
                nstate = 3'd2; reg_or_imm = 0; alu_or_mem = 0;
                if (format == J) 
                begin //jump, and finish
                    npc = instr[6:0];
                    nstate = 3'd0;
                end
                else if (format == R) //register instructions
                      = `f_code;
                else if (format == I) 
                begin //immediate instructions
                    reg_or_imm = 1;
                    if(`opcode == lw) 
                    begin
                        op = add; //why op=add for lw? add the offset with the SR content
                        alu_or_mem = 1;
                    end
                    else if ((`opcode == lw)||(`opcode == sw)||(`opcode == addi)) op = add;
                    else if ((`opcode == beq)||(`opcode == bne)) 
                    begin
                        op = sub; //why op=sub for branch? 
                        reg_or_imm = 0;
                    end
                    else if (`opcode == andi) op = and1;
                    else if (`opcode == ori) op = or1;
                end
            end
            
            2: 
            begin //Execute
                nstate = 3'd3;
                if (((alu_in_A == alu_in_B)&&(`opcode == beq)) || ((alu_in_A != alu_in_B)&&(`opcode == bne))) 
                begin
                    npc = pc + imm_ext[6:0];
                    nstate = 3'd0;
                end
                else if ((`opcode == bne)||(`opcode == beq)) nstate = 3'd0;
                else if (opsave == jr) 
                begin
                    npc = alu_in_A[6:0];
                    nstate = 3'd0;
                end
            end
            
            3: 
            begin //prepare to write to Memory
                nstate = 3'd0;
                if ((format == R)||(`opcode == addi)||(`opcode == andi)||(`opcode == ori)) regw = 1;
                else if (`opcode == sw) 
                begin
                    CS = 1;
                    WE = 1;
                    writing = 1;
                end
                else if (`opcode == lw) 
                begin
                    CS = 1;
                    nstate = 3'd4;
                end
            end
            
            4: //WB
            begin
                nstate = 3'd0;
                CS = 1;
                if (`opcode == lw) regw = 1;
            end
        endcase
    end //always
        
    always @(posedge CLK) 
    begin
    
        if (RST) 
        begin
            state <= 3'd0;
            pc <= 7'd0;
        end
        else 
        begin
            state <= nstate;
            pc <= npc;
        end
        
        if(state == 3'd0)
            instr <= Mem_Bus;
        if (state == 3'd1) 
        begin
            opsave <= op;
            reg_or_imm_save <= reg_or_imm;
            alu_or_mem_save <= alu_or_mem;
        end
        
        
    end //always

endmodule


module ALU(clk, rst, op, instr, alu_in_A, alu_in_B, alu_result);
    input clk;
    input rst;
    input [5:0] op;    
	input [31:0] instr;
    input [31:0] alu_in_A;
    input [31:0] alu_in_B;
    output reg [31:0] alu_result;
    
    parameter add  = 6'b100000;
    parameter sub  = 6'b100010;
    parameter xor1 = 6'b100110;
    parameter and1 = 6'b100100;
    parameter or1  = 6'b100101;
    parameter slt  = 6'b101010;
    parameter srl  = 6'b000010;
    parameter sll  = 6'b000000;
    
    
    always @(posedge clk) 
    begin
        if (rst)
            alu_result <= 0;
        else 
        begin
            if      (op == and1) alu_result <= alu_in_A & alu_in_B;
            else if (op == or1)  alu_result <= alu_in_A | alu_in_B;
            else if (op == add)  alu_result <= alu_in_A + alu_in_B;
            else if (op == sub)  alu_result <= alu_in_A - alu_in_B;
            else if (op == srl)  alu_result <= alu_in_B >> `numshift; // this is where instr[10:6] is used
            else if (op == sll)  alu_result <= alu_in_B << `numshift;
            else if (op == slt)  alu_result <= (alu_in_A < alu_in_B)? 32'd1 : 32'd0;                    
            else if (op == xor1) alu_result <= alu_in_A ^ alu_in_B;	
            else alu_result <= 0;
        end
    end
    
endmodule