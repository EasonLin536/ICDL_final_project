module NonMax ( clk, reset, angle, pixel_in0, pixel_in1, pixel_in2, enable, pixel_out, readable );
	
	input						clk, reset;
	input						enable;		// true when operating (sent by main control)
	output						readable;	// rise when start generating output

	input  [1:0]				angle;
	input  [`BIT_LENGTH - 1:0]	pixel_in0, pixel_in1, pixel_in2;
	output [`BIT_LENGTH - 1:0]	pixel_out;

// ================ Reg & Wires ================ //
	reg    [1:0]				state_n, state_r;
	reg    [1:0]				ang_n, ang_r;
	reg    [`BIT_LENGTH - 1:0]	pixel_col0_n[0:2], pixel_col1_n[0:2], pixel_col2_n[0:2];
	reg    [`BIT_LENGTH - 1:0]	pixel_col0_r[0:2], pixel_col1_r[0:2], pixel_col2_r[0:2];
	reg    [`BIT_LENGTH - 1:0]	pixel_out_n, pixel_out_r;
	reg    						readable_n, readable_r;

	integer i;

	assign pixel_out = pixel_out_r;
	assign readable = readable_r;

// =============== Combinational =============== //
	// FSM
	parameter load		= 2'b00;
	parameter operate	= 2'b01;
	parameter over		= 2'b11;

	always @(*) begin
		case (state_r)
			load: begin
				state_n = enable ? operate : load;
				readable_n = 0;
				ang_n = angle;
				pixel_col2_n[0] = pixel_in0;
				pixel_col2_n[1] = pixel_in1;
				pixel_col2_n[2] = pixel_in2;
				for (i=0; i<3; i=i+1) begin
					pixel_col0_n[i] = pixel_col1_r[i];
					pixel_col1_n[i] = pixel_col2_r[i];
				end
				pixel_out_n = 5'b0;
			end
			operate: begin
				state_n = enable ? operate : over;
				readable_n = 1;
				ang_n = angle;
				pixel_col2_n[0] = pixel_in0;
				pixel_col2_n[1] = pixel_in1;
				pixel_col2_n[2] = pixel_in2;
				for (i=0; i<3; i=i+1) begin
					pixel_col0_n[i] = pixel_col1_r[i];
					pixel_col1_n[i] = pixel_col2_r[i];
				end
				case (ang_r)
					2'b00: begin
						pixel_out_n = ((pixel_col0_r[1] > pixel_col1_r[1]) | (pixel_col2_r[1] > pixel_col1_r[1])) ?
						              5'b0 : pixel_col1_r[1];
					end
					2'b01: begin
						pixel_out_n = ((pixel_col0_r[2] > pixel_col1_r[1]) | (pixel_col2_r[0] > pixel_col1_r[1])) ?
						              5'b0 : pixel_col1_r[1];
					end
					2'b10: begin
						pixel_out_n = ((pixel_col1_r[0] > pixel_col1_r[1]) | (pixel_col1_r[2] > pixel_col1_r[1])) ?
						              5'b0 : pixel_col1_r[1];
					end
					2'b11: begin
						pixel_out_n = ((pixel_col0_r[0] > pixel_col1_r[1]) | (pixel_col2_r[2] > pixel_col1_r[1])) ?
						              5'b0 : pixel_col1_r[1];
					end
				endcase
			end
			over: begin
				state_n = over;
				ang_n = ang_r;
				readable_n = 0;
				for (i=0; i<3; i=i+1) begin
					pixel_col0_n[i] = 5'b0;
					pixel_col1_n[i] = 5'b0;
					pixel_col2_n[i] = 5'b0;
				end
				pixel_out_n = 5'b0;
			end
			default: begin
				state_n = over;
				ang_n = ang_r;
				readable_n = 0;
				for (i=0; i<3; i=i+1) begin
					pixel_col0_n[i] = 5'b0;
					pixel_col1_n[i] = 5'b0;
					pixel_col2_n[i] = 5'b0;
				end
				pixel_out_n = 5'b0;
			end
		endcase
	end
	
// ================ Sequential ================ //
	always @(posedge clk or posedge reset) begin
		if(reset) begin
			state_r <= 0;
			ang_r <= 0;
			readable_r <= 0;
			pixel_out_r <= 5'd0;
			for (i=0; i<3; i=i+1) begin
				pixel_col0_r[i] <= 5'd0;
				pixel_col1_r[i] <= 5'd0;
				pixel_col2_r[i] <= 5'd0;
			end
		end
		else begin
			state_r <= state_n;
			ang_r <= ang_n;
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