`timescale 1ns/10ps
`define CYCLE 10
`define PIXEL1     "./pattern/pixel_1.dat"  
`define PIXEL2     "./pattern/pixel_2.dat"  
`define PIXEL3     "./pattern/pixel_3.dat"  
`define EXPECT     "./pattern/out_golden.dat"

module tb();

	// parameter OUT_LENGTH    = 100;
	// parameter DATA_LENGTH   = OUT_LENGTH + 2;  // padding

	reg        clk, reset, mode;
	reg  [4:0] pixel_in0;
	reg  [4:0] pixel_in1;
	reg  [4:0] pixel_in2;
	wire [4:0] pixel_out;
    // wire       readable;
	
 //    reg  [4:0] out_mem    [0:OUT_LENGTH-1];
	// reg  [4:0] pixel1_mem [0:DATA_LENGTH-1];
	// reg  [4:0] pixel2_mem [0:DATA_LENGTH-1];
	// reg  [4:0] pixel3_mem [0:DATA_LENGTH-1];
	// reg  [4:0] out_temp;

	// reg        stop;
	// integer    i, j, out_f, err, pattern_num;
	// reg        over;

	Main_Ctrl_Unit mcu ( clk, reset, mode, pixel_in0, pixel_in1, pixel_in2, pixel_out );
	
	// initial	$readmemb (`PIXEL1,  pixel1_mem);
	// initial	$readmemb (`PIXEL2,  pixel2_mem);
	// initial	$readmemb (`PIXEL3,  pixel3_mem);
	// initial	$readmemb (`EXPECT,  out_mem);

	initial begin
		$dumpfile("MCU.fsdb");
     	$dumpvars;
    end

    initial begin
     	clk         = 1'b1;
     	reset       = 1'b0;
     	pixel_in0   = 5'd0;
		pixel_in1   = 5'd0;
		pixel_in2   = 5'd0;
     	// enable      = 1'b0;
     	// stop        = 1'b0;  
   		// over        = 1'b0;
   		// pattern_num = 0;
   		// err         = 0;
   		// i           = 0;
   		// j           = 0;
   		#2.5 reset  = 1'b1;
    	#2.5 reset  = 1'b0;
	end

	always begin #(`CYCLE/2) clk = ~clk; end

	initial begin
		#(`CYCLE)
		pixel_in0 = 5'd1;
		pixel_in1 = 5'd1;
		pixel_in2 = 5'd1;
		#(`CYCLE)
		pixel_in0 = 5'd2;
		pixel_in1 = 5'd2;
		pixel_in2 = 5'd2;
		#(`CYCLE)
		pixel_in0 = 5'd3;
		pixel_in1 = 5'd3;
		pixel_in2 = 5'd3;
		$finish;
	end

endmodule