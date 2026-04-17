`ifndef ALUS_H
`define ALUS_H

module Adder (
  input in1,
  input in2,
  input cin,

  output res,
  output cres
);

  assign res  = in1 ^ in2 ^ cin;
  assign cres = (in1 & in2) | (in1 & cin) | (in2 & cin);
endmodule

module ByteSpeicher (
  input [7:0] set,
  input clock,
  output [7:0] out
);

  generate
    for (genvar i = 0; i < 8; i = i + 1) begin : gen_memory
      D_Flip_Flop memory_cell (
        .in   (set[i]),
        .clock(clock),
        .out  (out[i])
      );
    end
  endgenerate
endmodule

module ByteAdder (
  input [7:0] in1,
  input [7:0] in2,
  input carry_in,
  output [7:0] out
);

  wire [7:0] carry;

  generate
    for (genvar i = 0; i < 8; i = i + 1) begin : gen_adder
      if (i == 0) begin : gen_first
        Adder adder (
          .in1 (in1[i]),
          .in2 (in2[i]),
          .cin (carry_in),
          .res (out[i]),
          .cres(carry[i])
        );
      end else begin : gen_second
        Adder adder (
          .in1 (in1[i]),
          .in2 (in2[i]),
          .cin (carry[i-1]),
          .res (out[i]),
          .cres(carry[i])
        );
      end
    end

  endgenerate

endmodule

module Add_sub_alu (
  input reset,
  input sub,
  input clock,
  input [7:0] in,
  output [7:0] out
);

  wire [7:0] speicher_out;
  wire [7:0] speicher_in;
  wire [7:0] korrigiert;

  ByteSpeicher byteSpeicher1 (
    .set  (speicher_in),
    .clock(clock),
    .out  (speicher_out)
  );

  ByteAdder byteAdder (
    .in1(speicher_out),
    .in2(korrigiert),
    .carry_in(sub),
    .out(out)
  );

  generate
    for (genvar i = 0; i < 8; i = i + 1) begin : reset_mechanismus
      assign speicher_in[i] = out[i] & reset;
      assign korrigiert[i]  = in[i] ^ sub;
    end
  endgenerate

endmodule

module test;
  reg clk;
  reg reset;
  reg sub;

  reg [7:0] in;
  wire [7:0] out;

  Add_sub_alu add_sub_alu (
    .reset(reset),
    .sub  (sub),
    .clock(clk),
    .in   (in),
    .out  (out)
  );

  always begin
    #5 clk = ~clk;
  end

  initial begin
    clk = 0;

    $dumpfile("wave.vcd");
    $dumpvars(0, test);

    #200 $finish;
  end

  initial begin
    reset = 0;
    in = 8'b1111;

    #5 reset = 1;

    sub = 0;

    #50 sub = 1;
  end

endmodule

`endif
