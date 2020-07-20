module Gaussian_Filter ( clk, reset, pixel_in0, pixel_in1, pixel_in2, pixel_in3, pixel_in4, enable, pixel_out, readable );

	input                      clk, reset;
	input                      enable;    // generate by main ctrl unit: =0: no operation; =1: operation
	output                     readable;  // when the entire image is processed
	input  [`BIT_LENGTH - 1:0] pixel_in0;
	input  [`BIT_LENGTH - 1:0] pixel_in1;
	input  [`BIT_LENGTH - 1:0] pixel_in2;
	input  [`BIT_LENGTH - 1:0] pixel_in3;
	input  [`BIT_LENGTH - 1:0] pixel_in4;
	output [`BIT_LENGTH - 1:0] pixel_out;

// ================ Reg & Wires ================ //
	
	reg    [`BIT_LENGTH - 1:0] reg_pixel_col0 [0:4]; // store the oldest pixels
	reg    [`BIT_LENGTH - 1:0] reg_pixel_col1 [0:4];
	reg    [`BIT_LENGTH - 1:0] reg_pixel_col2 [0:4];
	reg    [`BIT_LENGTH - 1:0] reg_pixel_col3 [0:4];
	reg    [`BIT_LENGTH - 1:0] reg_pixel_col4 [0:4];

	reg    [1:0]               next_state;
	reg    [1:0]               state;

	// output register
    reg    [`BIT_LENGTH - 1:0] output_r; 
    wire   [`BIT_LENGTH - 1:0] output_w;
    reg    [`BIT_LENGTH - 1:0] reg_gau;
    wire   [`BIT_LENGTH - 1:0] gau;

    // output readable signal
    reg    readable_r;
    wire   readable_w;
    reg    reg_readable;

    // wires into filter modules
    reg    [`BIT_LENGTH - 1:0] x [0:24];

    // wires out of filter modules
    wire   [`BIT_LENGTH + 6:0] sum [0:4];

    // for loop
    integer i;

    assign pixel_out  = output_r;
    assign output_w   = reg_gau;
    assign readable   = readable_r;
    assign readable_w = reg_readable;

// =============== Combinational =============== //

	// FSM
	parameter load    = 2'd0;
	parameter operate = 2'd1;
	parameter over    = 2'd2;

    // next state logic
	always @(*) begin
		case (state)
			load:    next_state = enable ? operate : load;
			operate: next_state = enable ? operate : over;
			over:    next_state = over;
			default: next_state = over;
		endcase
	end

    // output logic
    always @(*) begin
        case (state)
            load:    reg_gau = gau;
            operate: reg_gau = gau;
            over:    reg_gau = gau;
            default: reg_gau = 5'd0;
        endcase
    end

    always @(*) begin
        case (state)
        	load:    reg_readable = 1'b0;
        	operate: reg_readable = 1'b1;
            over:    reg_readable = 1'b0;
            default: reg_readable = 1'b0;
        endcase
    end

    // assign registers to wires
    always @(*) begin
    	for (i=0;i<5;i=i+1) begin
    		x[i]    = reg_pixel_col0[i];
    		x[i+5]  = reg_pixel_col1[i];
    		x[i+10] = reg_pixel_col2[i];
    		x[i+15] = reg_pixel_col3[i];
    		x[i+20] = reg_pixel_col4[i];
    	end
    end

    filter_col_0 fil0 ( x[0],  x[1],  x[2],  x[3],  x[4],  sum[0] );
    filter_col_1 fil1 ( x[5],  x[6],  x[7],  x[8],  x[9],  sum[1] );
    filter_col_2 fil2 ( x[10], x[11], x[12], x[13], x[14], sum[2] );
    filter_col_1 fil3 ( x[15], x[16], x[17], x[18], x[19], sum[3] );
    filter_col_0 fil4 ( x[20], x[21], x[22], x[23], x[24], sum[4] );

    sum_n_divide snd  ( sum[0], sum[1], sum[2], sum[3], sum[4], gau );

// ================ Sequential ================ //
	
	always @(posedge clk or posedge reset) begin
		if (reset) begin
			for (i=0;i<5;i=i+1) begin
				reg_pixel_col0[i] <= 5'd0;
				reg_pixel_col1[i] <= 5'd0;
				reg_pixel_col2[i] <= 5'd0;
				reg_pixel_col3[i] <= 5'd0;
				reg_pixel_col4[i] <= 5'd0;
            end
            state      <= load;
            output_r   <= 5'd0;
            readable_r <= 1'b0;
		end
		else begin
			for (i=0;i<5;i=i+1) begin
				reg_pixel_col0[i] <= reg_pixel_col1[i];
				reg_pixel_col1[i] <= reg_pixel_col2[i];
				reg_pixel_col2[i] <= reg_pixel_col3[i];
				reg_pixel_col3[i] <= reg_pixel_col4[i];
			end
			reg_pixel_col4[0] <= pixel_in0;
			reg_pixel_col4[1] <= pixel_in1;
			reg_pixel_col4[2] <= pixel_in2;
			reg_pixel_col4[3] <= pixel_in3;
			reg_pixel_col4[4] <= pixel_in4;

            state      <= next_state;
            output_r   <= output_w;
            readable_r <= readable_w;
		end
	end

endmodule

module filter_col_0 ( pixel_0, pixel_1, pixel_2, pixel_3, pixel_4, sum );
	
	input  [`BIT_LENGTH - 1:0] pixel_0;
	input  [`BIT_LENGTH - 1:0] pixel_1;
	input  [`BIT_LENGTH - 1:0] pixel_2;
	input  [`BIT_LENGTH - 1:0] pixel_3;
	input  [`BIT_LENGTH - 1:0] pixel_4;
	output [`BIT_LENGTH + 6:0] sum;

	wire   [`BIT_LENGTH + 3:0] extend_1;
	wire   [`BIT_LENGTH + 3:0] extend_2;
	wire   [`BIT_LENGTH + 3:0] extend_3;
	wire   [`BIT_LENGTH + 3:0] extend_4;
	wire   [`BIT_LENGTH + 3:0] extend_5;

	wire   [11:0] w0, w1, w2, w3;

	assign extend_1 = { 4'b0, pixel_0 };
	assign extend_2 = { 4'b0, pixel_1 };
	assign extend_3 = { 4'b0, pixel_2 };
	assign extend_4 = { 4'b0, pixel_3 };
	assign extend_5 = { 4'b0, pixel_4 };

	assign w0  = (extend_1 << 1) + (extend_2 << 2);
	assign w1  = (extend_4 << 2) + (extend_5 << 1);
	assign w2  = (extend_3 << 2) + extend_3;
	assign w3  = w0 + w1;
	assign sum = w2 + w3;

endmodule

module filter_col_1 ( pixel_0, pixel_1, pixel_2, pixel_3, pixel_4, sum );

	input  [`BIT_LENGTH - 1:0] pixel_0;
	input  [`BIT_LENGTH - 1:0] pixel_1;
	input  [`BIT_LENGTH - 1:0] pixel_2;
	input  [`BIT_LENGTH - 1:0] pixel_3;
	input  [`BIT_LENGTH - 1:0] pixel_4;
	output [`BIT_LENGTH + 6:0] sum;

	wire   [`BIT_LENGTH + 3:0] extend_1;
	wire   [`BIT_LENGTH + 3:0] extend_2;
	wire   [`BIT_LENGTH + 3:0] extend_3;
	wire   [`BIT_LENGTH + 3:0] extend_4;
	wire   [`BIT_LENGTH + 3:0] extend_5;

	wire   [11:0] w0, w1, w2, w3, w4, w5;

	assign extend_1 = { 4'b0, pixel_0 };
	assign extend_2 = { 4'b0, pixel_1 };
	assign extend_3 = { 4'b0, pixel_2 };
	assign extend_4 = { 4'b0, pixel_3 };
	assign extend_5 = { 4'b0, pixel_4 };

	assign w0  = (extend_1 << 2) + (extend_5 << 2);
	assign w1  = (extend_2 << 3) + extend_2;
	assign w2  = (extend_3 << 2) + (extend_3 << 3);
	assign w3  = (extend_4 << 3) + extend_4;
	assign w4  = w0 + w1;
	assign w5  = w2 + w3;
	assign sum = w4 + w5;

endmodule

module filter_col_2 ( pixel_0, pixel_1, pixel_2, pixel_3, pixel_4, sum );

	input  [`BIT_LENGTH - 1:0] pixel_0;
	input  [`BIT_LENGTH - 1:0] pixel_1;
	input  [`BIT_LENGTH - 1:0] pixel_2;
	input  [`BIT_LENGTH - 1:0] pixel_3;
	input  [`BIT_LENGTH - 1:0] pixel_4;
	output [`BIT_LENGTH + 6:0] sum;

	wire   [`BIT_LENGTH + 3:0] extend_1;
	wire   [`BIT_LENGTH + 3:0] extend_2;
	wire   [`BIT_LENGTH + 3:0] extend_3;
	wire   [`BIT_LENGTH + 3:0] extend_4;
	wire   [`BIT_LENGTH + 3:0] extend_5;

	wire   [11:0] w0, w1, w2, w3, w4, w5, w6, w7;

	assign extend_1 = { 4'b0, pixel_0 };
	assign extend_2 = { 4'b0, pixel_1 };
	assign extend_3 = { 4'b0, pixel_2 };
	assign extend_4 = { 4'b0, pixel_3 };
	assign extend_5 = { 4'b0, pixel_4 };

	assign w0 = (extend_1 << 2) + extend_1;
	assign w1 = (extend_2 << 2) + (extend_2 << 3);
	assign w2 = (extend_3 << 4) - extend_3;
	assign w3 = (extend_4 << 2) + (extend_4 << 3);
	assign w4 = (extend_5 << 2) + extend_5;

	assign w5 = w0 + w1;
	assign w6 = w2 + w3;
	assign w7 = w4 + w5;
	assign sum = w6 + w7;

endmodule

module sum_n_divide ( in1, in2, in3, in4, in5, out );

	input  [`BIT_LENGTH + 6:0] in1, in2, in3, in4, in5;
	output [`BIT_LENGTH - 1:0] out;

	wire   [`BIT_LENGTH + 9:0] w0, w1, w2, w3, w4, w5, w6;

	assign w0 = in1 + in2;
	assign w1 = in3 + in4;
	assign w2 = w0  + in5;
	assign w3 = w1  + w2;

	assign w4 = (w3 >> 7)  - (w3 >> 9);
	assign w5 = (w3 >> 11) - (w3 >> 14);
	assign w6 = w4 + w5;

	assign out = { w6[4:0] };

endmodule