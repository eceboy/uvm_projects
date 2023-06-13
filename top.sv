import uvm_pkg::*;
import top_pkg::*;
import enums_pkg::*;

`timescale 1ns/10ps

/***********************************************
* top 
***********************************************/
module top;
	// Declare the interface
	dut_if inf();

	// Declare the DUT and link the connections to the interface
	alu dut (
			.data_a(inf.data_a),
			.data_b(inf.data_b),
			.op(inf.op),
			.res(inf.res),
			.carry(inf.carry)
	);

	initial begin
		// Throw the interface into the DB so that other components may access it
		// Note: We can make the DB entry accesible by certain components only.
		uvm_config_db #(virtual dut_if)::set(null, "*", "dut_if", inf);

		// run_test is a UVM built in function that goes and launches a test from our tests.sv file
		// You may hardcode a test here or you may just simply do run_test(). If you go this route you must pass in a test
		// using +UVM_TESTNAME=<test_name>
        run_test("top_base_test");
	end

	initial begin
		// Clock generation
		forever #5 inf.clk = !inf.clk;
	end

	initial begin
		inf.op = NOP;
		inf.clk = 1'b0;
	end
endmodule : top
