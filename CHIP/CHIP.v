`define IMG_DIM    20
`define BIT_LENGTH 5
`define TOTAL_REG  `IMG_DIM * `IMG_DIM
`define TMP_REG    (`IMG_DIM - 2) * (`IMG_DIM - 2)

module CHIP ( clk, reset, mode, pixel_in0, pixel_in1, pixel_in2, edge_out, pixel_out, load_end );
	input                      clk, reset, mode, load_end;
	input  [`BIT_LENGTH - 1:0] pixel_in0, pixel_in1, pixel_in2; // input 3 pixels per cycle
	output                     edge_out; // pixel is edge or not
	output [`BIT_LENGTH - 1:0] pixel_out; // pixel's color

// ================ Reg & Wires ================ //
	reg  [8:0] load_index; // calculate index when loading
	
	reg  [4:0] row, row_next, col, col_next; // current row and col (lower right of the filter)

	reg  [`BIT_LENGTH - 1:0] reg_3_in [0:2]; // reg for median filter's input
	reg  [`BIT_LENGTH - 1:0] reg_GAU_in [0:4]; // reg for gaussian filter's input
	wire [`BIT_LENGTH - 1:0] in3_0, in3_1, in3_2;
	wire [`BIT_LENGTH - 1:0] GAU_in0, GAU_in1, GAU_in2, GAU_in3, GAU_in4;
	assign in3_0 = reg_3_in[0];
	assign in3_0 = reg_3_in[1];
	assign in3_0 = reg_3_in[2];
	assign GAU_in0 = reg_GAU_in[0];
	assign GAU_in1 = reg_GAU_in[1];
	assign GAU_in2 = reg_GAU_in[2];
	assign GAU_in3 = reg_GAU_in[3];
	assign GAU_in4 = reg_GAU_in[4];

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
    reg [`BIT_LENGTH - 1:0] reg_tmp   [0:`TMP_REG - 1];
    reg               [1:0] reg_angle [0:`TMP_REG - 1];

// =============== Combinational =============== //
	// FSM
	always @(*) begin
		case (state)
			LOAD_REG: state_next = load_end ? SET_OP : LOAD_REG;
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

	// operation state transition
	always @(*) begin
		if (state == SET_OP) begin
			if (mode == EDGE) begin
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
			// mode == COLOR
			else begin
				case (operation)
					IDLE:     operation_next = GAU_FIL;
					GAU_FIL:  operation_next = MED_FIL;
					MED_FIL:  operation_next = QUANTIZE;
					QUANTIZE: operation_next = IDLE;
					default:  operation_next = IDLE;
				endcase
			end
		end
		else begin
			operation_next = operation;
		end
	end

	// row & col transition
	

// ================ Sequential ================= //
	always @(posedge clk or posedge reset) begin
		if (reset) begin
			load_index <= 9'd0;
			state     <= LOAD_REG;
			row       <= 5'd0;
			col       <= 5'd0;
			operation <= MED_FIL;
		end
		else begin
			load_index <= load_index + 3;
			state     <= state_next;
			row       <= row_next;
			col       <= col_next;
			operation <= operation_next;
		end
	end

	// load pixels into img register file
	always @(posedge clk or posedge reset) begin
		if (reset) begin
			for (i=0;i<`TOTAL_REG;i=i+1) reg_img[i] <= 5'd0;
		end
		else begin
			if (state == LOAD_REG) begin
				for (i=0;i<`TOTAL_REG;i=i+1) reg_img[i] <= reg_img[i];
				if (!load_end) begin
					reg_img[load_index]   <= pixel_in0;
					reg_img[load_index+1] <= pixel_in1;
					reg_img[load_index+2] <= pixel_in2;
				end
				else begin
					// if it is the last input, only 2 pixels
					reg_img[load_index]   <= pixel_in0;
					reg_img[load_index+1] <= pixel_in1;
				end
			end
			else begin
				for (i=0;i<`TOTAL_REG;i=i+1) reg_img[i] <= reg_img[i];
			end
		end
		
	end

endmodule