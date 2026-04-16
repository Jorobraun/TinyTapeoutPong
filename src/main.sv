`default_nettype none

`include "hvsync_generator.sv"

module main (
  // Diese Sachen werden wie Python File gesteuert.
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);
  wire hsync, vsync, display_on;
  wire [9:0] hpos;
  wire [9:0] vpos;


  // Hilfszeug für Display berechnung.
  hvsync_generator hvsync_generator (
    clk,
    ~rst_n,
    hsync,
    vsync,
    display_on,
    hpos,
    vpos
  );

  assign uo_out = {hsync, 1'b0, 1'b1, 1'b0, vsync, 1'b0, 1'b1, 1'b0};

  // Wir dumben eine wave.vcd datei raus um zu verstehen was abgeht.
  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, main);
  end

endmodule
