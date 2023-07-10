import uvm_pkg::*;
import enums_pkg::*;

`include "uvm_macros.svh"

/***********************************************
* TRANSACTION SECTION 
***********************************************/
class data_transaction extends uvm_sequence_item;
    rand logic[7:0] data_a; 	// Data bits A
    rand logic[7:0] data_b; 	// Data bits b
    rand OP_CODE op;

    logic[7:0] res;		// Result
    logic carry;		// Carryout

    // Constructor
    function new(string name = "");
        super.new(name); // super call is not really needed but helps make code more readable. If not present
                         // then compiler will insert super.new call automatically with NO arguments
    endfunction

    `uvm_object_utils(data_transaction);
    // Function that randomizes the data inputs and OP code. 
    // Have to do this because .randomize() requires an additional license...
    function void randomize_custom();
        data_a = $urandom_range(0,256);
        data_b = $urandom_range(0,256);

        op = NOP;
        op = op.next($urandom_range(1,9));
    endfunction : randomize_custom

    // Copy function since we arent using the field automation macros
    // Creates a deep copy of the function passed in
    virtual function void do_copy(uvm_object rhs);
        data_transaction RHS;
        super.do_copy(rhs);
        $cast(RHS, rhs);
        data_a = RHS.data_a;
        data_b = RHS.data_b;
        op = RHS.op;

        res = RHS.res;
        carry = RHS.carry;
    endfunction : do_copy

    // Print contents of data_transaction object
    virtual function string convert2string();
        return $sformatf("data_a: 0x%0h data_b: 0x%0h op: %s carry: %b result: %b", data_a, data_b, op, carry, res);
    endfunction
endclass : data_transaction


/***********************************************
* SEQUENCES(s)
***********************************************/
// Execute 8 runs
class ALLOP_test_seq extends uvm_sequence #(data_transaction);
    // Register object with the factory
    `uvm_object_utils(ALLOP_test_seq)
    
    // Declare transaction
    data_transaction tr;
    int number_of_ops;

    // Good practice not to give a default name since the seq will always be given a name when created
    function new(string name = "");
        super.new(name); 
    endfunction
    
    // Create a transaction using the factory and randomize the data while constraining the put/get signals
    // Use start_item() to tell the sequencer a transaction is ready to be sent
    // finish_item() sends the transaction to the sequencer

    // Here we create a new data_transaction every loop (performance cost) but we could also move it outside the loop
    // and reuse the transaction. Have to ensure that the transaction is done being used, or that any analysis components
    // have made a copy of it, before moving on to the next transaction. Remember that transactions are passed around as
    // pointers!
    task body();
        if ( !uvm_config_db #(int)::get(get_sequencer(), "", "ALU_op_number", number_of_ops) )
            `uvm_error(get_type_name(), "Failed to get config object")

        for (int i = 0; i < number_of_ops; i++) begin 
            tr = data_transaction::type_id::create("data_transaction");
            start_item(tr);
            tr.randomize_custom();

            `uvm_info("DATA_TRANSACTION_SEND", tr.convert2string(), UVM_MEDIUM);
            finish_item(tr);
        end
    endtask
endclass : ALLOP_test_seq


/***********************************************
* SEQUENCER 
***********************************************/
class data_sequencer extends uvm_sequencer #(data_transaction);
	// Register the sequencer component with the factory
	`uvm_component_utils(data_sequencer)
  
	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction
endclass : data_sequencer


