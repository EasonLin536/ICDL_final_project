`define IMG_DIM    20
`define BIT_LENGTH 5
`define TOTAL_REG  `IMG_DIM*`IMG_DIM
`define TMP_REG    (`IMG_DIM - 2)*(`IMG_DIM - 2)

module Main_Ctrl_Unit ( clk, reset, mode, pixel_in0, pixel_in1, pixel_in2, pixel_out );
	input                    clk, reset, mode;
	input [`BIT_LENGTH - 1:0] pixel_in0, pixel_in1, pixel_in2;
	output                   pixel_out;

// ================ Reg & Wires ================ //
	reg [4:0] row, row_next, col, col_next; // current row and col (lower right of the filter)
    reg load_reg_done_r, load_reg_done_w; // if img_reg is entirely filled 1, else 0

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
    parameter MED_FIL  = 3'd0;
    parameter GAU_FIL  = 3'd1;
    parameter SOBEL    = 3'd2;
    parameter NON_MAX  = 3'd3;
    parameter HYSTER   = 3'd4;
    parameter QUANTIZE = 3'd5;

// =============== Register File =============== //
    reg [`BIT_LENGTH - 1:0] reg_img_r   [0:`TOTAL_REG - 1];
    reg [`BIT_LENGTH - 1:0] reg_img_w   [0:`TOTAL_REG - 1];
    reg [`BIT_LENGTH - 1:0] reg_tmp_r   [0:`TMP_REG - 1];
    reg [`BIT_LENGTH - 1:0] reg_tmp_w   [0:`TMP_REG - 1];
    reg               [1:0] reg_angle_r [0:`TMP_REG - 1];
    reg               [1:0] reg_angle_w [0:`TMP_REG - 1];


// =============== Combinational =============== //
	// FSM
	always @(*) begin
		case (state)
			LOAD_REG: state_next = load_reg_done_r ? SET_OP : LOAD_REG;
			SET_OP:   state_next = PREPARE;
			PREPARE: begin
				if (mode == EDGE) begin
					// column not end
					if (col < `IMG_DIM - 1) state_next = LOAD_MOD;
					// column end
					else begin
						// the entire operation is over
						if (operation == HYSTER) state_next = LOAD_REG;
						else state_next = WRITE_BACK;
					end
				end
				else begin
					// column not end
					if (col < `IMG_DIM - 1) state_next = LOAD_MOD;
					// column end
					else begin
						// the entire operation is over
						if (operation == QUANTIZE) state_next = LOAD_REG;
						else state_next = WRITE_BACK;
					end
				end
			end
			LOAD_MOD: begin
				if (row < `IMG_DIM - 1) state_next = LOAD_MOD;
				else state_next = PREPARE;
			end
			WRITE_BACK: state_next = SET_OP;
			default:    state_next = LOAD_REG;
		endcase
	end


	always @(*) begin
		if (state == LOAD_REG) begin
			for (i=0;i<`TOTAL_REG;i=i+3) begin
				reg_img_w[i] = pixel_in0;
				if (i+1 < `TOTAL_REG) reg_img_w[i+1] = pixel_in1;
				if (i+2 < `TOTAL_REG) reg_img_w[i+2] = pixel_in2;
			end
		end
		else begin
			for (i=0;i<`TOTAL_REG;i=i+1) begin
				reg_img_w[i] = reg_img_r[i];
			end
		end
	end

// ================ Sequential ================= //
	always @(posedge clk) begin
		if (reset) begin
			state           <= LOAD_REG;
			row             <= 5'd0;
			col             <= 5'd0;
			operation       <= MED_FIL;
			load_reg_done_r <= 1'd0;
			for (i=0;i<`TOTAL_REG;i=i+1) reg_img_r[i]   <= 5'd0;
			for (i=0;i<`TMP_REG;i=i+1)   reg_tmp_r[i]   <= 5'd0;
			for (i=0;i<`TMP_REG;i=i+1)   reg_angle_r[i] <= 2'd0;
		end
		else begin
			state           <= state_next;
			row             <= row_next;
			col             <= col_next;
			operation       <= operation_next;
			load_reg_done_r <= load_reg_done_w
			for (i=0;i<`TOTAL_REG;i=i+1) reg_img_r[i]   <= reg_img_w[i];
			for (i=0;i<`TMP_REG;i=i+1)   reg_tmp_r[i]   <= reg_tmp_w[i];
			for (i=0;i<`TMP_REG;i=i+1)   reg_angle_r[i] <= reg_angle_w[i];
		end
	end
endmodule
