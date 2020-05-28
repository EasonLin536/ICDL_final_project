`define IMG_DIM    20
`define BIT_LENGTH 5
`define INDEX_LEN  9
`define TOTAL_REG  `IMG_DIM * `IMG_DIM
// for sobel module
`define BIT_LENGTH_GRD 8
`define BIT_LENGTH_ANG 2

module CHIP ( clk, reset, pixel_in0, pixel_in1, pixel_in2, pixel_in3, pixel_in4, edge_out, load_end, readable);
	
	input                      clk, reset, load_end; // load_end is high with the last 5 input pixels
	input  [`BIT_LENGTH - 1:0] pixel_in0, pixel_in1, pixel_in2, pixel_in3, pixel_in4; // input 5 pixels per cycle
	output                     edge_out, readable;

// ================ Reg & Wires ================ //
	// LOAD_REG
	reg  [`INDEX_LEN - 1:0] load_index; // calculate index when loading into reg_img
	
	// LOAD_MOD
	// sub-modules' input index
	reg  [`INDEX_LEN - 1:0] ind_0_r, ind_1_r, ind_2_r, ind_3_r, ind_4_r; // current index of input pixels
	reg  [`INDEX_LEN - 1:0] ind_0_w, ind_1_w, ind_2_w, ind_3_w, ind_4_w;
	reg  [`INDEX_LEN - 1:0] ind_ang_r, ind_ang_w;
	// sub-modules' output index
	reg  [`INDEX_LEN - 1:0] ind_load_tmp_r, ind_load_tmp_w;
	
	// indicators
	reg  [`INDEX_LEN - 1:0] ind_col_end_r, ind_col_end_w; // assign with ind_1 - 1, if ind_0 == ind_col_end -> col_end = 1'b0
	reg  [`INDEX_LEN - 1:0] ind_en_rise_r, ind_en_rise_w; // the index when enable signal rise
	reg        row_end; // determine kernel movement
	reg        col_end_r, col_end_w;

	// sub-modules' input pixel registers
	reg  [`BIT_LENGTH - 1:0] reg_in_r [0:4]; // reg for sub-modules input
	reg  [`BIT_LENGTH - 1:0] reg_in_w [0:4]; // reg for sub-modules input
	wire [`BIT_LENGTH - 1:0] in_0, in_1, in_2, in_3, in_4; // wires connected to sub-modules' inputs
	assign in_0 = reg_in_r[0];
	assign in_1 = reg_in_r[1];
	assign in_2 = reg_in_r[2];
	assign in_3 = reg_in_r[3];
	assign in_4 = reg_in_r[4];
	
	// sub-modules' input angle registers
	reg  [1:0] reg_ang_r, reg_ang_w;
	wire [1:0] ang_in;
	assign ang_in = reg_ang_r;

	// enable of sub-modules : modify in LOAD_MOD
	reg  enable_r, enable_w;
	reg  readable_r;
	wire readable_w;
	wire mf_en, gf_en, sb_en, nm_en, hy_en;
	
	// readable of sub-modules
	wire mf_read, gf_read, sb_read, nm_read, hy_read;
	// use for extend col_end and LOAD_MOD state, 
	// because when finish loading input (col is ended), 
	// it takes a few cycles for the outputs to be written to reg_tmp
	reg sub_read_r;
	wire sub_read_w;
	assign sub_read_w = mf_read | gf_read | sb_read | nm_read | hy_read;

	// sub-modules are reset when state PREPARE
	wire sub_reset;

	// output of sub-modules
	wire [`BIT_LENGTH - 1:0] mf_out;
	wire [`BIT_LENGTH - 1:0] gf_out;
	wire [`BIT_LENGTH - 1:0] sb_grad_out;
	wire               [1:0] sb_ang_out;
	wire [`BIT_LENGTH - 1:0] nm_out;
	
	// sub-modules' registers
	reg  [`BIT_LENGTH - 1:0] load_tmp_r, load_tmp_w; // pixel
	reg                [1:0] load_ang_r; // angle
	wire               [1:0] load_ang_w;
	assign load_ang_w = sb_read ? sb_ang_out : 2'd0;

	// debug
	// assign debug_pixel = nm_out; // modilfy for different module debugging
	// assign debug_angle = sb_ang_out;
	
	// chip readable 
	assign readable_w = hy_read;
	assign readable = readable_r; // modilfy for different module debugging

	// chip output register
	reg  edge_out_r;
	wire edge_out_w;
	assign edge_out = edge_out_r;

	// for loops
    integer i;

