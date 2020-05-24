`define IMG_DIM    20
`define BIT_LENGTH 5
`define TOTAL_REG  `IMG_DIM * `IMG_DIM

module CHIP ( clk, reset, pixel_in0, pixel_in1, pixel_in2, pixel_in3, pixel_in4, edge_out, load_end, readable );
	input                      clk, reset, load_end;
	input  [`BIT_LENGTH - 1:0] pixel_in0, pixel_in1, pixel_in2, pixel_in3, pixel_in4; // input 3 pixels per cycle
	output                     edge_out, readable;

// ================ Reg & Wires ================ //
	// LOAD_REG
	reg  [8:0] load_index; // calculate index when loading into reg_img
	
	// LOAD_MOD
	// sub-modules' input index
	reg  [8:0] ind_0_r, ind_1_r, ind_2_r, ind_3_r, ind_4_r; // current index of pixel
	reg  [8:0] ind_0_w, ind_1_w, ind_2_w, ind_3_w, ind_4_w;
	reg  [8:0] ind_ang_r, ind_ang_w;
	// sub-modules' output index
	reg  [8:0] ind_load_tmp_r, ind_load_tmp_w;
	
	// indicators
	reg  [8:0] ind_col_end_r, ind_col_end_w; // assign with ind_1 - 1, if ind_0 == ind_col_end -> col_end = 1'b0
	reg  [8:0] ind_en_rise_r, ind_en_rise_w; // the index when enable signal rise
	reg        row_end; // determine kernel movement
	reg        col_end_r, col_end_w;

	// sub-modules' input pixel registers
	reg  [`BIT_LENGTH - 1:0] reg_3_in_r [0:2]; // reg for 3 pixel's input
	reg  [`BIT_LENGTH - 1:0] reg_3_in_w [0:2]; // reg for 3 pixel's input
	reg  [`BIT_LENGTH - 1:0] reg_5_in_r [0:4]; // reg for gaussian filter's input
	reg  [`BIT_LENGTH - 1:0] reg_5_in_w [0:4]; // reg for gaussian filter's input
	wire [`BIT_LENGTH - 1:0] in3_0, in3_1, in3_2;
	wire [`BIT_LENGTH - 1:0] in5_0, in5_1, in5_2, in5_3, in5_4;
	assign in3_0 = reg_3_in_r[0];
	assign in3_1 = reg_3_in_r[1];
	assign in3_2 = reg_3_in_r[2];
	assign in5_0 = reg_5_in_r[0];
	assign in5_1 = reg_5_in_r[1];
	assign in5_2 = reg_5_in_r[2];
	assign in5_3 = reg_5_in_r[3];
	assign in5_4 = reg_5_in_r[4];
	
	// sub-modules' input angle registers
	reg  [1:0] reg_ang_r, reg_ang_w;
	wire [1:0] ang_in;
	assign ang_in = reg_ang_r;

	// enable of sub-modules : modify in LOAD_MOD
	reg  enable_r, enable_w;
	wire mf_en, gf_en, sb_en, nm_en, hy_en;
	
	// readable of sub-modules
	wire mf_read, gf_read, sb_read, nm_read, hy_read;
	reg sub_read_r;
	wire sub_read_w;
	assign sub_read_w = mf_read | gf_read | sb_read | nm_read;

	// reset of sub-modules, should be high when SET_OP
	wire sub_reset;

	// output of sub-modules
	wire [`BIT_LENGTH - 1:0] med_out;
	wire [`BIT_LENGTH - 1:0] gau_out;
	wire [`BIT_LENGTH - 1:0] sb_grad_out;
	wire               [1:0] sb_ang_out;
	wire [`BIT_LENGTH - 1:0] non_max_out;
	
	// sub-modules' registers
	reg  [`BIT_LENGTH - 1:0] load_tmp_r, load_tmp_w;
	reg                [1:0] load_ang_r;
	wire               [1:0] load_ang_w;
	assign load_ang_w = sb_read ? sb_ang_out : 2'd0;

	// chip output register
	reg  edge_out_r;
	wire edge_out_w;

	// for loops
    integer i;

// ================== States =================== //
    reg [2:0] state, state_next;
    parameter LOAD_REG   = 3'd0;
    parameter SET_OP     = 3'd1;
    parameter PREPARE    = 3'd2;
    parameter LOAD_MOD   = 3'd3;
    parameter WRITE_BACK = 3'd4;

    reg [2:0] operation, operation_next; // current operation e.g., Median_Filter
    parameter IDLE     = 3'd0;
	parameter MED_FIL  = 3'd1;
    parameter GAU_FIL  = 3'd2;
    parameter SOBEL    = 3'd3;
    parameter NON_MAX  = 3'd4;
    parameter HYSTER   = 3'd5;
    parameter QUANTIZE = 3'd6;

// =============== Register File =============== //
    reg [`BIT_LENGTH - 1:0] reg_img   [0:`TOTAL_REG - 1];
    reg [`BIT_LENGTH - 1:0] reg_tmp   [0:`TOTAL_REG - 1];
    reg               [1:0] reg_angle [0:`TOTAL_REG - 1];

