import enums_pkg::*;

module alu (
	input logic[7:0] data_a, 	// Data bits A
	input logic[7:0] data_b, 	// Data bits B
	input OP_CODE op,  	        // OP Code
	output logic[7:0] res,		// Result
	output logic carry			// Carryout
);

// Calc carryout
assign carry = {{1'b0,data_a} + {1'b0,data_b}}[8];

always_comb begin
	case (op)
		NOP: res = 0;
		OR: res = data_a | data_b;
		NOR: res = ~(data_a | data_b);
		AND: res = data_a & data_b;
		NAND: res = ~(data_a & data_b);
		XOR: res = data_a ^ data_b;
		ADD: res = data_a + data_b;
		SUB: res = data_a - data_b;
		SHIFTL: res = data_a << 1;
		SHIFTR: res = data_a >> 1;
		default : res = 0;
	endcase
end

endmodule : alu