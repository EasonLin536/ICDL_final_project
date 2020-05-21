`define BIT_LENGTH 5

module Median_Filter ( clk, reset, pixel_in0, pixel_in1, pixel_in2, enable, pixel_out, readable );

	input                      clk, reset;
	input                      enable;    // generate by main ctrl unit: =0: no operation; =1: operation
	output                     readable;  // when the entire image is processed
	input  [`BIT_LENGTH - 1:0] pixel_in0;
	input  [`BIT_LENGTH - 1:0] pixel_in1;
	input  [`BIT_LENGTH - 1:0] pixel_in2;
	output [`BIT_LENGTH - 1:0] pixel_out;

// ================ Reg & Wires ================ //

	reg    [`BIT_LENGTH - 1:0] reg_pixel_col0 [0:2]; // store the oldest pixels
	reg    [`BIT_LENGTH - 1:0] reg_pixel_col1 [0:2];
	reg    [`BIT_LENGTH - 1:0] reg_pixel_col2 [0:2];

	reg    [1:0]               next_state;
	reg    [1:0]               state;

    reg    [`BIT_LENGTH - 1:0] x [0:8];

    // output register
    reg    [`BIT_LENGTH - 1:0] output_r; 
    wire   [`BIT_LENGTH - 1:0] output_w;
    reg    [`BIT_LENGTH - 1:0] reg_median;
    wire   [`BIT_LENGTH - 1:0] median;

    // output readable signal
    reg    readable_r;
    wire   readable_w;
    reg    reg_readable;

    // conparator
    wire   [`BIT_LENGTH - 1:0] w0, w1, w2, w3, w4,
                               w5, w6, w7, w8, w9,
                               w10, w11, w12, w13, w14,
                               w15, w16, w17, w18, w19,
                               w20, w21, w22, w23, w24,
                               w25, w26, w27, w28;
    
    // for loop
    integer i;

    assign pixel_out  = output_r;
    assign output_w   = reg_median;
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
            load:    reg_median = median;
            operate: reg_median = median;
            over:    reg_median = median;
            default: reg_median = 5'd0;
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

    always @(*) begin
        for (i=0;i<3;i=i+1) begin
            x[i] = reg_pixel_col0[i];
        end
        for (i=3;i<6;i=i+1) begin
            x[i] = reg_pixel_col1[i-3];
        end
        for (i=6;i<9;i=i+1) begin
            x[i] = reg_pixel_col2[i-6];
        end
    end

    // stage 1
    assign w0 = x[0] > x[1] ? x[0] : x[1];
    assign w1 = x[0] > x[1] ? x[1] : x[0];
    assign w2 = x[3] > x[4] ? x[3] : x[4];
    assign w3 = x[3] > x[4] ? x[4] : x[3];
    assign w4 = x[6] > x[7] ? x[6] : x[7];
    assign w5 = x[6] > x[7] ? x[7] : x[6];

    // stage 2
    assign w6  = w1 > x[2] ? w1   : x[2];
    assign w7  = w1 > x[2] ? x[2] : w1;
    assign w8  = w3 > x[5] ? w3   : x[5];
    assign w9  = w3 > x[5] ? x[5] : w3;
    assign w10 = w5 > x[8] ? w5   : x[8];
    assign w11 = w5 > x[8] ? x[8] : w5;

    //stage 3
    assign w12 = w0 > w6  ? w0  : w6;
    assign w13 = w0 > w6  ? w6  : w0;
    assign w14 = w2 > w8  ? w2  : w8;
    assign w15 = w2 > w8  ? w8  : w2;
    assign w16 = w4 > w10 ? w4  : w10;
    assign w17 = w4 > w10 ? w10 : w4;
    
    //stage 4
    assign w18 = w12 > w14 ? w14 : w12;
    assign w19 = w13 > w15 ? w13 : w15;
    assign w20 = w13 > w15 ? w15 : w13;
    assign w21 = w9  > w11 ? w9  : w11;

    // stage 5
    assign w22 = w18 > w16 ? w16 : w18;
    assign w23 = w20 > w17 ? w20 : w17;
    assign w24 = w7  > w21 ? w7  : w21;

    // stage 6
    assign w25 = w19 > w23 ? w23 : w19;

    // stage 7
    assign w26 = w22 > w25 ? w22 : w25;
    assign w27 = w22 > w25 ? w25 : w22;

    // stage 8
    assign w28 = w27 > w24 ? w27 : w24;

    // stage 9
    assign median = w26 > w28 ? w28 : w26;

// ================ Sequential ================ //

	always @(posedge clk or posedge reset) begin
		if (reset) begin
			for (i=0;i<3;i=i+1) begin
				reg_pixel_col0[i] <= 5'd0;
				reg_pixel_col1[i] <= 5'd0;
				reg_pixel_col2[i] <= 5'd0;
            end
            state      <= load;
            output_r   <= 5'd0;
            readable_r <= 1'b0;
		end
		else begin
			for (i=0;i<3;i=i+1) begin
				reg_pixel_col0[i] <= reg_pixel_col1[i];
				reg_pixel_col1[i] <= reg_pixel_col2[i];
			end
			reg_pixel_col2[0] <= pixel_in0;
			reg_pixel_col2[1] <= pixel_in1;
			reg_pixel_col2[2] <= pixel_in2;

            state      <= next_state;
            output_r   <= output_w;
            readable_r <= readable_w;
		end
	end

endmodule