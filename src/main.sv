`default_nettype none

`include "hvsync_generator.sv"
`include "alus.sv"
`include "fliplflops.sv"

module Pong (
  input wire clk,
  input wire frame_tick,
  input wire reset,
  input wire [9:0] xpos,
  input wire [9:0] ypos,
  output wire [1:0] red,
  output wire [1:0] green,
  output wire [1:0] blue
);
  reg [6:0] ball_x_pos;
  reg [5:0] ball_y_pos;

  wire coll = (xpos == ball_x_pos) && (ypos == ball_y_pos);

  assign red   = coll ? 2'b11 : 2'b00;
  assign green = coll ? 2'b11 : 2'b00;
  assign blue  = coll ? 2'b11 : 2'b00;

  always @(posedge clk) begin
    if (frame_tick) begin
      ball_x_pos <= ball_x_pos + 1;
      ball_y_pos <= ball_y_pos + 1;
    end
    if (reset) begin
      ball_x_pos <= 0;
      ball_y_pos <= 0;
    end
  end

endmodule

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
  wire hsync, vsync, display_on, frame_tick;
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
    vpos,
    frame_tick
  );

  // assign uo_out = {hsync, 1'b0, 1'b1, 1'b0, vsync, 1'b0, 1'b1, 1'b0};

  assign uo_out[3] = hsync;
  assign uo_out[7] = vsync;

  Pong pong (
    clk,
    frame_tick,
    ~rst_n,
    vpos,
    hpos,
    {uo_out[0], uo_out[4]},
    {uo_out[1], uo_out[5]},
    {uo_out[2], uo_out[6]}
  );

  // Wir dumben eine wave.vcd datei raus um zu verstehen was abgeht.
  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, main);
  end

endmodule
