`default_nettype none

`include "hvsync_generator.sv"
`include "alus.sv"
`include "fliplflops.sv"

module Schlaeger (
  input wire clk,
  input wire frame_tick,
  input wire reset,
  input wire move_down,
  input wire move_up,
  output reg [5:0] pos
);
  always @(posedge clk) begin
    if (reset) begin
      pos <= 32;
    end
    if (frame_tick) begin
      if (move_down) begin
        pos <= pos - 1;
      end
      if (move_up) begin
        pos <= pos + 1;
      end
    end
  end
endmodule

module Schlaeger_collide (
  input wire [5:0] pos,
  input wire [5:0] mesure_pos,
  output wire res
);
  assign res = pos == mesure_pos;
endmodule

module Pong #(
  parameter [6:0] player1_schlaeger_pos = 10,
  parameter [6:0] player2_schlaeger_pos = 80
) (
  input wire clk,
  input wire frame_tick,
  input wire reset,
  input wire player1_down,
  input wire player2_down,
  input wire player1_up,
  input wire player2_up,
  input wire [6:0] xpos,
  input wire [5:0] ypos,
  output wire [1:0] red,
  output wire [1:0] green,
  output wire [1:0] blue
);
  wire [5:0] player1_pos;
  wire [5:0] player2_pos;

  wire collides_player1;
  wire collides_player2;

  Schlaeger schlaeger1 (
    .clk       (clk),
    .reset     (reset),
    .frame_tick(frame_tick),
    .move_down (player1_down),
    .move_up   (player1_up),
    .pos       (player1_pos)
  );

  Schlaeger schlaeger2 (
    .clk       (clk),
    .reset     (reset),
    .frame_tick(frame_tick),
    .move_down (player2_down),
    .move_up   (player2_up),
    .pos       (player2_pos)
  );

  Schlaeger_collide schlaeger_collide1 (
    .pos       (player1_pos),
    .mesure_pos(ypos),
    .res       (collides_player1)
  );

  Schlaeger_collide schlaeger_collide2 (
    .pos       (player2_pos),
    .mesure_pos(ypos),
    .res       (collides_player2)
  );

  reg [6:0] ball_x_pos;
  reg [5:0] ball_y_pos;

  wire coll_ball = (xpos == ball_x_pos) && (ypos == ball_y_pos);
  wire is_white = coll_ball || ((xpos == player1_schlaeger_pos) && collides_player1) 
                            || ((xpos == player2_schlaeger_pos) && collides_player2);

  // Ball
  assign red   = is_white ? 2'b11 : 2'b00;
  assign green = is_white ? 2'b11 : 2'b00;
  assign blue  = is_white ? 2'b11 : 2'b00;

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
  wire [6:0] hpos;
  wire [5:0] vpos;

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
    ui_in[0],
    ui_in[2],
    ui_in[1],
    ui_in[3],
    hpos,
    vpos,
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
