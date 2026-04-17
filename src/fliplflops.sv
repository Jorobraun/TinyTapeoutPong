`ifndef FLIPFLOPS_H
`define FLIPFLOPS_H

module sr_latch (
  input  in_set,
  input  in_reset,
  output out
);
  wire out_r;

  nand g1 (out, in_set, out_r);
  nand g2 (out_r, in_reset, out);
endmodule

module D_sr_latch (
  input  in,
  input  clock,
  output out
);

  sr_latch l1 (
    .in_set(~(clock & in)),
    .in_reset(~(clock & ~in)),
    .out(out)
  );

endmodule

module D_Flip_Flop (
  input  in,
  input  clock,
  output out
);

  wire between;

  D_sr_latch d_SR_Latch1 (
    .in   (in),
    .clock(~clock),
    .out  (between)
  );

  D_sr_latch d_SR_Latch2 (
    .in   (between),
    .clock(clock),
    .out  (out)
  );

endmodule

`endif
