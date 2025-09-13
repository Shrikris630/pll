/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_adpll (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

 // All output pins must be assigned. If not used, assign to 0.
  wire samp_clk;
  wire rst; 
  wire clk90;
  wire clk_ref;
  wire clr;
  wire pgm;
  wire out_sel;
  wire [2:0]param_sel; 
  wire fb_clk;
  wire dco_out;
  wire  [4:0]pgm_value;
  wire [4:0] dout;
  wire sign;
  wire dummy;
  wire dummy2;
  wire dummy3;
  wire dummy4;
  
 
  assign samp_clk = clk;                 // 50MHz clock
  assign rst = rst_n;                    // Reset
  assign clk90 = ui_in[0];               // 50MHz with 90 degree phase-shift
  assign clk_ref = ui_in[1];             // Input reference clock
  assign clr = ui_in[2];                 // Clear command : set 1 to clear all the pgmmed values else keep 0
  assign pgm = ui_in[3];                  // pgm : set 1 to pgm values else keep 0
  assign out_sel= ui_in[4] ;             // Output selector: set 0 to get filter output and 1 to get integral path output
  assign param_sel = ui_in[7:5];         // Parameter selector : Select the parameter to be pgmmed
  assign pgm_value = uio_in[6:2];        // pgm value
  assign dummy2 = uio_in[0];
  assign dummy3 = uio_in[1];
  assign dummy = uio_in[7] ; 
  assign uio_out[0] = fb_clk;            // Feedback clock output
  assign uio_out[1] = dco_out;           // DCO output
 assign uio_out[2] = dummy2;
 assign uio_out[3] = dummy3;
 assign uio_out[4] = dummy2;
 assign uio_out[5] = dummy3;
 assign uio_out[6] = dummy2;
 assign uio_out[7] = dummy4;
  assign uo_out[4:0] = dout;
  assign uo_out[5] = sign;
  assign uo_out[6] = ~dummy;
  assign uo_out[7] = dummy;
  assign dummy4 = ena;
  
 // IO enable 
  assign uio_oe[1:0]=2'b11;
  assign uio_oe[6:2]= 5'd0;
  assign uio_oe[7] = 1'b0;
 
  // adpll top-level block
  adpll_top u0( .clk(samp_clk), .rst(rst),.clk90(clk90),.clk_ref(clk_ref),.clr(clr),.pgm(pgm), .out_sel(out_sel),.param_sel(param_sel),.fb_clk(fb_clk),.dco_out(dco_out),.pgm_value(pgm_value),.dout(dout),.sign(sign));
  


  // List all unused inputs to prevent warnings


endmodule

// Top level module of adpll as a chip
// In tiny tapeout we can have 8 input, 8 output, 8 bidirectional, clk and rst pins

//`include "adpll_5bit.v"
module adpll_top(
  input wire clk,
  input wire rst, 
  input wire clk90, 
  input wire clk_ref,
  input wire clr,
  input wire pgm,
  input wire out_sel,
  input wire [2:0]param_sel, 
  inout fb_clk,
  inout dco_out,
  inout  [4:0]pgm_value,
  output [4:0] dout,
  output sign);
  
  
 
  reg[4:0]alpha_var_buf;
  reg[4:0]beta_var_buf;
  reg[4:0]dco_offset_buf;
  reg[4:0]dco_thresh_buf;
  reg[4:0]kdco_buf;
  reg[3:0]ndiv;
  wire[4:0]filter_out;
  wire[4:0]integ_out;
  wire filter_sign;
  wire integ_sign;
  wire alpha_en, beta_en,dco_offset_en,dco_thresh_en,kdco_en,ndiv_ld;
  
  
  
 
   
   //pgm mode : pgm all PLL the parameters
   // pgmming is done in cycle by cycle manner, where we can sequentially pgm below
   //  *** frequency divider ***
   //  1. frequency division for frequency divider block
   //  *** Loop Filter parameters ***
   //  2. alpha
   //  3. beta
   //  **** dco parameters ***
   //  4. dco_offst
   //  5. dco_thresold
   //  6. dco_gain
   
   // Select the pgmming option
   assign ndiv_ld = (pgm) ? (param_sel==3'd0)?1:0:0;
   assign alpha_en = (pgm) ? (param_sel==3'd1)?1:0:0;
   assign beta_en = (pgm) ? (param_sel==3'd2)?1:0:0;
   assign dco_offset_en = (pgm) ? (param_sel==3'd3)?1:0:0;
   assign dco_thresh_en = (pgm) ? (param_sel==3'd4)?1:0:0;
   assign kdco_en = (pgm) ? (param_sel==3'd5)?1:0:0;


   // outputs filter data or integrator's data based on out_sel variable 
   assign {sign, dout} = (out_sel) ?{integ_sign,integ_out}:{filter_sign, filter_out};

  adpll_5bit u0( .clk(clk), .reset(rst), .clk90(clk90), .clk_ref(clk_ref),.ndiv(ndiv),.alpha_var(alpha_var_buf),.beta_var(beta_var_buf),.dco_offset(dco_offset_buf), .dco_thresh_val(dco_thresh_buf), .kdco(kdco_buf), .fb_clk(fb_clk), .integ_out(integ_out), .integ_sign(integ_sign), .filter_out(filter_out),.filter_sign(filter_sign), .dco_out(dco_out));
       
       
  // Perform pgmming    
  always@(posedge ndiv_ld or posedge clr) begin
     if(~clr) 
       ndiv <= pgm_value[3:0];
     else
       ndiv <= 4'd0;  
   end
   
  always@(posedge alpha_en or posedge clr) begin
     if(~clr)
       alpha_var_buf <= pgm_value;
     else
       alpha_var_buf <= 5'd0;
   end
   
  always@(posedge beta_en or posedge clr) begin
    if(~clr)
      beta_var_buf <= pgm_value;
    else
      beta_var_buf <= 5'd0;
   end
     
  always@(posedge dco_offset_en or posedge clr) begin
     if(~clr)
       dco_offset_buf <= pgm_value;
     else
       dco_offset_buf <= 5'd0;
   end
         
  always@(posedge dco_thresh_en or posedge clr) begin
     if(~clr) 
       dco_thresh_buf <= pgm_value;
     else
       dco_thresh_buf <= 5'd0;
   end    
     
  always@(posedge kdco_en or posedge clr) begin
     if(~clr)
       kdco_buf <= pgm_value;
     else
       kdco_buf <= 5'd0;  
   end
   
endmodule   

// 5-bit ADPLL verilog-code
//`include "pd.v"
//`include "ctr.v"
//`include "acs_5bit.v"
//`include "pi_filter_5bit.v"
//`include "dco_5bit.v"
//`include "freq_divider_5bit.v"


module adpll_5bit(
  input wire clk,
  input wire reset,
  input wire clk90,
  input wire clk_ref,
  input wire[3:0]ndiv,
  input wire[4:0]alpha_var,
  input wire[4:0]beta_var,
  input wire[4:0]dco_offset,
  input wire[4:0]dco_thresh_val,
  input wire[4:0]kdco,
  inout fb_clk,
  output [4:0] integ_out,
  output integ_sign,
  inout  [4:0] filter_out,
  inout  filter_sign,
  inout dco_out);
  
  wire up, dwn, upb, dwnb;
  wire[4:0] up_error, dwn_error;
  wire[4:0] bin_error;
  wire error_sign;
  wire freq_div_buf;
  wire clk2x;

  //1. Generate Sampling clock 2x frequency  
  assign clk2x = clk^clk90;
  assign upb = ~up;
  assign dwnb = ~dwn;
   
  //2. Phase Detection
  pd i0_pd(.clk(clk),.reset(reset), .clk_ref(clk_ref), .fb_clk(fb_clk), .up(up), .dwn(dwn));
  
  //3. Convert the phase-error to binary
  ctr i1_ctr(.clk(clk), .reset(upb), .counter(up_error));
  ctr i2_ctr(.clk(clk), .reset(dwnb), .counter(dwn_error));
  
  acs_5bit i3_sub(.sign_in1(1'b0), .in1(up_error), .sign_in2(1'b1),.in2(dwn_error), .sum(bin_error), .sign_out(error_sign));
 
  //4. Loop filter 
  pi_filter_5bit i4_pi_filter( .clk(clk), .reset(reset), .error_sign(error_sign), .error(bin_error), .alpha_var(alpha_var), .beta_var(beta_var), .integ_out(integ_out), .integ_sign(integ_sign), .filter_out(filter_out), .filter_sign(filter_sign));      

  //5. dco
  dco_5bit i5_dco(.clk(clk2x), .reset(reset), .kdco(kdco), .ctrl_sign(filter_sign), .ctrl(filter_out),.dco_offset(dco_offset), .thresh_val(dco_thresh_val),.dco_clk(dco_out));
  
  //6. Frequency divider
  freq_divider_5bit i6_freq_div(.clk(dco_out), .reset(reset), .ndiv(ndiv), .freq_div_out(freq_div_buf));
  
  //7. Mux out the frequecy divider or dco output directly
  assign fb_clk = (ndiv==4'd0)?dco_out:freq_div_buf;
  
endmodule

//Thermometer coded TDC-based Phase Detector (PD)
// Sequential PD generates up and down signal which is converted to its binary equivalent by TDC
module pd(
  input clk,
  input wire reset,
  input wire clk_ref,
  input wire fb_clk,
  output reg up,
  output reg dwn);

  reg start;
  reg reset_trig;

      //-------------------------------------------------------------
    // 1. Generate synchronous reset_trig based on UP & DWN signals
    //-------------------------------------------------------------
     always @(posedge clk or posedge reset) begin
        if (reset)
            reset_trig <= 1'b1;
        else
            reset_trig <= up & dwn;  // Reset when both UP and DWN are asserted
     end

    //-------------------------------------------------------------
    // 2. UP detection (sequential PD)
    //-------------------------------------------------------------
    always @(posedge clk_ref or posedge reset_trig) begin
        if (reset_trig)
            up <= 1'b0;
        else
            up <= start;  // Equivalent to 1'b1 & start
    end

    //-------------------------------------------------------------
    // 3. DWN detection (sequential PD)
    //-------------------------------------------------------------
    always @(posedge fb_clk or posedge reset_trig) begin
        if (reset_trig)
            dwn <= 1'b0;
        else
            dwn <= start;
    end

  // 3. Start the phase detection after Clock arrival
  always@(posedge clk_ref or posedge reset) begin
    if(reset)
      start <= 1'b0;
    else 
      start <= 1'b1;
  end

endmodule

module ctr(
  input clk,
  input reset,
  output reg [4:0] counter
);


  // use bits of (4-bit) counter to divide clocks
  
always @(posedge clk or posedge reset)
  begin
    if (reset)
      counter <= 0;
    else
      counter <= counter + 1;
  end

endmodule





// 5-bit PI filter
// Receives the phase-error and takes its average
//`include "acs_5bit.v"
module pi_filter_5bit(
  input wire clk,
  input wire reset,
  input wire error_sign,
  input wire [4:0]error,
  input wire [4:0]alpha_var,
  input wire [4:0]beta_var,
  output [4:0]integ_out,
  output integ_sign,
  output [4:0]filter_out,
  output filter_sign);
  
  reg [4:0]integ_store;
  reg integ_store_sign;
  wire [4:0]integ_var;
  wire [4:0]prop_var;
 
 
  //1, Proportional Path
  assign prop_var = error*beta_var;

  //2. integral path
  assign integ_var = error*alpha_var;
  
  // 2.1. Delay the data
  always@(posedge clk or posedge reset) begin
    if(reset) begin
      integ_store <=5'd0;
      integ_store_sign <= 1'b0;
    end
    else begin    
      integ_store <= integ_out;
      integ_store_sign <= integ_sign;
    end   
  end 

  // 2.2. Add the delayed data with 
  acs_5bit acs0(.sign_in1(error_sign), .in1(integ_var), .sign_in2(integ_store_sign),.in2(integ_store), .sum(integ_out), .sign_out(integ_sign));

  //3. filter_out
  acs_5bit acs1(.sign_in1(error_sign), .in1(prop_var), .sign_in2(integ_sign),.in2(integ_out), .sum(filter_out), .sign_out(filter_sign));
  

endmodule  

// dco module
// Receives the filter output and generates the proportional time-period
//`include "acs_5bit.v"
module dco_5bit(
  input wire clk,
  input wire reset,
  input wire[4:0] kdco,
  input wire ctrl_sign,
  input wire [4:0] ctrl,
  input wire [4:0] dco_offset,
  input wire [4:0] thresh_val,
  output reg dco_clk
);

  wire [4:0] ctrl_buf;
  wire [4:0] thresh;
  wire [4:0] thresh_buf, thresh_buf2;
  wire thresh_sign;
  wire [4:0] phase;             
  reg [4:0] counter;           

  // 1. Buffer the control input for reset logic
  assign ctrl_buf = (reset) ? 5'd0 : ctrl;

  // 2. Calculate phase (widen to 6 bits to prevent overflow in phase calculation)
  assign phase = (ctrl_buf * kdco)>>1;  // Multiply control value with DCO constant

  // 3. Modulate the DCO threshold based on phase.
  acs_5bit acs0(.sign_in1(1'b0), .in1(thresh_val), .sign_in2((~ctrl_sign)),.in2(phase), .sum(thresh_buf), .sign_out(thresh_sign));
  
  // 4. Add offset to prevent threshold getting negative values   
  assign thresh_buf2 = thresh_buf + dco_offset;
     
  // 5. Saturating threshold handling (clamp between 0 and 31)
  assign thresh = (thresh_sign) ? 5'd0 : (thresh_buf2 > 5'd30) ? 5'd31 : thresh_buf2;
    
  // 6. Update threshold and toggle DCO clock based on the counter
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      dco_clk <= 1'b0;
      counter <= 5'd0;
    end else begin
      // 6.1. Compare the counter data with threshold
      if (counter >= thresh) begin
        // 6.2. Flip the DCO output when threshold is crossed
        dco_clk <= ~dco_clk;               
        // 6.3. Reset counter to offset
        counter <= dco_offset;    
      end else begin
        // 6.4. Increment counter otherwise
        counter <= counter + 1;            
      end
    end
  end 
 
 

endmodule

// Programmable frequency divider
module freq_divider_5bit(
  input wire clk,
  input wire reset,
  input wire [3:0]ndiv,
  output reg freq_div_out);
  
  wire [3:0] thresh;
  reg [3:0] counter;
  
 
 // 1. Left shift ndiv considering half the time-period
  assign thresh = ndiv >> 1;
  
  always@(posedge clk or posedge reset ) begin
    if(reset) begin
      counter <= 4'd0;
      freq_div_out <= 0;
    end
    else begin
      //2. Compare the counter with threshold
      if(counter >= thresh) begin
        // 3. Toggle frequency divider output if counter >= threshold
        freq_div_out <= ~freq_div_out;
        // 4. Reset the counter if counter >= threshold
        counter <= 4'd0;
      end
      else begin
        // 6. Increment counter if not true
        counter <= counter + 1;
      end
    end
  end   
endmodule  

// 5-bit Adder cum subtractor (ACS)
// Inputs are 5-bit data and their signs 
// Output is addition/subtraction result with sign
module acs_5bit(
  input wire sign_in1,      // Sign bit for input 1
  input wire [4:0] in1,     // 5-bit input 1
  input wire sign_in2,      // Sign bit for input 2
  input wire [4:0] in2,     // 5-bit input 2
  output wire [4:0] sum,    // 5-bit output sum/result
  output wire sign_out      // Sign of the output result
);

  wire [4:0] in1_buf, in2_buf; // Buffers for the inputs, possibly in 2's complement form
  wire [4:0] sbuf;             // Sum buffer (output of addition/subtraction)
  wire [4:0] result;           // Result buffer for 6-bit sum (including sign)
  wire [4:0] min1, min2;
  wire comp;
  wire eq;
  
  // 1. Convert inputs to 2's complement if the sign bit is 1 (negative)
  assign min1 = ~in1 + 1;
  assign min2 = ~in2 + 1;
  
  // 2. Select Positive or Negative number depending on sign
  assign in1_buf = (sign_in1) ?  min1 : in1; 
  assign in2_buf = (sign_in2) ?  min2 : in2; 
  
  // 3. Perform Addition or Subtraction
  assign result = in1_buf + in2_buf; 
  
  // 4. Extract the 5-bit sum (ignoring the overflow from 6th bit)
  assign sbuf = result; 
  
  // 5. Output Sign logic
  assign comp = (in1 > in2) ? 1'b1:1'b0;
  assign eq = (in1 == in2) ? 1'b1:1'b0;
  assign sign_out = ((sign_in1 & sign_in2)|(sign_in2 & (~comp))|(sign_in1 & comp))&(~eq)|(sign_in1 & sign_in2 & (~comp) & eq) ; 

  // 6. Compute 2's complement if the result is negative
  assign sum = (sign_out) ? ~sbuf + 1 : sbuf;

endmodule