// =========== Declare Sub-Modules ============= //
	Median_Filter mf ( .clk(clk), .reset(sub_reset), .enable(mf_en),
					   .pixel_in0(in3_0), .pixel_in1(in3_1), .pixel_in2(in3_2),
					   .pixel_out(med_out), .readable(mf_read) );
	
	Gaussian_Filter gf ( .clk(clk), .reset(sub_reset), .enable(gf_en),
					     .pixel_in0(in5_0), .pixel_in1(in5_1), .pixel_in2(in5_2), .pixel_in3(in5_3), .pixel_in4(in5_4),
					     .pixel_out(gau_out), .readable(gf_read) );
	
	Sobel sb ( .clk(clk), .reset(sub_reset), .enable(sb_en),
			   .pixel_in0(in3_0), .pixel_in1(in3_1), .pixel_in2(in3_2),
			   .pixel_out(sb_grad_out), .angle_out(sb_ang_out), .readable(sb_read) );
	
	NonMax nm ( .clk(clk), .reset(sub_reset), .enable(nm_en),
			    .angle(ang_in), .pixel_in0(in3_0), .pixel_in1(in3_1), .pixel_in2(in3_2),
			    .pixel_out(non_max_out), .readable(nm_read) );
	
	Hyster hy ( .clk(clk), .reset(sub_reset), .enable(hy_en),
			    .pixel_in0(in3_0), .pixel_in1(in3_1), .pixel_in2(in3_2),
			    .pixel_out(edge_out_w), .readable(readable) );

