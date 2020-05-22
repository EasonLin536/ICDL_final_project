`define IMG_DIM    20
`define BIT_LENGTH 5
`define TOTAL_REG  `IMG_DIM * `IMG_DIM
`define ANG_REG    (`IMG_DIM - 2) * (`IMG_DIM - 2)

module CHIP ( clk, reset, pixel_in0, pixel_in1, pixel_in2, pixel_in3, pixel_in4, edge_out, load_end, readable );
	input                      clk, reset, load_end;
	input  [`BIT_LENGTH - 1:0] pixel_in0, pixel_in1, pixel_in2, pixel_in3, pixel_in4; // input 3 pixels per cycle
	output                     edge_out, readable;

// ================ Reg & Wires ================ //
	// LOAD_REG
	reg  [8:0] load_index; // calculate index when loading
	
	reg  [8:0] ind_0_w, ind_1_w, ind_2_w, ind_3_w, ind_4_w;
	reg  [8:0] ind_0_r, ind_1_r, ind_2_r, ind_3_r, ind_4_r; // current row and col (lower right of the filter)
	
	reg  [8:0] ind_col_end_r, ind_col_end_w; // assign with ind_1 - 1, if ind_0 == ind_col_end -> col_end = 1'b0
	reg        row_end, col_end; // determine kernel movement

	// LOAD_MOD
	reg  [`BIT_LENGTH - 1:0] reg_3_in [0:2]; // reg for median filter's input
	reg  [`BIT_LENGTH - 1:0] reg_5_in [0:4]; // reg for gaussian filter's input
	wire [`BIT_LENGTH - 1:0] in3_0, in3_1, in3_2;
	wire [`BIT_LENGTH - 1:0] in5_0, in5_1, in5_2, in5_3, in5_4;
	assign in3_0 = reg_3_in[0];
	assign in3_1 = reg_3_in[1];
	assign in3_2 = reg_3_in[2];
	assign in5_0 = reg_5_in[0];
	assign in5_1 = reg_5_in[1];
	assign in5_2 = reg_5_in[2];
	assign in5_3 = reg_5_in[3];
	assign in5_4 = reg_5_in[4];

	// output of sub-modules
	wire [`BIT_LENGTH - 1:0] med_out;
	wire [`BIT_LENGTH - 1:0] gau_out;
	wire [`BIT_LENGTH - 1:0] sb_grad_out;
	wire               [1:0] sb_ang_out;
	wire [`BIT_LENGTH - 1:0] non_max_out;

	// enable of sub-modules : modify in LOAD_MOD
	reg mf_en, gf_en, sb_en, nm_en, hy_en;
	// readable of sub-modules
	reg mf_read, gf_read, sb_read, nm_read, hy_read;

	// output register
	reg edge_out_r;
	reg edge_out_w;

	// for loops
    integer i;

// ================== States =================== //
    wire mode; // chip's operation
    parameter EDGE  = 1'd0;
    parameter COLOR = 1'd1;

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
    reg               [1:0] reg_angle [0:`ANG_REG - 1];

// =========== Declare Sub-Modules ============= //
	Median_Filter mf(.clk(clk), .reset(reset), .enable(mf_en),
					 .pixel_in0(in3_0), .pixel_in1(in3_1), .pixel_in2(in3_2),
					 .pixel_out(med_out), .readable(mf_read));
	Gaussian_Filter gf(.clk(clk), .reset(reset), .enable(gf_en),
					   .pixel_in0(in5_0), .pixel_in1(in5_1), .pixel_in2(in5_2), .pixel_in3(in5_3), .pixel_in4(in5_4),
					   .pixel_out(gau_out), .readable(gf_read));
	Sobel sb(.clk(clk), .reset(reset), .enable(sb_en),
			 .pixel_in0(in3_0), .pixel_in1(in3_1), .pixel_in2(in3_2),
			 .pixel_out(sb_grad_out), .angle_out(sb_ang_out), .readable(sb_read));
	NonMax nm(.clk(clk), .reset(reset), .enable(nm_en),
			  angle, .pixel_in0(in3_0), .pixel_in1(in3_1), .pixel_in2(in3_2),
			  .pixel_out(non_max_out), .readable(nm_read));
	Hyster hy(.clk(clk), .reset(reset), .enable(hy_en),
			  .pixel_in0(in3_0), .pixel_in1(in3_1), .pixel_in2(in3_2),
			  .pixel_out(edge_out_w), .readable(readable));

