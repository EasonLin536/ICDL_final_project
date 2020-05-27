`define IMG_WIDTH  960
`define IMG_HEIGHT 720
`define BIT_LENGTH 5

module Hyster ( clk, reset, pixel_in0, pixel_in1, pixel_in2, enable, pixel_out, readable);
	
	input						clk, reset;
	input						enable;		// true when operating (sent by main control)
	output						readable;	// rise when start generating output

	input  [`BIT_LENGTH - 1:0]	pixel_in0, pixel_in1, pixel_in2;
	output						pixel_out;

// ================ Reg & Wires ================ //
	reg    [1:0]				state_n, state_r;
	reg    [`BIT_LENGTH - 1:0]	pixel_col0_n[0:2], pixel_col1_n[0:2], pixel_col2_n[0:2];
	reg    [`BIT_LENGTH - 1:0]	pixel_col0_r[0:2], pixel_col1_r[0:2], pixel_col2_r[0:2];
	reg 						pixel_out_n, pixel_out_r;
	reg    						readable_n, readable_r;

	wire   [`BIT_LENGTH - 1:0]	w1, w2, w3, w4, w5, w6, w7;

	integer i;

	assign pixel_out = pixel_out_r;
	assign readable = readable_r;

// =============== Combinational =============== //
	// FSM
	parameter load		= 2'b00;
	parameter operate	= 2'b01;
	parameter over		= 2'b11;

	parameter weak		= 5'b01;
	parameter strong	= 5'b10;

	assign w1 = (pixel_col0_r[0] > pixel_col0_r[1]) ? pixel_col0_r[0] : pixel_col0_r[1];
	assign w2 = (pixel_col0_r[2] > pixel_col1_r[0]) ? pixel_col0_r[2] : pixel_col1_r[0];
	assign w3 = (pixel_col1_r[2] > pixel_col2_r[0]) ? pixel_col1_r[2] : pixel_col2_r[0];
	assign w4 = (pixel_col2_r[1] > pixel_col2_r[2]) ? pixel_col2_r[1] : pixel_col2_r[2];
	assign w5 = (w1 > w2) ? w1 : w2;
	assign w6 = (w3 > w4) ? w3 : w4;
	assign w7 = (w5 > w6) ? w5 : w6;

	always @(*) begin
		case (state_r)
			load: begin
				state_n = enable ? operate : load;
				readable_n = 0;
				pixel_col2_n[0] = pixel_in0;
				pixel_col2_n[1] = pixel_in1;
				pixel_col2_n[2] = pixel_in2;
				for (i=0; i<3; i=i+1) begin
					pixel_col0_n[i] = pixel_col1_r[i];
					pixel_col1_n[i] = pixel_col2_r[i];
				end
				pixel_out_n = 0;
			end
			operate: begin
				state_n = enable ? operate : over;
				readable_n = 1;
				pixel_col2_n[0] = pixel_in0;
				pixel_col2_n[1] = pixel_in1;
				pixel_col2_n[2] = pixel_in2;
				for (i=0; i<3; i=i+1) begin
					pixel_col0_n[i] = pixel_col1_r[i];
					pixel_col1_n[i] = pixel_col2_r[i];
				end
				
				// function part
				if (pixel_col1_r[1] < weak) begin
					pixel_out_n = 0;
				end
				else begin
					if (pixel_col1_r[1] < strong) begin
						pixel_out_n = (w7 < strong) ? 0 : 1;
					end
					else begin
						pixel_out_n = 1;
					end
				end

			end
			over: begin
				state_n = over;
				readable_n = 0;
				for (i=0; i<3; i=i+1) begin
					pixel_col0_n[i] = 5'b0;
					pixel_col1_n[i] = 5'b0;
					pixel_col2_n[i] = 5'b0;
				end
				pixel_out_n = 0;
			end
			default: begin
				state_n = over;
				readable_n = 0;
				for (i=0; i<3; i=i+1) begin
					pixel_col0_n[i] = 5'b0;
					pixel_col1_n[i] = 5'b0;
					pixel_col2_n[i] = 5'b0;
				end
				pixel_out_n = 0;
			end
		endcase
	end
	
// ================ Sequential ================ //
	always @(posedge clk or posedge reset) begin
		if(reset) begin
			state_r <= 0;
			readable_r <= 0;
			pixel_out_r <= 0;
			for (i=0; i<3; i=i+1) begin
				pixel_col0_r[i] <= 5'd0;
				pixel_col1_r[i] <= 5'd0;
				pixel_col2_r[i] <= 5'd0;
			end
		end
		else begin
			state_r <= state_n;
			readable_r <= readable_n;
			pixel_out_r <= pixel_out_n;
			for (i=0; i<3; i=i+1) begin
				pixel_col0_r[i] <= pixel_col0_n[i];
				pixel_col1_r[i] <= pixel_col1_n[i];
				pixel_col2_r[i] <= pixel_col2_n[i];
			end
		end
	end


endmodule