// =============== Register File =============== //
    reg [`BIT_LENGTH - 1:0] reg_img_r   [0:`TOTAL_REG - 1];
    reg [`BIT_LENGTH - 1:0] reg_img_w   [0:`TOTAL_REG - 1];
    reg [`BIT_LENGTH - 1:0] reg_tmp_r   [0:`TOTAL_REG - 1];
    reg [`BIT_LENGTH - 1:0] reg_tmp_w   [0:`TOTAL_REG - 1];
    reg               [1:0] reg_angle_r [0:`TOTAL_REG - 1];
    reg               [1:0] reg_angle_w [0:`TOTAL_REG - 1];

// ================== States =================== //
    reg [2:0] state, state_next;
    parameter LOAD_REG   = 3'd0; // load 20*20 raw image into registers on chip
    parameter SET_OP     = 3'd1; // select operation to perform e.g., Median Filter
    parameter PREPARE    = 3'd2; // determine if the operation is ended with row_end
    parameter LOAD_MOD   = 3'd3; // load input pixels to sub-modules and store the output to registers
    parameter WRITE_BACK = 3'd4; // write the pixels in reg_tmp to reg_img and add padding

    reg [2:0] operation, operation_next; // current operation e.g., Median_Filter
    parameter IDLE     = 3'd0;
	parameter MED_FIL  = 3'd1; // 3*3 median filter
    parameter GAU_FIL  = 3'd2; // 5*5 gaussian filter
    parameter SOBEL    = 3'd3; // sobel gradient calculation
    parameter NON_MAX  = 3'd4; // non-maximum supression
    parameter HYSTER   = 3'd5; // hysteresis

// =========== Declare Sub-Modules ============= //
	Median_Filter mf ( .clk(clk), .reset(sub_reset), .enable(mf_en),
					   .pixel_in0(in_0), .pixel_in1(in_1), .pixel_in2(in_2),
					   .pixel_out(mf_out), .readable(mf_read) );
	
	Gaussian_Filter gf ( .clk(clk), .reset(sub_reset), .enable(gf_en),
					     .pixel_in0(in_0), .pixel_in1(in_1), .pixel_in2(in_2), .pixel_in3(in_3), .pixel_in4(in_4),
					     .pixel_out(gf_out), .readable(gf_read) );
	
	Sobel sb ( .clk(clk), .reset(sub_reset), .enable(sb_en),
			   .pixel_in0(in_0), .pixel_in1(in_1), .pixel_in2(in_2),
			   .pixel_out(sb_grad_out), .angle_out(sb_ang_out), .readable(sb_read) );
	
	NonMax nm ( .clk(clk), .reset(sub_reset), .enable(nm_en),
			    .angle(ang_in), .pixel_in0(in_0), .pixel_in1(in_1), .pixel_in2(in_2),
			    .pixel_out(nm_out), .readable(nm_read) );
	
	Hyster hy ( .clk(clk), .reset(sub_reset), .enable(hy_en),
			    .pixel_in0(in_0), .pixel_in1(in_1), .pixel_in2(in_2),
			    .pixel_out(edge_out_w), .readable(hy_read) );