// =============== Combinational =============== //
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
			LOAD_MOD:   state_next = (!col_end) ? LOAD_MOD : PREPARE;
			WRITE_BACK: state_next = SET_OP;
			default:    state_next = LOAD_REG;
		endcase
	end

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

	// ind initialization
	always @(*) begin
		if (state == SET_OP) begin
			ind_0_w = 9'd0;
			ind_1_w = 9'd20;
			ind_2_w = 9'd40;
			ind_3_w = 9'd60;
			ind_4_w = 9'd80;
		end
		else begin
			ind_0_w = ind_0_r;
			ind_1_w = ind_1_r;
			ind_2_w = ind_2_r;
			ind_3_w = ind_3_r;
			ind_4_w = ind_4_r;
		end
	end

	/* PREPARE */
	// assign ind_col_end
	always @(*) begin
		ind_col_end_w = (state == PREPARE) ? ind_1_r : ind_col_end_r;
	end

	// determine row_end
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
	// update ind_0~4_w
	always @(*) begin
		if (state == LOAD_MOD) begin
			ind_0_w = ind_0_r + 1;
			ind_1_w = ind_1_r + 1;
			ind_2_w = ind_2_r + 1;
			ind_3_w = ind_3_r + 1;
			ind_4_w = ind_4_r + 1;
		end
		else begin
			ind_0_w = ind_0_r;
			ind_1_w = ind_1_r;
			ind_2_w = ind_2_r;
			ind_3_w = ind_3_r;
			ind_4_w = ind_4_r;
		end
	end

	// load pixels into sub-modules, enable signals
	always @(*) begin
		if (state == LOAD_MOD) begin
			
		end
		else begin
			
		end
	end

	// load output to tmp & angle registers files, readable signals
	always @(*) begin
		if (state == LOAD_MOD) begin
			
		end
		else begin
			
		end
	end

	// determine col_end
	always @(*) begin
		if (state == LOAD_MOD) col_end = (ind_0_r == ind_col_end - 1) ? 1'b1 : 1'b0;
		else col_end = 1'b0;
	end

	/* WRITE_BACK */
	// write tmp to img registers
	always @(*) begin
		if (state == WRITE_BACK) begin
			for (i=0;i<`TOTAL_REG;i=i+1) reg_img[i] = reg_tmp[i];
			if (operation == GAU_FIL) begin
				// 4 corners
				reg_img[0:1]     = reg_img[42];
				reg_img[20:21]   = reg_img[42];
				reg_img[18:19]   = reg_img[57];
				reg_img[38:39]   = reg_img[57];
				reg_img[360:361] = reg_img[342];
				reg_img[380:381] = reg_img[342];
				reg_img[378:379] = reg_img[357];
				reg_img[398:399] = reg_img[357];
				// horizontal sides
				reg_img[2:17]    = reg_img[42:57];
				reg_img[22:37]   = reg_img[42:57];
				reg_img[362:377] = reg_img[342:357];
				reg_img[382:397] = reg_img[342:357];
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
				reg_img[1:18]    = reg_img[21:38];
				reg_img[381:398] = reg_img[361:378];
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
	always @(posedge clk or posedge reset) begin
		if (reset) begin
			state      <= LOAD_REG;
			load_index <= 9'd0;
			operation  <= IDLE;
			ind_0_r    <= 9'd0;
			ind_1_r    <= 9'd0;
			ind_2_r    <= 9'd0;
			ind_3_r    <= 9'd0;
			ind_4_r    <= 9'd0;
			ind_col_end_r <= 9'd0;
			edge_out_r <= 1'b0;
		end
		else begin
			state      <= state_next;
			load_index <= load_index + 5;
			operation  <= operation_next;
			ind_0_r    <= ind_0_w;
			ind_1_r    <= ind_1_w;
			ind_2_r    <= ind_2_w;
			ind_3_r    <= ind_3_w;
			ind_4_r    <= ind_4_w;
			ind_col_end_r <= ind_col_end_w;
			edge_out_r <= edge_out_w;
		end
	end

	// LOAD_REG
	always @(posedge clk or posedge reset) begin
		if (reset) begin
			for (i=0;i<`TOTAL_REG;i=i+1) reg_img[i] <= 5'd0;
		end
		else begin
			if (state == LOAD_REG) begin
				for (i=0;i<`TOTAL_REG-5;i=i+1) reg_img[i] <= reg_img[i];
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