import enums_pkg::*;

/***********************************************
* interface 
***********************************************/

// Signals are declared as logic so that X,Z values can be caught in the simulation
interface dut_if ();
    logic clk;
    logic[7:0] data_a; 	// Data bits A
    logic[7:0] data_b; 	// Data bits B
    OP_CODE op;  	// OP Code
    
    logic[7:0] res;		// Result
    logic carry;		// Carryout
endinterface : dut_if