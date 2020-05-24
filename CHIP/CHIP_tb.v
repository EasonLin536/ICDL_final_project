`timescale 1ns/10ps
`define CYCLE 10
`define PIXEL0     "./pattern/pixel_0.dat"  
`define PIXEL1     "./pattern/pixel_1dat"  
`define PIXEL2     "./pattern/pixel_2.dat"
`define PIXEL3     "./pattern/pixel_3.dat"
`define PIXEL4     "./pattern/pixel_4.dat"
`define EXPECT     "./pattern/out_golden.dat"

module tb();

	reg        clk, reset, load_end;
	reg  [4:0] pixel_in0;
	reg  [4:0] pixel_in1;
	reg  [4:0] pixel_in2;
	reg  [4:0] pixel_in3;
	reg  [4:0] pixel_in4;
	wire       edge_out;
    
	integer k;
	
	CHIP chip (clk, reset, pixel_in0, pixel_in1, pixel_in2, pixel_in3, pixel_in4, edge_out, load_end, readable);

	initial begin
		$dumpfile("CHIP.fsdb");
     	$dumpvars;
    end

    initial begin
     	clk        = 1'b0;
     	reset      = 1'b0;
     	pixel_in0  = 5'd0;
		pixel_in1  = 5'd0;
		pixel_in2  = 5'd0;
		load_end   = 1'b0;
   		#2.5 reset = 1'b1;
    	#5 reset = 1'b0;
	end

	always begin #(`CYCLE/2) clk = ~clk; end

	initial begin
		for (k=0;k<400;k=k+1) begin
			if (k == 399) begin
				load_end = 1'b1;
			end

			if (k % 5 == 0) #(`CYCLE);
			
			if (k % 5 == 0) pixel_in0 = k[4:0];
			else if (k % 5 == 1) pixel_in1 = k[4:0];
			else if (k % 5 == 2) pixel_in2 = k[4:0];
			else if (k % 5 == 3) pixel_in3 = k[4:0];
			else pixel_in4 = k[4:0];
			
			
		end
		
		#(`CYCLE*1200);
		$finish;
	end

endmodule