`timescale 1ns/10ps
`define CYCLE 10
// modify pattern path
`define PIXEL0 "./pattern/pixel_in0.dat"  
`define PIXEL1 "./pattern/pixel_in1.dat"  
`define PIXEL2 "./pattern/pixel_in2.dat"
`define PIXEL3 "./pattern/pixel_in3.dat"
`define PIXEL4 "./pattern/pixel_in4.dat"
`define EXPECT "./pattern/out_golden.dat"
`define BIT_LENGTH 4

module tb();

	parameter INPUT_TILE  = 1350; // modify for # of input tile
	parameter DATA_LENGTH = 80 * INPUT_TILE;
	parameter OUT_LENGTH  = 18*18 * INPUT_TILE;

	reg        clk, reset, load_end;
	reg  [`BIT_LENGTH - 1:0] pixel_in0;
	reg  [`BIT_LENGTH - 1:0] pixel_in1;
	reg  [`BIT_LENGTH - 1:0] pixel_in2;
	reg  [`BIT_LENGTH - 1:0] pixel_in3;
	reg  [`BIT_LENGTH - 1:0] pixel_in4;
	wire       edge_out;
    
	reg  [`BIT_LENGTH - 1:0] pixel_mem  [0:OUT_LENGTH-1];
	reg  [`BIT_LENGTH - 1:0] angle_mem  [0:OUT_LENGTH-1];
	reg  [`BIT_LENGTH - 1:0] pixel0_mem [0:DATA_LENGTH-1];
	reg  [`BIT_LENGTH - 1:0] pixel1_mem [0:DATA_LENGTH-1];
	reg  [`BIT_LENGTH - 1:0] pixel2_mem [0:DATA_LENGTH-1];
	reg  [`BIT_LENGTH - 1:0] pixel3_mem [0:DATA_LENGTH-1];
	reg  [`BIT_LENGTH - 1:0] pixel4_mem [0:DATA_LENGTH-1];
	reg  [`BIT_LENGTH - 1:0] pixel_temp;

	reg        in_pause;
	reg        stop;
	integer    i, j, k, out_f, err, pattern_num;
	reg        over;

	CHIP chip (clk, reset, pixel_in0, pixel_in1, pixel_in2, pixel_in3, pixel_in4, edge_out, load_end, readable);

	initial	$readmemb (`PIXEL0, pixel0_mem);
	initial	$readmemb (`PIXEL1, pixel1_mem);
	initial	$readmemb (`PIXEL2, pixel2_mem);
	initial	$readmemb (`PIXEL3, pixel3_mem);
	initial	$readmemb (`PIXEL4, pixel4_mem);
	initial	$readmemb (`EXPECT, pixel_mem);

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
		load_end    = 1'b0;
		in_pause    = 1'b0;
   		#2.5 reset  = 1'b1;
    	#5 reset    = 1'b0;
	end

	always begin #(`CYCLE/2) clk = ~clk; end

	always @(negedge clk) begin
		// if input not done loading
		if (i < DATA_LENGTH) begin
			// if we should load input pixels again
			if (!in_pause) begin
				if (i == 0) $display("PROCESSING IMAGE %d/%d", i / 80 + 1, INPUT_TILE);

				pixel_in0 = pixel0_mem[i];
				pixel_in1 = pixel1_mem[i];
				pixel_in2 = pixel2_mem[i];
				pixel_in3 = pixel3_mem[i];
				pixel_in4 = pixel4_mem[i];
				
				i = i + 1;

				if (i % 80 == 0 && i != 0) begin
					$display("PROCESSING IMAGE %d/%d", i / 80 + 1, INPUT_TILE);
					#2.5 reset = 1'b1;
					#5   reset = 1'b0;
				end

				if ((i + 1) % 80 == 0) begin
					in_pause = 1'b1;
					load_end = 1'b1;
				end	
			end
		end
	end
	
	always @(negedge clk) begin
		if (j < OUT_LENGTH && readable) begin

			if ((j + 1) % 324 == 0) begin
				in_pause = 1'b0;
				load_end = 1'b0;
	     	end

			pixel_temp = pixel_mem[j];
			j = j + 1;

		    if (edge_out !== pixel_temp) begin
		        $display("ERROR at %d:output %d !=expect %d ", pattern_num, edge_out, pixel_temp);
			    $fdisplay(out_f,"ERROR at %d:output %d !=expect %d ", pattern_num, edge_out, pixel_temp);
		        err = err + 1 ;
		    end

		    pattern_num = pattern_num + 1; 
			if (pattern_num === OUT_LENGTH) over = 1'b1;
	    end
	end

	// initial begin
	// 	for (i=0;i<DATA_LENGTH;i=i+1) begin
	// 		if (i==79) load_end = 1'b1;
			
	// 		#(`CYCLE);
			
	// 		pixel_in0 = pixel0_mem[i];
	// 		pixel_in1 = pixel1_mem[i];
	// 		pixel_in2 = pixel2_mem[i];
	// 		pixel_in3 = pixel3_mem[i];
	// 		pixel_in4 = pixel4_mem[i];
	// 	end
	// 	stop = 1;
	// end

	// always @(negedge clk) begin
	// 	if (j < OUT_LENGTH && readable) begin
	// 		pixel_temp = pixel_mem[j];
	// 		j = j + 1;
			
	// 	    // modilfy for different module debugging : only when Full(i.e. Hysteresis)
	// 	    if (edge_out !== pixel_temp) begin
	// 	        $display("ERROR at %d:output %d !=expect %d ", pattern_num, edge_out, pixel_temp);
	// 		    $fdisplay(out_f,"ERROR at %d:output %d !=expect %d ", pattern_num, edge_out, pixel_temp);
	// 	        err = err + 1 ;
	// 	    end
	// 	    // comment out if not Full(i.e. Hysteresis)

	// 	    pattern_num = pattern_num + 1; 
	// 		if (pattern_num === OUT_LENGTH) over = 1'b1;
	//     end
	// end

	initial begin
	    @(posedge over)      
       	$display("---------------------------------------------\n");
       	if (err == 0)  begin
          	$display("All data have been generated successfully!\n");
          	$display("-------------------PASS-------------------\n");
       	end
       	else begin
          	$display("There are %d errors out of %d!\n", err, OUT_LENGTH);
		end
        $display("---------------------------------------------\n");
	    
	    #10 $finish;
	end

endmodule