// ============ Finite State Machine =========== //
	/* FSM */
	always @(*) begin
		case (state)
			// if finish loading -> select operation, or keep loading 
			LOAD_REG: state_next = load_end ? SET_OP : LOAD_REG;
			SET_OP:   state_next = PREPARE;
			PREPARE: begin
				// row not end, keep loading pixel to the sub-module
				if (!row_end) state_next = LOAD_MOD;
				// row end
				// if the entire operation is over -> another 20*20 image,
				// or write the pixels in reg_tmp back to reg_img
				else state_next = (operation == HYSTER) ? LOAD_REG : WRITE_BACK;				
			end
			// if col end and finish reading output -> back to prepare, or keep loading
			LOAD_MOD:   state_next = (col_end_r && !sub_read_r) ? PREPARE : LOAD_MOD;
			// select the next operation
			WRITE_BACK: state_next = SET_OP;
			default:    state_next = LOAD_REG;
		endcase
	end

// =============== Combinational =============== //
	/* SET_OP */
	// operation transition
	always @(*) begin
		if (state == SET_OP) begin
			case (operation)
				IDLE:    operation_next = MED_FIL;
				MED_FIL: operation_next = GAU_FIL;
				GAU_FIL: operation_next = SOBEL;
				SOBEL:   operation_next = NON_MAX;
				NON_MAX: operation_next = HYSTER;
				HYSTER:  operation_next = IDLE;
				default: operation_next = IDLE;
			endcase
		end
		else begin
			operation_next = operation;
		end
	end

	// reset sub-modules
	assign sub_reset = (state == PREPARE) ? 1'b1 : 1'b0;

	/* PREPARE */
	// assign ind_col_end & ind_en_rise
	always @(*) begin
		// remember the index of last pixel of the current row to determine col_end
		ind_col_end_w = (state == PREPARE) ? (ind_1_r - 1) : ind_col_end_r;
		// remember the index of next 3/5 to determine enable signal
		ind_en_rise_w = (state == PREPARE) ? ((operation == GAU_FIL) ? (ind_0_r + 4) : (ind_0_r + 2)) : ind_en_rise_r;
	end

	// determine row_end: write back to original reg_img
	always @(*) begin
		if (state == PREPARE) begin
			if (operation == GAU_FIL) begin
				row_end = (ind_4_r == 9'd400) ? 1'b1 : 1'b0; // the 5th row
			end
			else begin
				row_end = (ind_2_r == 9'd400) ? 1'b1 : 1'b0; // the 3rd row
			end
		end
		else begin
			row_end = 1'b0;
		end
	end

	/* LOAD_MOD */
	// sub-modules' inputs index
	always @(*) begin
		// ind initialization
		if (state == SET_OP) begin
			ind_0_w = 9'd0;  // [row, col] = [0, 0]
			ind_1_w = 9'd20; // [row, col] = [1, 0]
			ind_2_w = 9'd40; // [row, col] = [2, 0]
			ind_3_w = 9'd60; // [row, col] = [3, 0]
			ind_4_w = 9'd80; // [row, col] = [4, 0]
			ind_ang_w = (operation_next == NON_MAX) ? 9'd19 : 9'd0; // input 18 valid angle for 20 pixels
		end
		// update ind_0~4_w if the col not ended
		else if (state == LOAD_MOD && !col_end_r) begin
			ind_0_w = ind_0_r + 1;
			ind_1_w = ind_1_r + 1;
			ind_2_w = ind_2_r + 1;
			ind_3_w = ind_3_r + 1;
			ind_4_w = ind_4_r + 1;
			ind_ang_w = (operation == NON_MAX) ? ind_ang_r + 1 : ind_ang_r;
		end
		else begin
			ind_0_w = ind_0_r;
			ind_1_w = ind_1_r;
			ind_2_w = ind_2_r;
			ind_3_w = ind_3_r;
			ind_4_w = ind_4_r;
			ind_ang_w = ind_ang_r;
		end
	end

	// sub-modules' outputs index for loading into reg_tmp
	always @(*) begin
		if (state == SET_OP) begin
			ind_load_tmp_w = (operation_next == GAU_FIL) ? 9'd42 : 9'd21; // different starting index when loading sub-modules' output to reg_tmp
		end
		else if (state == LOAD_MOD) begin
			case (operation)
				GAU_FIL: begin
					if (state_next == PREPARE) ind_load_tmp_w = ind_load_tmp_r + 4;
					else ind_load_tmp_w = (sub_read_r || col_end_r) ? ind_load_tmp_r + 1 : ind_load_tmp_r;
				end
				default: begin
					if (state_next == PREPARE) ind_load_tmp_w = ind_load_tmp_r + 2;
					else ind_load_tmp_w = (sub_read_r || col_end_r) ? ind_load_tmp_r + 1 : ind_load_tmp_r;
				end
			endcase
		end
		else ind_load_tmp_w = ind_load_tmp_r;
	end

	// load pixels into sub-modules
	always @(*) begin
		for (i=0;i<5;i=i+1) reg_in_w[i] = reg_in_r[i];
		if (state == LOAD_MOD) begin
			case (operation)
				GAU_FIL: begin
					reg_in_w[0] = reg_img_r[ind_0_r];
					reg_in_w[1] = reg_img_r[ind_1_r];
					reg_in_w[2] = reg_img_r[ind_2_r];
					reg_in_w[3] = reg_img_r[ind_3_r];
					reg_in_w[4] = reg_img_r[ind_4_r];
				end
				default: begin
					reg_in_w[0] = reg_img_r[ind_0_r];
					reg_in_w[1] = reg_img_r[ind_1_r];
					reg_in_w[2] = reg_img_r[ind_2_r];
				end
			endcase
		end
		else begin
			for (i=0;i<5;i=i+1) reg_in_w[i] = 5'd0;
		end
	end

	// load angle into sub-modules
	always @(*) begin
		if (state == LOAD_MOD) begin
			reg_ang_w = (operation == NON_MAX) ? reg_angle_r[ind_ang_r] : 2'd0;
		end
		else reg_ang_w = 2'd0;
	end

	// load enable signals
	assign mf_en = (operation == MED_FIL) ? enable_r : 1'b0;
	assign gf_en = (operation == GAU_FIL) ? enable_r : 1'b0;
	assign sb_en = (operation == SOBEL)   ? enable_r : 1'b0;
	assign nm_en = (operation == NON_MAX) ? enable_r : 1'b0;
	assign hy_en = (operation == HYSTER ) ? enable_r : 1'b0;

	always @(*) begin
		if (state == LOAD_MOD) begin
			if (ind_0_r == ind_en_rise_r) enable_w = 1'b1;
			else enable_w = (ind_0_r == ind_col_end_r + 1) ? 1'b0 : enable_r;
		end
		else enable_w = enable_r;
	end

	// get output of sub-modules of different operation
	always @(*) begin
		if (state == LOAD_MOD) begin
			case (operation)
				MED_FIL: load_tmp_w = mf_out;
				GAU_FIL: load_tmp_w = gf_out;
				SOBEL:   load_tmp_w = sb_grad_out;
				NON_MAX: load_tmp_w = nm_out;
				default: load_tmp_w = load_tmp_r;
			endcase
		end
		else begin
			load_tmp_w = 5'd0;
		end
	end

	// load output to reg_tmp only when state LOAD_MOD
	always @(*) begin
		for (i=0;i<`TOTAL_REG;i=i+1) reg_tmp_w[i] = reg_tmp_r[i];
		reg_tmp_w[ind_load_tmp_r] = (state == LOAD_MOD) ? load_tmp_r : reg_tmp_r[ind_load_tmp_r];
	end

	// load angle to reg_ang
	always @(*) begin
		for (i=0;i<`TOTAL_REG;i=i+1) reg_angle_w[i] = reg_angle_r[i];
		reg_angle_w[ind_load_tmp_r] = (state == LOAD_MOD && operation == SOBEL) ? load_ang_r : reg_angle_r[ind_load_tmp_r];
	end

	// determine col_end
	always @(*) begin
		if (col_end_r) begin
			col_end_w = sub_read_r ? 1'b1 : 1'b0;
		end
		else begin
			if (state == LOAD_MOD) col_end_w = (ind_0_r == ind_col_end_r) ? 1'b1 : 1'b0;
			else col_end_w = 1'b0;
		end
	end

	/* WRITE_BACK */
	// write tmp to img registers with padding
	// e.g., output of mf is 18*18 write back to reg_img is 20*20
	always @(*) begin
		if (state == WRITE_BACK) begin
			for (i=0;i<`TOTAL_REG;i=i+1) reg_img_w[i] = reg_tmp_r[i];
			if (operation == GAU_FIL) begin
				// 4 corners
				reg_img_w[0]   = reg_tmp_r[42];
				reg_img_w[1]   = reg_tmp_r[42];
				reg_img_w[20]  = reg_tmp_r[42];
				reg_img_w[21]  = reg_tmp_r[42];
				reg_img_w[18]  = reg_tmp_r[57];
				reg_img_w[19]  = reg_tmp_r[57];
				reg_img_w[38]  = reg_tmp_r[57];
				reg_img_w[39]  = reg_tmp_r[57];
				reg_img_w[360] = reg_tmp_r[342];
				reg_img_w[361] = reg_tmp_r[342];
				reg_img_w[380] = reg_tmp_r[342];
				reg_img_w[381] = reg_tmp_r[342];
				reg_img_w[378] = reg_tmp_r[357];
				reg_img_w[379] = reg_tmp_r[357];
				reg_img_w[398] = reg_tmp_r[357];
				reg_img_w[399] = reg_tmp_r[357];
				// horizontal sides
				for (i=0;i<16;i=i+1) begin
					reg_img_w[i+2]   = reg_tmp_r[i+42];
					reg_img_w[i+22]  = reg_tmp_r[i+42];
					reg_img_w[i+362] = reg_tmp_r[i+342];
					reg_img_w[i+382] = reg_tmp_r[i+342];
				end
				// vertical sides
				for (i=40;i<360;i=i+20) begin
					reg_img_w[i]    = reg_tmp_r[i+2];
					reg_img_w[i+1]  = reg_tmp_r[i+2];
					reg_img_w[i+18] = reg_tmp_r[i+17];
					reg_img_w[i+19] = reg_tmp_r[i+17];
				end
			end
			else begin
				// 4 corners
				reg_img_w[0]   = reg_tmp_r[21];
				reg_img_w[19]  = reg_tmp_r[38];
				reg_img_w[380] = reg_tmp_r[361];
				reg_img_w[399] = reg_tmp_r[378];
				// horizontal sides
				for (i=0;i<18;i=i+1) begin
					reg_img_w[i+1]   = reg_tmp_r[i+21];
					reg_img_w[i+381] = reg_tmp_r[i+361];
				end
				// vertical sides
				for (i=20;i<380;i=i+20) begin
					reg_img_w[i]    = reg_tmp_r[i+1];
					reg_img_w[i+19] = reg_tmp_r[i+18];
				end
			end
		end
		else for (i=0;i<`TOTAL_REG;i=i+1) reg_img_w[i] = reg_img_r[i];
	end

// ================ Sequential ================= //
	always @(posedge clk) begin
		if (reset) begin
			// FSM
			state          <= LOAD_REG;
			// LOAD_REG
			load_index     <= 9'd0;
			// SET_OP
			operation      <= IDLE;
			// LOAD_MOD 
			col_end_r      <= 1'b0;
			// index of input & output
			ind_0_r        <= 9'd0;
			ind_1_r        <= 9'd0;
			ind_2_r        <= 9'd0;
			ind_3_r        <= 9'd0;
			ind_4_r        <= 9'd0;
			ind_ang_r      <= 9'd0;
			ind_load_tmp_r <= 9'd0;
			// indicator
			ind_col_end_r  <= 9'd0;
			ind_en_rise_r  <= 9'd0;
			enable_r       <= 1'b0;
			readable_r     <= 1'b0;
			// register of output of sub-modules
			sub_read_r     <= 1'b0;
			load_tmp_r     <= 5'd0; // pixel or gradient
			load_ang_r     <= 2'd0; // angle
			// chip output
			edge_out_r     <= 1'b0;
		end
		else begin
			// FSM
			state          <= state_next;
			// LOAD_REG
			load_index     <= (state == LOAD_REG) ? load_index + 5 : 9'd0;
			// SET_OP
			operation      <= operation_next;
			// LOAD_MOD 
			col_end_r      <= col_end_w;
			// index of input & output
			ind_0_r        <= ind_0_w;
			ind_1_r        <= ind_1_w;
			ind_2_r        <= ind_2_w;
			ind_3_r        <= ind_3_w;
			ind_4_r        <= ind_4_w;
			ind_ang_r      <= ind_ang_w;
			ind_load_tmp_r <= ind_load_tmp_w;
			// indicator
			ind_col_end_r  <= ind_col_end_w;
			ind_en_rise_r  <= ind_en_rise_w;
			enable_r       <= enable_w;
			readable_r     <= readable_w;
			// register of output of sub-modules
			sub_read_r     <= sub_read_w;
			load_tmp_r     <= load_tmp_w;
			load_ang_r     <= load_ang_w;
			// chip output
			edge_out_r     <= edge_out_w;
		end
	end

	// LOAD_MOD : load input into sub-modules
	always @(posedge clk) begin
		if (reset) begin
			for (i=0;i<5;i=i+1) reg_in_r[i] <= 5'd0;
			reg_ang_r <= 2'd0;
		end
		else begin
			for (i=0;i<5;i=i+1) reg_in_r[i] <= reg_in_w[i];
			reg_ang_r <= reg_ang_w;
		end
	end

	// get output of sub-modules
	always @(posedge clk) begin
		if (reset) begin
			for (i=0;i<`TOTAL_REG;i=i+1) begin
				reg_tmp_r[i]   <= 5'd0;
				reg_angle_r[i] <= 2'd0;
			end
		end
		else begin
			for (i=0;i<`TOTAL_REG;i=i+1) begin
				reg_tmp_r[i]   <= reg_tmp_w[i];
				reg_angle_r[i] <= reg_angle_w[i];
			end
		end
	end

	// LOAD_REG
	always @(posedge clk) begin
		if (reset) begin
			for (i=0;i<`TOTAL_REG;i=i+1) begin
				reg_img_r[i] <= 5'd0;
			end
		end
		else begin
			if (state == LOAD_REG) begin
				for (i=0;i<`TOTAL_REG;i=i+1) reg_img_r[i] <= reg_img_w[i];
				reg_img_r[load_index]   <= pixel_in0;
				reg_img_r[load_index+1] <= pixel_in1;
				reg_img_r[load_index+2] <= pixel_in2;
				reg_img_r[load_index+3] <= pixel_in3;
				reg_img_r[load_index+4] <= pixel_in4;
			end
			else begin
				for (i=0;i<`TOTAL_REG;i=i+1) reg_img_r[i] <= reg_img_w[i];
			end
		end
	end

endmodule

// ================ Sub-Modules ================ //
/* Median Filter */
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

/* Gaussian Filter */
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

/* Sobel */
module Sobel ( clk, reset, pixel_in0, pixel_in1, pixel_in2, enable, pixel_out, angle_out, readable );

    input                          clk, reset;
    input                          enable;    // generate by main ctrl unit: =0: no operation; =1: operation
    output                         readable;  // when the entire image is processed
    input      [`BIT_LENGTH - 1:0] pixel_in0;
    input      [`BIT_LENGTH - 1:0] pixel_in1;
    input      [`BIT_LENGTH - 1:0] pixel_in2;
    output     [`BIT_LENGTH - 1:0] pixel_out; // gradient
    output [`BIT_LENGTH_ANG - 1:0] angle_out; // angle

// ================ Reg & Wires ================ //

    reg    [`BIT_LENGTH - 1:0] reg_pixel_col0 [0:2]; // store the oldest pixels
    reg    [`BIT_LENGTH - 1:0] reg_pixel_col1 [0:2];
    reg    [`BIT_LENGTH - 1:0] reg_pixel_col2 [0:2];

    reg    [1:0]               next_state;
    reg    [1:0]               state;

    reg    [`BIT_LENGTH_GRD-1 :0] x0;
    reg    [`BIT_LENGTH_GRD-1 :0] x1;
    reg    [`BIT_LENGTH_GRD-1 :0] x2;
    reg    [`BIT_LENGTH_GRD-1 :0] x3;
    reg    [`BIT_LENGTH_GRD-1 :0] x4;
    reg    [`BIT_LENGTH_GRD-1 :0] x5;
    reg    [`BIT_LENGTH_GRD-1 :0] x6;
    reg    [`BIT_LENGTH_GRD-1 :0] x7;
    reg    [`BIT_LENGTH_GRD-1 :0] x8;

    // output register
    reg    [`BIT_LENGTH - 1:0] output_r; 
    wire   [`BIT_LENGTH - 1:0] output_w;

    reg    [`BIT_LENGTH_ANG - 1:0] ang_output_r; 
    wire   [`BIT_LENGTH_ANG - 1:0] ang_output_w;

    reg    [`BIT_LENGTH - 1:0]     reg_gradient;
    wire   [`BIT_LENGTH_GRD - 1:0] gradient;

    reg    [`BIT_LENGTH_ANG - 1:0] reg_angle;
    wire   [`BIT_LENGTH_ANG - 1:0] angle;
    reg    [`BIT_LENGTH_ANG - 1:0] r_angle;

    wire   [`BIT_LENGTH_GRD-1:0]   wire_Gx;
    wire   [`BIT_LENGTH_GRD-1:0]   wire_Gy;

    wire   [`BIT_LENGTH_GRD-1:0]   absGx;
    wire   [`BIT_LENGTH_GRD-1:0]   absGy;
    // output readable signal
    reg    readable_r;
    wire   readable_w;
    reg    reg_readable;


    wire   [`BIT_LENGTH_GRD - 1:0] absGradient;
    // conparator
    wire   [`BIT_LENGTH_GRD - 1:0] w0, w1, w2, w3, w4, w5;

    wire   [`BIT_LENGTH_GRD - 1:0] Gxt;
    wire   [`BIT_LENGTH_GRD - 1:0] Gyt;
    
    wire         w20, w21;
    wire   [2:0] w23;
    // for loop
    integer i;

    assign pixel_out = output_r;
    assign output_w  = reg_gradient;

    assign angle_out    = ang_output_r;
    assign ang_output_w = reg_angle;

    assign readable   = readable_r;
    assign readable_w = reg_readable;

    assign angle = r_angle;

// =============== Combinational =============== //
    
    // FSM
    parameter load    = 2'd0;
    parameter operate = 2'd1;
    parameter over    = 2'd2;

    // next state logic
    always @(*) begin
        case (state)
            load:    next_state = enable ? operate : load; //1 : 0
            operate: next_state = enable ? operate : over; // enable==0 over=1
            over:    next_state = over;
            default: next_state = over;
        endcase
    end

    // output logic
    always @(*) begin
        case (state)
            load:    reg_gradient = gradient[`BIT_LENGTH_GRD-1] ? -1*absGradient[`BIT_LENGTH_GRD-1:3]:gradient[`BIT_LENGTH_GRD-1:3];
            operate: reg_gradient = gradient[`BIT_LENGTH_GRD-1] ? -1*absGradient[`BIT_LENGTH_GRD-1:3]:gradient[`BIT_LENGTH_GRD-1:3];
            over:    reg_gradient = gradient[`BIT_LENGTH_GRD-1] ? -1*absGradient[`BIT_LENGTH_GRD-1:3]:gradient[`BIT_LENGTH_GRD-1:3];
            default: reg_gradient = 5'd0;
        endcase
    end

    always @(*) begin
        case (state)
            load:    reg_angle = angle;
            operate: reg_angle = angle;
            over:    reg_angle = angle;
            default: reg_angle = 2'd0;
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
        x0 = reg_pixel_col0[0];
        x1 = reg_pixel_col0[1];
        x2 = reg_pixel_col0[2];
        x3 = reg_pixel_col1[0];
        x4 = reg_pixel_col1[1];
        x5 = reg_pixel_col1[2];
        x6 = reg_pixel_col2[0];
        x7 = reg_pixel_col2[1];
        x8 = reg_pixel_col2[2];
    end

    assign w0 = (~x0 + 8'd1) + ( (~x1 + 8'd1) << 1) + (~x2 + 8'd1);
    assign w1 = 8'd0; //( 0 * x[3]) + ( 0 * x[4]) + ( 0 * x[5]);
    assign w2 = ((x6) + (x7 << 1)) + (x8);

    assign w3 = (x0) + (~x2 + 8'd1); //+ ( 0 * x[1])
    assign w4 = (x3 << 1) + ((~x5 + 8'd1) << 1); //+ ( 0 * x[4]) 
    assign w5 = (x6) + (~x8 + 8'd1); //+ ( 0 * x[7]) 

    assign wire_Gx = (w0 + w1) + w2;
    assign wire_Gy = (w3 + w4) + w5;

    assign absGradient = (gradient[`BIT_LENGTH_GRD-1]) ? (~gradient + 8'd1) : gradient;

    assign sign_xor = wire_Gx[`BIT_LENGTH_GRD - 1] ^ wire_Gy[`BIT_LENGTH_GRD-1];

    assign absGx = (wire_Gx[`BIT_LENGTH_GRD-1]) ? (~wire_Gx + 8'd1) : wire_Gx ;
    assign absGy = (wire_Gy[`BIT_LENGTH_GRD-1]) ? (~wire_Gy + 8'd1) : wire_Gy ;

    assign gradient = (absGx + absGy);

    assign Gxt = {2'b00,absGx[`BIT_LENGTH_GRD - 1 : 2]} + {3'b000,absGx[`BIT_LENGTH_GRD - 1 : 3]} + {5'b00000,absGx[`BIT_LENGTH_GRD - 1 : 5]} + {7'b0000000,absGx[`BIT_LENGTH_GRD - 1] };
    assign Gyt = {2'b00,absGy[`BIT_LENGTH_GRD - 1 : 2]} + {3'b000,absGy[`BIT_LENGTH_GRD - 1 : 3]} + {5'b00000,absGy[`BIT_LENGTH_GRD - 1 : 5]} + {7'b0000000,absGy[`BIT_LENGTH_GRD - 1] };

    assign w20 = Gxt > absGy ? 1 : 0;
    assign w21 = Gyt > absGx ? 1 : 0;
    
    assign w23 = { w20 , w21 , sign_xor };

    always@(w20 or w21 or sign_xor) begin
        case (w23)
            3'b100   : r_angle = 2'b00; // 0 degree
            3'b101   : r_angle = 2'b00;
            3'b110   : r_angle = 2'b00;
            3'b111   : r_angle = 2'b00;
    
            3'b000   : r_angle = 2'b01; //45
    
            3'b001   : r_angle = 2'b11; //135
    
            3'b011   : r_angle = 2'b10; //90
            3'b010   : r_angle = 2'b10;
        default : r_angle  = 2'b00;

     endcase
    end

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
            ang_output_r <= ang_output_w;
            readable_r <= readable_w;
        end
    end

endmodule

/* NonMax */
module NonMax ( clk, reset, angle, pixel_in0, pixel_in1, pixel_in2, enable, pixel_out, readable);
	
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

/* Hyster */
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