`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/06/2024 07:52:46 PM
// Design Name: 
// Module Name: MIPS_32_PIPE
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module MIPS_32_PIPE(CLK1,CLK2);

 input CLK1,CLK2;
  reg [31:0] PC, IF_ID_IR,IF_ID_NPC;
  reg [31:0] ID_EX_IR,ID_EX_NPC,ID_EX_A,ID_EX_B,ID_EX_Imm;
  reg [2:0] ID_EX_Type,EX_MEM_Type,MEM_WB_Type;
  reg [31:0] EX_MEM_IR,EX_MEM_ALUOut,EX_MEM_B;
  reg          EX_MEM_cond;
  reg [31:0] MEM_WB_IR,MEM_WB_ALUOut,MEM_WB_LMD;
  
  reg [31:0] Reg [31:0]; //32x 32-bit register bank
  reg[31:0] Mem [0:1023]; // 1024 x 32 memory 
  parameter ADD=6'b000000,SUB=6'b000001,AND=6'b000010,OR=6'b000011,SLT=6'b000100,MUL=6'b000101,
  HLT=6'b111111,LW=6'b001000,SW=6'b001001,ADDI=6'b001010,SUBI=6'b001011,SLTI=6'b001100,
  BNEQZ=6'b001101,BEQZ=6'b001110;
 //TYPE instruction
 parameter RR_ALU =3'b000,RM_ALU=3'b001,LOAD=3'b010,STORE=3'b011,BRANCH=3'b100,HALT=3'b101;
 
 reg HALTED;//set after HLT instruction is completed (in WB Stage)
 
 reg TAKEN_BRANCH;//Required to disable instructions after branch
 
 always @(posedge CLK1) //Instruction Fecth (or) IF Stage
  if(HALTED == 0)
   begin
     if(((EX_MEM_IR[31:26] == BEQZ) && (EX_MEM_cond == 1)) || 
        ((EX_MEM_IR[31:26] == BNEQZ) && (EX_MEM_cond == 0)))
       begin
       IF_ID_IR <= #2 Mem[EX_MEM_ALUOut];
       TAKEN_BRANCH <= #2 1'b1;
       IF_ID_NPC <= #2 EX_MEM_ALUOut + 1;
       PC <= #2 EX_MEM_ALUOut + 1;
       end        
     else
      begin
       IF_ID_IR <= #2 Mem[PC];
       IF_ID_NPC <= #2 PC + 1;
       IF_ID_NPC <= #2 PC + 1;
       end
     end    
     
     always @ (posedge CLK2)//ID or Instruction Decode Stage 
      if (HALTED ==0)
      begin 
        if (IF_ID_IR[25:21] == 5'b00000) ID_EX_A <=0;//R0 = 0 special register 
        else ID_EX_A <= #2 Reg[IF_ID_IR[25:21]]; //source regsister 1 aka rs
        
        if (IF_ID_IR[20:16] == 5'b00000) ID_EX_B <=0;
        else ID_EX_B <= #2 Reg[IF_ID_IR[20:16]]; //source register 2 aka rt 
        
        ID_EX_NPC <= #2 IF_ID_NPC;
        ID_EX_IR <= #2 IF_ID_IR;
        ID_EX_Imm <= #2 {{16{IF_ID_IR[15]}},{IF_ID_IR[15:0]}};//Immediate value with 16 bit padding for
        
        case (IF_ID_IR[31:26])
         ADD,SUB,AND,OR,SLT,MUL: ID_EX_Type <= #2 RR_ALU;
         ADDI,SUBI,SLTI:         ID_EX_Type <= #2 RM_ALU;
         LW:                     ID_EX_Type <= #2 LOAD;
         SW:                     ID_EX_Type <= #2 STORE;
         BNEQZ,BEQZ:             ID_EX_Type <= #2 BRANCH;
         HLT:                    ID_EX_Type <= #2 HALT;
         default:                ID_EX_Type <= #2 HALT;  // invalid opcode
         
        endcase
       end   
       
       always@ (posedge CLK1) //EX or Execution Stage
        if (HALTED == 0)
        begin 
         EX_MEM_Type <= #2 ID_EX_Type;
         EX_MEM_IR <= #2 ID_EX_IR;
         TAKEN_BRANCH <= #2 0;
         
         case (ID_EX_Type)
          RR_ALU: begin
                     case (ID_EX_IR[31:26]) //opcode 
                      ADD: EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_B;
                      SUB: EX_MEM_ALUOut <= #2 ID_EX_A - ID_EX_B;
                      AND: EX_MEM_ALUOut <= #2 ID_EX_A & ID_EX_B;
                      OR: EX_MEM_ALUOut <= #2 ID_EX_A | ID_EX_B;
                      SLT: EX_MEM_ALUOut <= #2 ID_EX_A < ID_EX_B;
                      MUL: EX_MEM_ALUOut <= #2 (ID_EX_A) * (ID_EX_B);
                      default: EX_MEM_ALUOut <= #2 32'hxxxxxxxx;
                      endcase
                   end   
          RM_ALU: begin 
                    case (ID_EX_IR[31:26]) //opcode 
                     ADDI: EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_Imm;
                     SUBI: EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_Imm;
                     SLTI: EX_MEM_ALUOut <= #2 ID_EX_A < ID_EX_Imm;
                     default: EX_MEM_ALUOut <= 32'hxxxxxxxx;
                     endcase 
                   end 
          LOAD,STORE:
                  begin 
                    EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_Imm;
                    EX_MEM_ALUOut <= #2 ID_EX_B;
                  end
          BRANCH: begin 
                      EX_MEM_ALUOut <= #2 ID_EX_NPC + ID_EX_Imm;
                      EX_MEM_cond <= #2 (ID_EX_A == 0);
                  end 
               
         endcase
       end     
       
       always @(posedge CLK2)//MEM Stage 
         if (HALTED == 0)
         begin 
          MEM_WB_Type <= #2 EX_MEM_Type;
          MEM_WB_IR <= #2 EX_MEM_IR;
          
          case (EX_MEM_Type)
           RR_ALU,RM_ALU:
                      MEM_WB_ALUOut <= #2 EX_MEM_ALUOut;
                      
           LOAD:      MEM_WB_LMD <= #2 Mem[EX_MEM_ALUOut];
           STORE:     if  (TAKEN_BRANCH == 0) // Disable write
                          Mem[EX_MEM_ALUOut] <= #2 EX_MEM_B;
           endcase
          end   
          
          always @(posedge CLK1) //WB or write back stage
            begin
              if(TAKEN_BRANCH == 0) //Disable write if branch taken 
              case (MEM_WB_Type)
               RR_ALU: Reg[MEM_WB_IR[15:11]] <= #2 MEM_WB_ALUOut; //Destination Register or rd
               
               RM_ALU: Reg[MEM_WB_IR[20:16]] <= #2 MEM_WB_ALUOut; //source register 2 or register b  
               
               LOAD:   Reg[MEM_WB_IR[20:16]] <= #2 MEM_WB_LMD; // source register 2 or register rb
               
               HALT: HALTED <= #2 1'b1;
               endcase 
              end
   endmodule           
                   
