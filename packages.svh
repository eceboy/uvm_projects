package enums_pkg;
    typedef enum bit[3:0] {NOP, OR, NOR, AND, NAND, XOR, ADD, SUB, SHIFTL, SHIFTR} OP_CODE;
endpackage : enums_pkg

package top_pkg;
    `include "uvm_alu_complete.sv"
endpackage : top_pkg