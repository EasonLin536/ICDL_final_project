`timescale 1ns/10ps
`define CYCLE 10
`define PIXEL0     "./pattern/pixel_in0.dat"  
`define PIXEL1     "./pattern/pixel_in1.dat"  
`define PIXEL2     "./pattern/pixel_in2.dat"
`define PIXEL3     "./pattern/pixel_in3.dat"
`define PIXEL4     "./pattern/pixel_in4.dat"
`define PIXEL_EXPECT "./pattern/nm_out.dat"
`define ANGLE_EXPECT "./pattern/sb_ang_out.dat"

module tb();

	parameter DATA_LENGTH = 80;
	parameter OUT_LENGTH  = 18*18;

	reg        clk, reset, load_end;
	reg  [4:0] pixel_in0;
	reg  [4:0] pixel_in1;
	reg  [4:0] pixel_in2;
	reg  [4:0] pixel_in3;
	reg  [4:0] pixel_in4;
	wire       edge_out;
	wire [4:0] debug_pixel;
	wire [1:0] debug_angle;
    
	reg  [4:0] pixel_mem  [0:OUT_LENGTH-1];
	reg  [4:0] angle_mem  [0:OUT_LENGTH-1];
	reg  [4:0] pixel0_mem [0:DATA_LENGTH-1];
	reg  [4:0] pixel1_mem [0:DATA_LENGTH-1];
	reg  [4:0] pixel2_mem [0:DATA_LENGTH-1];
	reg  [4:0] pixel3_mem [0:DATA_LENGTH-1];
	reg  [4:0] pixel4_mem [0:DATA_LENGTH-1];
	reg  [4:0] pixel_temp;
	reg  [4:0] angle_temp;

	reg        stop;
	integer    i, j, k, out_f, err, pattern_num;
	reg        over;

	CHIP chip (clk, reset, pixel_in0, pixel_in1, pixel_in2, pixel_in3, pixel_in4, edge_out, load_end, readable, debug_pixel, debug_angle);

	initial	$readmemb (`PIXEL0, pixel0_mem);
	initial	$readmemb (`PIXEL1, pixel1_mem);
	initial	$readmemb (`PIXEL2, pixel2_mem);
	initial	$readmemb (`PIXEL3, pixel3_mem);
	initial	$readmemb (`PIXEL4, pixel4_mem);
	initial	$readmemb (`PIXEL_EXPECT, pixel_mem);
	initial	$readmemb (`ANGLE_EXPECT, angle_mem);

	initial begin
		$dumpfile("CHIP.fsdb");
     	$dumpvars;
    end

    initial begin
     	clk         = 1'b0;
     	reset       = 1'b0;
     	stop        = 1'b0;  
   		over        = 1'b0;
   		pattern_num = 0;
   		err         = 0;
   		i           = 0;
   		j           = 0;
		load_end   = 1'b0;
   		#2.5 reset = 1'b1;
    	#5 reset = 1'b0;
	end

	always begin #(`CYCLE/2) clk = ~clk; end

	initial begin
		for (i=0;i<DATA_LENGTH;i=i+1) begin
			if (i==79) load_end = 1'b1;
			
			#(`CYCLE);
			
			pixel_in0 = pixel0_mem[i];
			pixel_in1 = pixel1_mem[i];
			pixel_in2 = pixel2_mem[i];
			pixel_in3 = pixel3_mem[i];
			pixel_in4 = pixel4_mem[i];
		end
		stop = 1;
	end

	always @(negedge clk) begin
		if (j < OUT_LENGTH && readable) begin
			pixel_temp = pixel_mem[j];
			angle_temp = angle_mem[j];
			j = j + 1;
		    if (debug_pixel !== pixel_temp) begin
		        $display("ERROR at %d:output %d !=expect %d ", pattern_num, debug_pixel, pixel_temp);
			    $fdisplay(out_f,"ERROR at %d:output %d !=expect %d ", pattern_num, debug_pixel, pixel_temp);
		        err = err + 1 ;
		    end
		    // if (debug_angle !== angle_temp) begin
		    //     $display("ERROR at %d:output %d !=expect %d ", pattern_num, debug_angle, angle_temp);
			   //  $fdisplay(out_f,"ERROR at %d:output %d !=expect %d ", pattern_num, debug_angle, angle_temp);
		    //     err = err + 1 ;
		    // end

		    pattern_num = pattern_num + 1; 
			if (pattern_num === OUT_LENGTH) over = 1'b1;
	    end
	end

	initial begin
	    @(posedge over)      
	    if (stop) begin
	       	$display("---------------------------------------------\n");
	       	if (err == 0)  begin
	          	$display("All data have been generated successfully!\n");
	          	$display("-------------------PASS-------------------\n");
	       	end
	       	else begin
	          	$display("There are %d errors!\n", err);
			end
	         $display("---------------------------------------------\n");
	    end
	    
	    #10 $finish;
	end

endmodule