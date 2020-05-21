`timescale 1ns/10ps
`define CYCLE 10
`define PIXEL1     "./pattern/pixel_1.dat"  
`define PIXEL2     "./pattern/pixel_2.dat"  
`define PIXEL3     "./pattern/pixel_3.dat"
`define ANGLE      "./pattern/angle.dat"
`define EXPECT     "./pattern/out_golden.dat"

module tb();

	parameter DATA_LENGTH   = 102;
	parameter OUT_LENGTH    = 100;

	reg  clk_p_i, reset_p_i;
	reg  [1:0] angle_i; 
	reg  [4:0] pixel_in0_i, pixel_in1_i, pixel_in2_i;
	reg  enable_i;
	wire [4:0] pixel_out_o;
	wire readable_o;
	
    reg  [4:0] out_mem    [0:OUT_LENGTH-1];
	reg  [4:0] pixel1_mem [0:DATA_LENGTH-1];
	reg  [4:0] pixel2_mem [0:DATA_LENGTH-1];
	reg  [4:0] pixel3_mem [0:DATA_LENGTH-1];
	reg  [1:0] angle_mem  [0:DATA_LENGTH-1];
	reg  [4:0] out_temp;

	reg        stop;
	integer    i, j, out_f, err, pattern_num;
	reg        over;

	NonMax nM(clk_p_i, reset_p_i, angle_i, pixel_in0_i, pixel_in1_i, pixel_in2_i, enable_i, pixel_out_o, readable_o);
	
	initial	$readmemb (`PIXEL1,  pixel1_mem);
	initial	$readmemb (`PIXEL2,  pixel2_mem);
	initial	$readmemb (`PIXEL3,  pixel3_mem);
	initial $readmemb (`ANGLE ,  angle_mem);
	initial	$readmemb (`EXPECT,  out_mem);

	initial begin
		$dumpfile("Median_Filter.fsdb");
     	$dumpvars;
    end

    initial begin
     	clk_p_i			= 1'b1;
     	reset_p_i		= 1'b0;
     	enable_i		= 1'b0;
     	stop        	= 1'b0;  
   		over        	= 1'b0;
   		pattern_num 	= 0;
   		err         	= 0;
   		i           	= 0;
   		j           	= 0;
   		#2 reset_p_i	= 1'b1;
    	#2 reset_p_i	= 1'b0;
	end

	always begin #(`CYCLE/2) clk_p_i = ~clk_p_i; end

	always @(negedge clk_p_i) begin
		if (i == 2 && enable_i == 1'b0) enable_i = 1'b1;
	    if (i < DATA_LENGTH) begin
	        pixel_in0_i = pixel1_mem[i];
		    pixel_in1_i = pixel2_mem[i];
		    pixel_in2_i = pixel3_mem[i];
		    angle_i   = angle_mem[i];
		    
		    i = i + 1;
	    end
	    else
	       	stop = 1;
	end

	always @(posedge clk_p_i or posedge readable_o) begin
		if (j < OUT_LENGTH && readable_o) begin
			out_temp = out_mem[j];
			j = j + 1;
		end
	end

	always @(negedge clk_p_i) begin
		if (readable_o) begin
		    if (pixel_out_o !== out_temp) begin
		        $display("ERROR at %d:output %d !=expect %d ", pattern_num, pixel_out_o, out_temp);
			    $fdisplay(out_f,"ERROR at %d:output %d !=expect %d ", pattern_num, pixel_out_o, out_temp);
		        err = err + 1 ;
		    end

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
