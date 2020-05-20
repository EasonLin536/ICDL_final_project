`timescale 1ns/10ps
`define CYCLE 10
`define PIXEL1     "./pattern/pixel_1.dat"  
`define PIXEL2     "./pattern/pixel_2.dat"  
`define PIXEL3     "./pattern/pixel_3.dat"  
`define EXPECT     "./pattern/golden_grad.dat"
`define EXPECT2	   "./pattern/golden_ang.dat"

module tb();

	parameter DATA_LENGTH   = 102;
	parameter OUT_LENGTH    = 100;

	reg        clk, reset, enable;
	reg  [4:0] pixel_in1;
	reg  [4:0] pixel_in2;
	reg  [4:0] pixel_in3;
	wire [4:0] pixel_out;
	wire [1:0] angle_out;
    wire       readable;
	
    reg  [4:0] out_grad  [0:OUT_LENGTH-1];
    reg  [1:0] out_ang   [0:OUT_LENGTH-1];
  	reg  [4:0] pixel1_sb [0:DATA_LENGTH-1];
	reg  [4:0] pixel2_sb [0:DATA_LENGTH-1];
	reg  [4:0] pixel3_sb [0:DATA_LENGTH-1];
	reg  [4:0] out_temp;
	reg  [1:0] ang_temp;

	reg        stop;
	integer    i, j, out_f, err, pattern_num;
	reg        over;

	Sobel sb ( clk, reset, pixel_in1, pixel_in2, pixel_in3, enable, pixel_out, angle_out, readable );
	
	initial	$readmemb (`PIXEL1,  pixel1_sb);
	initial	$readmemb (`PIXEL2,  pixel2_sb);
	initial	$readmemb (`PIXEL3,  pixel3_sb);
	initial	$readmemb (`EXPECT,  out_grad);
	initial	$readmemb (`EXPECT2, out_ang);
	initial begin
		$dumpfile("sobel.fsdb");
     	$dumpvars;
    end

    initial begin
     	clk         = 1'b1;
     	reset       = 1'b0;
     	enable      = 1'b0;
     	stop        = 1'b0;  
   		over        = 1'b0;
   		pattern_num = 0;
   		err         = 0;
   		i           = 0;
   		j           = 0;
   		#2.5 reset  = 1'b1;
    	#2.5 reset  = 1'b0;
	end

	always begin #(`CYCLE/2) clk = ~clk; end

	always @(negedge clk) begin
		if (i == 2 && enable == 1'b0) enable = 1'b1;
	    if (i < DATA_LENGTH) begin
	        pixel_in1 = pixel1_sb[i];
		    pixel_in2 = pixel2_sb[i];
		    pixel_in3 = pixel3_sb[i];
		    
		    i = i + 1;
	    end
	    else
	       	stop = 1;
	end

	always @(posedge clk or posedge readable) begin
		if (j < OUT_LENGTH && readable) begin
			out_temp = out_grad[j];
			ang_temp = out_ang[j];
			j = j + 1;
		end
	end

	always @(negedge clk) begin
		if (readable) begin
		    if (pixel_out !== out_temp) begin
		        $display("ERROR at %d:pixel_output %d !=expect %d ", pattern_num, pixel_out, out_temp);
			    $fdisplay(out_f,"ERROR at %d:output %d !=expect %d ", pattern_num, pixel_out, out_temp);
		        err = err + 1 ;
		    end
		    if (angle_out !== ang_temp) begin
		    	$display("ERROR at %d:angle_output %d !=expect %d ", pattern_num, angle_out, ang_temp);
			    $fdisplay(out_f,"ERROR at %d:output %d !=expect %d ", pattern_num, angle_out, ang_temp);
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