/***********************************************
* DRIVER 
***********************************************/
class data_driver extends uvm_driver #(data_transaction);
    // Register the driver with the factory
    `uvm_component_utils(data_driver)

    // Declare the interface and transaction object
    virtual dut_if driver_dut_if; 
    data_transaction tr; 
    
    function new(string name, uvm_component parent);
        super.new(name, parent); 
    endfunction
   
    // Grab the interface from the DB config
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(virtual dut_if)::get(this, "", "dut_if", driver_dut_if))
            `uvm_error(get_type_name(), "data_driver uvm_config_db::get failed")
    endfunction

    // At the posedge of the clk, request a new transaction using blocking function get_next_item()
    // This blocks the sequencer from sending another item until item_done() is called.
    task send_data();
        forever begin
            @(posedge driver_dut_if.clk);
            seq_item_port.get_next_item(tr);
            `uvm_info("DATA_TRANSACTION_RECIEVED", tr.convert2string(), UVM_MEDIUM);
            driver_dut_if.data_a <= tr.data_a;
            driver_dut_if.data_b <= tr.data_b;
            driver_dut_if.op <= tr.op;
            seq_item_port.item_done();
        end
    endtask
    
    task run_phase(uvm_phase phase);
        send_data();
    endtask 
endclass : data_driver

/***********************************************
* MONITOR 
***********************************************/

// Monitor that watches the interface for put requests
class result_monitor extends uvm_monitor;
    // Register 'result' monitor with factory
    `uvm_component_utils(result_monitor)
    
    // Declare a handle for the interface and the transaction
    virtual dut_if dut_monitor_if;
    data_transaction tr;

    // Declare the parametrized analysis port that will handle data_transaction types
  	uvm_analysis_port #(data_transaction) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent); 
    endfunction

    // Build the analysis port and retrieve the interface from the DB config
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("result_monitor_ap", this);

        if (!uvm_config_db #(virtual dut_if)::get(this, "", "dut_if", dut_monitor_if))
            `uvm_error(get_type_name(), "result_monitor uvm_config_db::get failed")
    endfunction

    // Build a transaction (using the factory), and send transaction to analysis port.
    // Only creates a transaction if the op is not NOP
    task run_phase(uvm_phase phase);
    	forever begin
            @(posedge dut_monitor_if.clk);
			if(dut_monitor_if.op != NOP) begin
                tr = data_transaction::type_id::create("tr");
                tr.data_a = dut_monitor_if.data_a;
                tr.data_b = dut_monitor_if.data_b;
                tr.op = dut_monitor_if.op;
                tr.res = dut_monitor_if.res;
                tr.carry = dut_monitor_if.carry;
                `uvm_info("MON_TRANS_DTCTD", tr.convert2string(), UVM_MEDIUM);
                ap.write(tr);
            end
    	end 
    endtask
endclass : result_monitor


/***********************************************
* SUBSCRIBER(S) 
***********************************************/
class alu_printer extends uvm_subscriber #(data_transaction);
    // Register agent with the factory
    `uvm_component_utils(alu_printer)

    
    function new(string name, uvm_component parent);
        super.new(name, parent);         
    endfunction

    virtual function void write(data_transaction t);
        `uvm_info("SUB_RECEIVED_TRANS", t.convert2string(), UVM_MEDIUM);
    endfunction
endclass : alu_printer //alu_printer extends uvm_subscriber


/***********************************************
* AGENTS 
***********************************************/

// Active agent (Contains sequencer, driver, and a monitor)
class alu_agent extends uvm_agent;
    // Register agent with the factory
    `uvm_component_utils(alu_agent)
    
    // Declare the AP which will pass the broadcasted transactions from the monitor AP to the env hierarchy
    // No need to declare it new again since we are only linking the handle.
  	uvm_analysis_port #(data_transaction) ap; 

    // Declare the components
    data_driver data_driver_h; 
    data_sequencer data_sequencer_h;
    result_monitor result_monitor_h;    
 
    function new(string name, uvm_component parent);
        super.new(name, parent); 
    endfunction

    // Build the components using the factory
    function void build_phase(uvm_phase phase);
        data_driver_h       = data_driver::type_id::create("data_driver_h", this); 
        data_sequencer_h    = data_sequencer::type_id::create("data_sequencer_h", this); 
        result_monitor_h    = result_monitor::type_id::create("result_monitor_h", this);
    endfunction

    // Connect the driver and sequencer.
    // Next, connect the analysis port of the monitor with the analysis port of the enviroment
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        data_driver_h.seq_item_port.connect(data_sequencer_h.seq_item_export);
        ap = result_monitor_h.ap; 
    endfunction
endclass : alu_agent


/***********************************************
* ENVIROMENT 
***********************************************/
class my_environment extends uvm_env;
	// Register enviroment component with factory
    `uvm_component_utils(my_environment);
    
    // Declare the agent, scoreboard, coverage component handles
    alu_agent alu_agent_h; 
    alu_printer printer_h;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    // Build the agents, scoreboard using the factory
    // Build the TLM FIFOs using class new constructor
    function void build_phase(uvm_phase phase);
        alu_agent_h = alu_agent::type_id::create("alu_agent_h", this);
        printer_h = alu_printer::type_id::create("printer_h", this);
    endfunction

    // If we have a scoreboard or coverage collector we will connect them here in the connect_phase()
    function void connect_phase(uvm_phase phase);
        alu_agent_h.ap.connect(printer_h.analysis_export);
    endfunction
endclass : my_environment


/***********************************************
* VIRTUAL SEQUENCES 
***********************************************/
class my_virtual_seq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(my_virtual_seq)
    
    // Declare the sequences to run
    ALLOP_test_seq ALLOP_test_seq_h;

    // Declare the sequencers the sequences will run on 
    data_sequencer data_sqr_h;
    
    function new(string name = "");
        super.new(name);
    endfunction

    // Create the sequences using the factory 
    task pre_body();
        ALLOP_test_seq_h = ALLOP_test_seq::type_id::create("ALLOP_test_seq_h");   
    endtask

    // Assign the sequences to the sequencers
    task body();  
        ALLOP_test_seq_h.start(data_sqr_h); 
    endtask

endclass : my_virtual_seq

/***********************************************
* TESTS 
***********************************************/

// How to select different test cases in Questa:
// vsim top +UVM_TESTNAME=<name of first test>
// vsim top +UVM_TESTNAME=<name of second test>

class top_base_test extends uvm_test;
    // Register the component with the factory
    `uvm_component_utils(top_base_test)
    
    // Declare the enviroment, vseq
    my_environment env_h;
	my_virtual_seq vseq_h;

    int num_op = 8;

    function new(string name= "top_base_test", uvm_component parent);   
        super.new(name, parent); 
    endfunction

    // Build the enviroment, vseq using the factory methods
    function void build_phase(uvm_phase phase);
        env_h = my_environment::type_id::create("env_h", this);
        vseq_h = my_virtual_seq::type_id::create("vseq_h");

        uvm_config_db #(int)::set(this, "*", "ALU_op_number", num_op);

        $display("top_base exiting build phase");
    endfunction

    // raise the objections so that the simulation knows when to start (raise) and when to stop (drop)
    // Call the virtual sequence and start
    task run_phase(uvm_phase phase);
        //vseq_h = my_virtual_seq::type_id::create("vseq_h");
        phase.raise_objection(this);

        // Link the vseq sequencers with the sequencer(s) in the agents
        vseq_h.data_sqr_h = env_h.alu_agent_h.data_sequencer_h;
        vseq_h.start(null);
        phase.drop_objection(this);
    endtask
endclass : top_base_test