// ============ Finite State Machine =========== //
	/* FSM */
	always @(*) begin
		case (state)
			LOAD_REG: state_next = load_end ? SET_OP : LOAD_REG;
			SET_OP:   state_next = PREPARE;
			PREPARE: begin
				// row not end
				if (!row_end) state_next = LOAD_MOD;
				// row end
				else begin
					// the entire operation is over
					if (operation == HYSTER) state_next = LOAD_REG;
					else state_next = WRITE_BACK;
				end
			end
			LOAD_MOD:   state_next = (col_end_r && !sub_read_r) ? PREPARE : LOAD_MOD;
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
		// remember the index of next row to determine col_end
		ind_col_end_w = (state == PREPARE) ? (ind_1_r - 1) : ind_col_end_r;
		// remember the index of next 3/5 to determine enable signal
		ind_en_rise_w = (state == PREPARE) ? ((operation == GAU_FIL) ? (ind_0_r + 4) : (ind_0_r + 2)) : ind_en_rise_r;
	end

	// determine row_end: write back to original reg_img
	always @(*) begin
		if (state == PREPARE) begin
			if (operation == GAU_FIL) begin
				row_end = (ind_4_r == 9'd400) ? 1'b1 : 1'b0;
			end
			else begin
				row_end = (ind_2_r == 9'd400) ? 1'b1 : 1'b0;
			end
		end
		else begin
			row_end = 1'b0;
		end
	end

	/* LOAD_MOD */
	// all indexes of sub-modules' inputs and outputs
	always @(*) begin
		// ind initialization
		if (state == SET_OP) begin
			ind_0_w = 9'd0;  // [row, col] = [0, 0]
			ind_1_w = 9'd20; // [row, col] = [1, 0]
			ind_2_w = 9'd40; // [row, col] = [2, 0]
			ind_3_w = 9'd60; // [row, col] = [3, 0]
			ind_4_w = 9'd80; // [row, col] = [4, 0]
			ind_ang_w = (operation == NON_MAX) ? 9'd19 : 9'd0; // input 18 valid angle for 20 pixels
			
		end
		// update ind_0~4_w
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

	always @(*) begin
		if (state == SET_OP) begin
			ind_load_tmp_w = (operation == GAU_FIL) ? 9'd42 : 9'd21; // different starting index when loading sub-modules' output to reg_tmp
		end
		else if (state == LOAD_MOD && sub_read_r) begin
			case (operation)
				// MED_FIL: ind_load_tmp_w = mf_read ? (col_end_r ? ind_load_tmp_r + 3 : ind_load_tmp_r + 1) : ind_load_tmp_r;
				// GAU_FIL: ind_load_tmp_w = gf_read ? (col_end_r ? ind_load_tmp_r + 5 : ind_load_tmp_r + 1) : ind_load_tmp_r;
				// SOBEL:   ind_load_tmp_w = sb_read ? (col_end_r ? ind_load_tmp_r + 3 : ind_load_tmp_r + 1) : ind_load_tmp_r;
				// NON_MAX: ind_load_tmp_w = nm_read ? (col_end_r ? ind_load_tmp_r + 3 : ind_load_tmp_r + 1) : ind_load_tmp_r;
				// HYSTER:  ind_load_tmp_w = hy_read ? (col_end_r ? ind_load_tmp_r + 3 : ind_load_tmp_r + 1) : ind_load_tmp_r;
				// default: ind_load_tmp_w = ind_load_tmp_r;
				MED_FIL: ind_load_tmp_w = mf_read ? ind_load_tmp_r + 1 : ind_load_tmp_r;
				GAU_FIL: ind_load_tmp_w = gf_read ? ind_load_tmp_r + 1 : ind_load_tmp_r;
				SOBEL:   ind_load_tmp_w = sb_read ? ind_load_tmp_r + 1 : ind_load_tmp_r;
				NON_MAX: ind_load_tmp_w = nm_read ? ind_load_tmp_r + 1 : ind_load_tmp_r;
				HYSTER:  ind_load_tmp_w = hy_read ? ind_load_tmp_r + 1 : ind_load_tmp_r;
				default: ind_load_tmp_w = ind_load_tmp_r;
			endcase
		end
		else ind_load_tmp_w = ind_load_tmp_r;
	end

	// load pixels into sub-modules
	always @(*) begin
		if (state == LOAD_MOD) begin
			for (i=0;i<3;i=i+1) reg_3_in_w[i] = 5'd0;
			for (i=0;i<5;i=i+1) reg_5_in_w[i] = 5'd0;
			case (operation)
				GAU_FIL: begin
					reg_5_in_w[0] = reg_img[ind_0_r];
					reg_5_in_w[1] = reg_img[ind_1_r];
					reg_5_in_w[2] = reg_img[ind_2_r];
					reg_5_in_w[3] = reg_img[ind_3_r];
					reg_5_in_w[4] = reg_img[ind_4_r];
				end
				default: begin
					reg_3_in_w[0] = reg_img[ind_0_r];
					reg_3_in_w[1] = reg_img[ind_1_r];
					reg_3_in_w[2] = reg_img[ind_2_r];
				end
			endcase
		end
		else begin
			for (i=0;i<3;i=i+1) reg_3_in_w[i] = 5'd0;
			for (i=0;i<5;i=i+1) reg_5_in_w[i] = 5'd0;
		end
	end

	// load ang into sub-modules
	always @(*) begin
		if (state == LOAD_MOD) begin
			reg_ang_w = (operation == NON_MAX) ? reg_angle[ind_ang_r] : 2'd0;
		end
		else reg_ang_w = 2'd0;
	end

	// load enable signals
	assign mf_en = (operation == MED_FIL) ? enable_r : 1'b0;
	assign gf_en = (operation == GAU_FIL) ? enable_r : 1'b0;
	assign sb_en = (operation == SOBEL  ) ? enable_r : 1'b0;
	assign nm_en = (operation == NON_MAX) ? enable_r : 1'b0;
	assign hy_en = (operation == HYSTER ) ? enable_r : 1'b0;

	always @(*) begin
		// if (state == LOAD_MOD) enable_w = (ind_0_r == ind_en_rise_r) ? 1'b1 : ((ind_0_r == ind_col_end_r) ? 1'b0 : enable_r);
		// enable is high if input pixels are filled
		// if the col has ended, which means no more input, enable is low
		if (state == LOAD_MOD) begin
			if (ind_0_r == ind_en_rise_r) enable_w = 1'b1;
			else enable_w = (ind_0_r == ind_col_end_r) ? 1'b0 : enable_r;
		end
		else enable_w = enable_r;
	end

	// get output of sub-modules according to readable signals
	// problem: when col_end, state is different, can't get the last output
	always @(*) begin
		if (state == LOAD_MOD) begin
			case (operation)
				MED_FIL: load_tmp_w = mf_read ? med_out : load_tmp_r;
				GAU_FIL: load_tmp_w = gf_read ? gau_out : load_tmp_r;
				SOBEL:   load_tmp_w = sb_read ? sb_grad_out : load_tmp_r;
				NON_MAX: load_tmp_w = nm_read ? non_max_out : load_tmp_r;
				default: load_tmp_w = load_tmp_r;
			endcase
		end
		else begin
			load_tmp_w = 5'd0;
		end
	end

	// load output to reg_tmp
	always @(*) begin
		reg_tmp[ind_load_tmp_r] = (state == LOAD_MOD) ? load_tmp_r : reg_tmp[ind_load_tmp_r];
	end

	// load ang to ang registers, readable signal
	always @(*) begin
		reg_angle[ind_load_tmp_r] = (state == LOAD_MOD && operation == SOBEL) ? load_ang_r : reg_angle[ind_load_tmp_r];
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
			for (i=0;i<`TOTAL_REG;i=i+1) reg_img[i] = reg_tmp[i];
			if (operation == GAU_FIL) begin
				// 4 corners
				reg_img[0]   = reg_img[42];
				reg_img[1]   = reg_img[42];
				reg_img[20]  = reg_img[42];
				reg_img[21]  = reg_img[42];
				reg_img[18]  = reg_img[57];
				reg_img[19]  = reg_img[57];
				reg_img[38]  = reg_img[57];
				reg_img[39]  = reg_img[57];
				reg_img[360] = reg_img[342];
				reg_img[361] = reg_img[342];
				reg_img[380] = reg_img[342];
				reg_img[381] = reg_img[342];
				reg_img[378] = reg_img[357];
				reg_img[379] = reg_img[357];
				reg_img[398] = reg_img[357];
				reg_img[399] = reg_img[357];
				// horizontal sides
				for (i=0;i<16;i=i+1) begin
					reg_img[i+2]   = reg_img[i+42];
					reg_img[i+22]  = reg_img[i+42];
					reg_img[i+362] = reg_img[i+342];
					reg_img[i+382] = reg_img[i+342];
				end
				// vertical sides
				for (i=40;i<360;i=i+20) begin
					reg_img[i]    = reg_img[i+2];
					reg_img[i+1]  = reg_img[i+2];
					reg_img[i+18] = reg_img[i+17];
					reg_img[i+19] = reg_img[i+17];
				end
			end
			else begin
				// 4 corners
				reg_img[0]   = reg_img[21];
				reg_img[19]  = reg_img[38];
				reg_img[380] = reg_img[361];
				reg_img[399] = reg_img[378];
				// horizontal sides
				for (i=0;i<18;i=i+1) begin
					reg_img[i+1]   = reg_img[i+21];
					reg_img[i+381] = reg_img[i+361];
				end
				// vertical sides
				for (i=20;i<380;i=i+20) begin
					reg_img[i]    = reg_img[i+1];
					reg_img[i+19] = reg_img[i+18];
				end
			end
		end
		else for (i=0;i<`TOTAL_REG;i=i+1) reg_img[i] = reg_img[i];
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
			// 
			col_end_r      <= 1'b0;
			// index of input & output
			ind_0_r        <= 9'd0;
			ind_1_r        <= 9'd0;
			ind_2_r        <= 9'd0;
			ind_3_r        <= 9'd0;
			ind_4_r        <= 9'd0;
			ind_ang_r      <= 9'd0;
			ind_load_tmp_r <= 9'd0;
			ind_col_end_r  <= 9'd0;
			ind_en_rise_r  <= 9'd0;
			enable_r       <= 1'b0;
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
			// 
			col_end_r      <= col_end_w;
			// index of input & output
			ind_0_r        <= ind_0_w;
			ind_1_r        <= ind_1_w;
			ind_2_r        <= ind_2_w;
			ind_3_r        <= ind_3_w;
			ind_4_r        <= ind_4_w;
			ind_ang_r      <= ind_ang_w;
			ind_load_tmp_r <= ind_load_tmp_w;
			ind_col_end_r  <= ind_col_end_w;
			ind_en_rise_r  <= ind_en_rise_w;
			enable_r       <= enable_w;
			// register of output of sub-modules
			sub_read_r     <= sub_read_w;
			load_tmp_r     <= load_tmp_w;
			load_ang_r     <= load_ang_w;
			// chip output
			edge_out_r     <= edge_out_w;
		end
	end

	// LOAD_MOD : load 3/5 input into sub-modules
	always @(posedge clk) begin
		if (reset) begin
			for (i=0;i<3;i=i+1) reg_3_in_r[i] <= 5'd0;
			for (i=0;i<5;i=i+1) reg_5_in_r[i] <= 5'd0;
			reg_ang_r <= 2'd0;
		end
		else begin
			for (i=0;i<3;i=i+1) reg_3_in_r[i] <= reg_3_in_w[i];
			for (i=0;i<5;i=i+1) reg_5_in_r[i] <= reg_5_in_w[i];
			reg_ang_r <= reg_ang_w;
		end
	end

	// LOAD_REG
	always @(posedge clk) begin
		if (reset) begin
			for (i=0;i<`TOTAL_REG;i=i+1) reg_img[i] <= 5'd0;
		end
		else begin
			if (state == LOAD_REG) begin
				for (i=0;i<`TOTAL_REG;i=i+1) reg_img[i] <= reg_img[i];
				reg_img[load_index]   <= pixel_in0;
				reg_img[load_index+1] <= pixel_in1;
				reg_img[load_index+2] <= pixel_in2;
				reg_img[load_index+3] <= pixel_in3;
				reg_img[load_index+4] <= pixel_in4;
			end
			else begin
				for (i=0;i<`TOTAL_REG;i=i+1) reg_img[i] <= reg_img[i];
			end
		end
	end
endmodule