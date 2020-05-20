`define BIT_LENGTH 5
`define BIT_LENGTH_GRD 8
`define BIT_LENGTH_ANG 2

module Sobel ( clk, reset, pixel_in1, pixel_in2, pixel_in3, enable, pixel_out, angle_out, readable );

    input                      clk, reset;
    input                      enable;    // generate by main ctrl unit: =0: no operation; =1: operation
    output                     readable;  // when the entire image is processed
    input  [`BIT_LENGTH - 1:0] pixel_in1;
    input  [`BIT_LENGTH - 1:0] pixel_in2;
    input  [`BIT_LENGTH - 1:0] pixel_in3;
    output [`BIT_LENGTH - 1:0] pixel_out; // gradient

    output [`BIT_LENGTH_ANG-1:0] angle_out; // angle

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

    wire   [`BIT_LENGTH_GRD - 1:0]    Gxt;
    wire   [`BIT_LENGTH_GRD - 1:0]    Gyt;
    wire   w20, w21;
    wire   [2:0]   w23;
    // for loop
    integer i;


    assign pixel_out  = output_r;
    assign output_w   = reg_gradient;

    assign angle_out  = ang_output_r;
    assign ang_output_w = reg_angle;

    assign readable   = readable_r;
    assign readable_w = reg_readable;

    assign angle= r_angle;

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

    assign w0 = (~x0 + 8'd1) + ( (~x1+8'd1) << 1) + (~x2 + 8'd1);
    assign w1 = 8'd0;                            //( 0 * x[3]) + ( 0 * x[4]) + ( 0 * x[5]);
    assign w2 = ((x6) + (x7 << 1)) + (x8);

    assign w3 = (x0) + (~x2 + 8'd1);                  //+ ( 0 * x[1])
    assign w4 = (x3<<1) + ((~x5+8'd1) << 1);              //+ ( 0 * x[4]) 
    assign w5 = (x6) + (~x8 + 8'd1);              //+ ( 0 * x[7]) 
/*
    assign w0 = ((-1*x0) + ( -2*x1)) + (-1*x2);
    assign w1 = 8'd0;                            //( 0 * x[3]) + ( 0 * x[4]) + ( 0 * x[5]);
    assign w2 = (x6 + (2*x7) ) + x8;

    assign w3 = (x0) + (-1*x2);                  //+ ( 0 * x[1])
    assign w4 = (2*x3) + (-2*x5);              //+ ( 0 * x[4]) 
    assign w5 = (x6) + (-1*x8);              //+ ( 0 * x[7]) 
*/

    assign wire_Gx = (w0 + w1) + w2;
    assign wire_Gy = (w3 + w4) + w5;


    assign absGradient = (gradient[`BIT_LENGTH_GRD-1]) ? (~gradient + 8'd1) : gradient ;

    assign sign_xor = wire_Gx[`BIT_LENGTH_GRD - 1] ^ wire_Gy[`BIT_LENGTH_GRD-1];

    assign absGx = (wire_Gx[`BIT_LENGTH_GRD-1]) ? (~wire_Gx + 8'd1) : wire_Gx ;
    assign absGy = (wire_Gy[`BIT_LENGTH_GRD-1]) ? (~wire_Gy + 8'd1) : wire_Gy ;


/*
    assign absGx = (wire_Gx[`BIT_LENGTH_GRD-1]) ? (-1*wire_Gx) : wire_Gx ;
    assign absGy = (wire_Gy[`BIT_LENGTH_GRD-1]) ? (-1*wire_Gy) : wire_Gy ;
*/
    assign gradient = (absGx + absGy);

    assign Gxt = {2'b00,absGx[`BIT_LENGTH_GRD - 1 : 2]} + {3'b000,absGx[`BIT_LENGTH_GRD - 1 : 3]} + {5'b00000,absGx[`BIT_LENGTH_GRD - 1 : 5]} + {7'b0000000,absGx[`BIT_LENGTH_GRD - 1] };
    assign Gyt = {2'b00,absGy[`BIT_LENGTH_GRD - 1 : 2]} + {3'b000,absGy[`BIT_LENGTH_GRD - 1 : 3]} + {5'b00000,absGy[`BIT_LENGTH_GRD - 1 : 5]} + {7'b0000000,absGy[`BIT_LENGTH_GRD - 1] };

    assign w20 = Gxt > absGy ? 1 : 0;
    assign w21 = Gyt > absGx ? 1 : 0;
    
    assign w23 = { w20 , w21 , sign_xor };

    always@(w20 or w21 or sign_xor) begin
        case (w23)
            3'b100   : r_angle = 2'b00;// 0 degree
            3'b101   : r_angle = 2'b00;
            3'b110   : r_angle = 2'b00;
            3'b111   : r_angle = 2'b00;
    
            3'b000   : r_angle = 2'b01;//45
    
            3'b001   : r_angle = 2'b11;//135
    
            3'b011   : r_angle = 2'b10;//90
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
            reg_pixel_col2[0] <= pixel_in1;
            reg_pixel_col2[1] <= pixel_in2;
            reg_pixel_col2[2] <= pixel_in3;

            state      <= next_state;
            output_r   <= output_w;
            ang_output_r <= ang_output_w;
            readable_r <= readable_w;
        end
    end

endmodule