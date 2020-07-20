`define IMG_DIM        20
`define BIT_LENGTH     4
`define INDEX_LEN      9
`define TOTAL_REG      `IMG_DIM * `IMG_DIM
// for sobel module
`define BIT_LENGTH_GRD 8
`define BIT_LENGTH_ANG 2

module CANNY ( clk, reset, pixel_in0, pixel_in1, pixel_in2, pixel_in3, pixel_in4, edge_out, load_end, readable );
	
	input                      clk, reset, load_end; // load_end is high with the last 5 input pixels
	input  [`BIT_LENGTH - 1:0] pixel_in0, pixel_in1, pixel_in2, pixel_in3, pixel_in4; // input 5 pixels per cycle
	output                     edge_out, readable;

// ================ Reg & Wires ================ //
	// LOAD_REG
	reg   [`INDEX_LEN - 1:0] load_index; // calculate index when loading into reg_img
	
	// LOAD_MOD
	// sub-modules' input index
	reg   [`INDEX_LEN - 1:0] ind_0_r, ind_1_r, ind_2_r, ind_3_r, ind_4_r; // current index of input pixels
	reg   [`INDEX_LEN - 1:0] ind_0_w, ind_1_w, ind_2_w, ind_3_w, ind_4_w;
	reg   [`INDEX_LEN - 1:0] ind_ang_r, ind_ang_w;
	// sub-modules' output index
	reg   [`INDEX_LEN - 1:0] ind_load_tmp_r, ind_load_tmp_w;
	
	// indicators
	reg   [`INDEX_LEN - 1:0] ind_col_end_r, ind_col_end_w; // assign with ind_1 - 1, if ind_0 == ind_col_end -> col_end = 1'b0
	reg   [`INDEX_LEN - 1:0] ind_en_rise_r, ind_en_rise_w; // the index when enable signal rise
	reg                      row_end; // determine kernel movement
	reg                      col_end_r, col_end_w;

	// sub-modules' input pixel registers
	reg  [`BIT_LENGTH - 1:0] reg_in_r [0:4]; // reg for sub-modules input
	reg  [`BIT_LENGTH - 1:0] reg_in_w [0:4]; // reg for sub-modules input
	wire [`BIT_LENGTH - 1:0] in_0, in_1, in_2, in_3, in_4; // wires connected to sub-modules' inputs
	
	
	// sub-modules' input angle registers
	reg                [1:0] reg_ang_r, reg_ang_w;
	wire               [1:0] ang_in;

	// enable of sub-modules : modify in LOAD_MOD
	reg                      enable_r, enable_w;
	reg                      readable_r;
	wire                     readable_w;
	wire                     mf_en, gf_en, sb_en, nm_en, hy_en;
	
	// readable of sub-modules
	wire                     mf_read, gf_read, sb_read, nm_read, hy_read;
	// use for extend col_end and LOAD_MOD state, 
	// because when finish loading input (col is ended), 
	// it takes a few cycles for the outputs to be written to reg_tmp
	reg                      sub_read_r;
	wire                     sub_read_w;

	// sub-modules are reset when state PREPARE
	wire                     sub_reset;

	// output of sub-modules
	wire [`BIT_LENGTH - 1:0] mf_out;
	wire [`BIT_LENGTH - 1:0] gf_out;
	wire [`BIT_LENGTH - 1:0] sb_grad_out;
	wire               [1:0] sb_ang_out;
	wire [`BIT_LENGTH - 1:0] nm_out;
	
	// sub-modules' input registers
	reg  [`BIT_LENGTH - 1:0] load_tmp_r, load_tmp_w; // pixel
	reg                [1:0] load_ang_r; // angle
	wire               [1:0] load_ang_w;

	// chip output register
	reg                      edge_out_r;
	wire                     edge_out_w;

	// for loops
    integer i;

// ================= Registers ================ //
    reg  [`BIT_LENGTH - 1:0] reg_img_r   [0:`TOTAL_REG - 1];
    reg  [`BIT_LENGTH - 1:0] reg_img_w   [0:`TOTAL_REG - 1];
    reg  [`BIT_LENGTH - 1:0] reg_tmp_r   [0:`TOTAL_REG - 1];
    reg  [`BIT_LENGTH - 1:0] reg_tmp_w   [0:`TOTAL_REG - 1];
    reg                [1:0] reg_angle_r [0:`TOTAL_REG - 1];
    reg                [1:0] reg_angle_w [0:`TOTAL_REG - 1];

// ================== States =================== //
    reg [2:0] state, state_next;
    parameter LOAD_REG   = 3'd0; // load 20*20 raw image into registers on chip
    parameter SET_OP     = 3'd1; // select operation to perform e.g., Median Filter
    parameter PREPARE    = 3'd2; // determine if the operation is ended with row_end
    parameter LOAD_MOD   = 3'd3; // load input pixels to sub-modules and store the output to registers
    parameter WRITE_BACK = 3'd4; // write the pixels in reg_tmp to reg_img and add padding

    reg [2:0] operation, operation_next; // current operation e.g., Median_Filter
    parameter IDLE       = 3'd0;
	parameter MED_FIL    = 3'd1; // 3*3 median filter
    parameter GAU_FIL    = 3'd2; // 5*5 gaussian filter
    parameter SOBEL      = 3'd3; // sobel gradient calculation
    parameter NON_MAX    = 3'd4; // non-maximum supression
    parameter HYSTER     = 3'd5; // hysteresis

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
	// sub-modules' input pixel registers
	assign in_0 = reg_in_r[0];
	assign in_1 = reg_in_r[1];
	assign in_2 = reg_in_r[2];
	assign in_3 = reg_in_r[3];
	assign in_4 = reg_in_r[4];
	
	// sub-modules' input angle registers
	assign ang_in = reg_ang_r;
	
	// readable of sub-modules
	assign sub_read_w = mf_read | gf_read | sb_read | nm_read | hy_read;
	
	// sub-modules' input registers
	assign load_ang_w = sb_read ? sb_ang_out : 2'd0;
	
	// chip readable 
	assign readable_w = hy_read;
	assign readable   = readable_r; // modilfy for different module debugging
	
	// chip output register
	assign edge_out = edge_out_r;

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