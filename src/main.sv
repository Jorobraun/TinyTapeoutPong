`default_nettype none

`include "hvsync_generator.sv"

module Digit_Renderer (
  input wire [3:0] value,
  input wire [6:0] x_offset,
  input wire [5:0] y_offset,
  input wire [6:0] xpos,
  input wire [5:0] ypos,
  output wire draw
);
  reg [6:0] segments;
  always @(*) begin
    case (value)
      4'd0: segments = 7'b1111110;
      4'd1: segments = 7'b0110000;
      4'd2: segments = 7'b1101101;
      4'd3: segments = 7'b1111001;
      4'd4: segments = 7'b0110011;
      4'd5: segments = 7'b1011011;
      4'd6: segments = 7'b1011111;
      4'd7: segments = 7'b1110000;
      4'd8: segments = 7'b1111111;
      4'd9: segments = 7'b1111011;
      default: segments = 7'b0000000;
    endcase
  end

  wire [6:0] dx = xpos - x_offset;
  wire [5:0] dy = ypos - y_offset;

  assign draw = (segments[6] && dy < 2 && dx < 6) ||  // a
    (segments[5] && dx >= 4 && dx < 6 && dy < 6) ||  // b
    (segments[4] && dx >= 4 && dx < 6 && dy >= 4 && dy < 10) ||  // c
    (segments[3] && dy >= 8 && dy < 10 && dx < 6) ||  // d
    (segments[2] && dx < 2 && dy >= 4 && dy < 10) ||  // e
    (segments[1] && dx < 2 && dy < 6) ||  // f
    (segments[0] && dy >= 4 && dy < 6 && dx < 6);  // g
endmodule

module Schlaeger (
  input wire clk,
  input wire frame_tick,
  input wire reset,
  input wire move_down,
  input wire move_up,
  output reg [5:0] pos
);
  always @(posedge clk) begin
    if (reset) pos <= 28;
    else if (frame_tick) begin
      if (move_down && (pos < 55)) pos <= pos + 1;
      if (move_up && (pos > 0)) pos <= pos - 1;
    end
  end
endmodule

module Schlaeger_collide (
  input wire [5:0] pos,
  input wire [5:0] mesure_pos,
  output wire res
);
  assign res = (mesure_pos >= pos) && ({1'b0, mesure_pos} < ({1'b0, pos} + 7'd9));
endmodule

module Pong #(
  parameter [6:0] player1_schlaeger_x = 10,
  parameter [6:0] player2_schlaeger_x = 85
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
  wire [5:0] player1_y, player2_y;
  wire ball_hits_p1_y, ball_hits_p2_y;

  Schlaeger p1_ctrl (
    .clk(clk),
    .reset(reset),
    .frame_tick(frame_tick),
    .move_down(player1_down),
    .move_up(player1_up),
    .pos(player1_y)
  );
  Schlaeger p2_ctrl (
    .clk(clk),
    .reset(reset),
    .frame_tick(frame_tick),
    .move_down(player2_down),
    .move_up(player2_up),
    .pos(player2_y)
  );


  reg [6:0] ball_x_pos;
  reg [5:0] ball_y_pos;

  Schlaeger_collide phys_p1 (
    .pos(player1_y),
    .mesure_pos(ball_y_pos),
    .res(ball_hits_p1_y)
  );
  Schlaeger_collide phys_p2 (
    .pos(player2_y),
    .mesure_pos(ball_y_pos),
    .res(ball_hits_p2_y)
  );

  reg ball_x_dir, ball_y_dir;
  reg [7:0] xpattern = 8'b11111111,
   ypattern = 8'b10000010;
  reg [2:0] currentpatternindex;


  parameter [7:0] pattern4x = 8'b11111111;
  parameter [7:0] pattern4y = 8'b00000000;

  parameter [7:0] pattern35x = 8'b01110111;
  parameter [7:0] pattern35y = 8'b11001100;

  parameter [7:0] pattern26x = 8'b10101010;
  parameter [7:0] pattern26y = 8'b10101010;

  parameter [7:0] pattern17x = 8'b10001000;
  parameter [7:0] pattern17y = 8'b00110011;

  parameter [7:0] pattern08x = 8'b10000000;
  parameter [7:0] pattern08y = 8'b00010001;
  


  reg [7:0] scoreP1, scoreP2;
  wire [6:0] next_ball_x = ball_x_dir ? (ball_x_pos - xpattern[currentpatternindex]) 
                                    : (ball_x_pos + xpattern[currentpatternindex]);
  wire [5:0] next_ball_y = ball_y_dir ? (ball_y_pos - ypattern[currentpatternindex]) 
                                      : (ball_y_pos + ypattern[currentpatternindex]);

  wire [5:0] next_hit_p1 = next_ball_y - player1_y;

  always @(posedge clk) begin
    
    if (reset) begin
      currentpatternindex = 0; 
      xpattern = pattern4x;
      ypattern = pattern4y;
      ball_x_pos <= 48;
      ball_y_pos <= 32;
      ball_x_dir <= 0;
      ball_y_dir <= 1;
      scoreP1 <= 8'h00;
      scoreP2 <= 8'h00;
    end else if (frame_tick) begin
      
      currentpatternindex <= currentpatternindex + 1; 
      
      if (ball_x_pos >= 95 || ball_x_pos <= 1) begin //check if hit end wall
        // Score Logic for P1
        if (ball_x_pos >=  95) begin
          if (scoreP1[3:0] == 4'd9) begin
            scoreP1[3:0] <= 4'd0;
            scoreP1[7:4] <= (scoreP1[7:4] == 4'd9) ? 4'd0 : scoreP1[7:4] + 1'b1;
          end else scoreP1[3:0] <= scoreP1[3:0] + 1'b1;
        end  // Score Logic for P2
        else begin
          if (scoreP2[3:0] == 4'd9) begin
            scoreP2[3:0] <= 4'd0;
            scoreP2[7:4] <= (scoreP2[7:4] == 4'd9) ? 4'd0 : scoreP2[7:4] + 1'b1;
          end else scoreP2[3:0] <= scoreP2[3:0] + 1'b1;
        end

        ball_x_pos <= 48;
        ball_y_pos <= 32;
        ball_x_dir <= ~ball_x_dir;
      end else begin
        if (ball_y_pos == 0 && ball_y_dir == 1) begin // check if top intersection
          ball_y_dir <= 0; //change move direction away from top
          
          if ((next_ball_x == player1_schlaeger_x && ball_hits_p1_y) || 
              (next_ball_x == player2_schlaeger_x && ball_hits_p2_y)) begin
            ball_x_dir <= ~ball_x_dir;
            xpattern <= pattern26x;
            ypattern <= pattern26y;
            currentpatternindex <= 1;
            ball_y_pos <= ball_y_pos + 1'b1;
            ball_x_pos <= ball_x_dir ? (ball_x_pos + 1'b1) : (ball_x_pos - 1'b1);
          end else begin
            if (xpattern[currentpatternindex]) begin
            ball_x_pos <= ball_x_dir ? (ball_x_pos - 1'b1) : (ball_x_pos + 1'b1);
            if (ypattern[currentpatternindex]) begin
            ball_y_pos <= (ball_y_pos + 1'b1);
          end
          end

          end
          
        end else if (ball_y_pos == 63 && ball_y_dir == 0) begin
          ball_y_dir <= 1;

          
          if ((next_ball_x == player1_schlaeger_x && ball_hits_p1_y) || 
              (next_ball_x == player2_schlaeger_x && ball_hits_p2_y)) begin
            ball_x_dir <= ~ball_x_dir;
            xpattern <= pattern26x;
            ypattern <= pattern26y;
            currentpatternindex <= 1;
            ball_y_pos <= ball_y_pos - 1'b1;
            ball_x_pos <= ball_x_dir ? (ball_x_pos + 1'b1) : (ball_x_pos - 1'b1);
          end else begin
            if (xpattern[currentpatternindex]) begin
            ball_x_pos <= ball_x_dir ? (ball_x_pos - 1'b1) : (ball_x_pos + 1'b1);
            if (ypattern[currentpatternindex]) begin
            ball_y_pos <= (ball_y_pos - 1'b1);
          end

          end
          
          end
      end


      else if (ball_x_dir == 1 && next_ball_x <= player1_schlaeger_x && ball_x_pos > player1_schlaeger_x && next_ball_y >= player1_y && next_ball_y <= (player1_y + 8)) begin 
        ball_x_dir <= 0; 
        ball_x_pos <= player1_schlaeger_x + 1;
        
        //different velocities and angles based on paddle hit location
        case (next_hit_p1)
            6'd0, 6'd8: begin xpattern <= pattern08x; ypattern <= pattern08y; end
            6'd1, 6'd7: begin xpattern <= pattern17x; ypattern <= pattern17y; end
            6'd2, 6'd6: begin xpattern <= pattern26x; ypattern <= pattern26y; end
            6'd3, 6'd5: begin xpattern <= pattern35x; ypattern <= pattern35y; end
            default:    begin xpattern <= pattern4x;  ypattern <= pattern4y;  end
        endcase

        // direction based on if hit on top or bottom
        if (next_hit_p1 < 4) ball_y_dir <= 1; 
        else if (next_hit_p1 > 4) ball_y_dir <= 0;

        // take first step
        currentpatternindex <= 1; 
        ball_y_pos <= (next_hit_p1 < 4) ? (ball_y_pos - ypattern[0]) : (ball_y_pos + ypattern[0]);
    end
    else if (ball_x_dir == 0 && next_ball_x >= player2_schlaeger_x && ball_x_pos < player2_schlaeger_x && next_ball_y >= player2_y && next_ball_y <= (player2_y + 8)) begin 
      ball_x_dir <= 1; // Bounce Left
      ball_x_pos <= player2_schlaeger_x - 1;
      
      // Calculate where on the paddle the ball hit
      // Using a wire or temp reg for next_hit_p2 would be cleaner, but we can do it inline:
      case (next_ball_y - player2_y)
          6'd0, 6'd8: begin xpattern <= pattern08x; ypattern <= pattern08y; end
          6'd1, 6'd7: begin xpattern <= pattern17x; ypattern <= pattern17y; end
          6'd2, 6'd6: begin xpattern <= pattern26x; ypattern <= pattern26y; end
          6'd3, 6'd5: begin xpattern <= pattern35x; ypattern <= pattern35y; end
          default:    begin xpattern <= pattern4x;  ypattern <= pattern4y;  end
      endcase

      // Set Y direction: Top of paddle bounces up (1), bottom bounces down (0)
      if ((next_ball_y - player2_y) < 4) ball_y_dir <= 1; 
      else if ((next_ball_y - player2_y) > 4) ball_y_dir <= 0;

      // Reset pattern index and take the first step immediately
      currentpatternindex <= 1; 
      ball_y_pos <= ((next_ball_y - player2_y) < 4) ? (ball_y_pos - ypattern[0]) : (ball_y_pos + ypattern[0]);
    end else begin
        if (xpattern[currentpatternindex]) begin
          ball_x_pos <= ball_x_dir ? (ball_x_pos - 1'b1) : (ball_x_pos + 1'b1);
        end
        if (ypattern[currentpatternindex]) begin
          ball_y_pos <= ball_y_dir ? (ball_y_pos - 1'b1) : (ball_y_pos + 1'b1);
        end
        end

      end
    end
  end

  // Score Rendering 
  wire d1t, d1o, d2t, d2o;
  // Player 1 (Red) 
  Digit_Renderer p1t (
    .value(scoreP1[7:4]),
    .x_offset(7'd22),
    .y_offset(6'd5),
    .xpos(xpos),
    .ypos(ypos),
    .draw(d1t)
  );
  Digit_Renderer p1o (
    .value(scoreP1[3:0]),
    .x_offset(7'd30),
    .y_offset(6'd5),
    .xpos(xpos),
    .ypos(ypos),
    .draw(d1o)
  );
  // Player 2 (Green) 
  Digit_Renderer p2t (
    .value(scoreP2[7:4]),
    .x_offset(7'd60),
    .y_offset(6'd5),
    .xpos(xpos),
    .ypos(ypos),
    .draw(d2t)
  );
  Digit_Renderer p2o (
    .value(scoreP2[3:0]),
    .x_offset(7'd68),
    .y_offset(6'd5),
    .xpos(xpos),
    .ypos(ypos),
    .draw(d2o)
  );

  // Game Rendering
  wire coll_ball = (xpos == ball_x_pos) && (ypos == ball_y_pos);
  wire draw_p1, draw_p2;
  Schlaeger_collide disp_p1 (
    .pos(player1_y),
    .mesure_pos(ypos),
    .res(draw_p1)
  );
  Schlaeger_collide disp_p2 (
    .pos(player2_y),
    .mesure_pos(ypos),
    .res(draw_p2)
  );

  wire game_white = coll_ball || (xpos == player1_schlaeger_x && draw_p1) || (xpos == player2_schlaeger_x && draw_p2);

  // Colors
  assign red   = game_white ? 2'b11 : ((d1t || d1o) ? 2'b11 : 2'b00);
  assign green = game_white ? 2'b11 : ((d2t || d2o) ? 2'b11 : 2'b00);
  assign blue  = game_white ? 2'b11 : 2'b00;

endmodule


module main (
  input  wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire       ena,
  input  wire       clk,
  input  wire       rst_n
);
  wire hsync, vsync, display_on, frame_tick;
  wire [6:0] hpos;
  wire [5:0] vpos;
  wire [1:0] r, g, b;

  hvsync_generator hvsync_gen (
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(display_on),
    .hpos(hpos),
    .vpos(vpos),
    .frame_tick(frame_tick)
  );

  Pong pong (
    .clk(clk),
    .frame_tick(frame_tick),
    .reset(~rst_n),
    .player1_down(ui_in[0]),
    .player1_up(ui_in[1]),
    .player2_down(ui_in[2]),
    .player2_up(ui_in[3]),
    .xpos(hpos),
    .ypos(vpos),
    .red(r),
    .green(g),
    .blue(b)
  );

  assign uo_out[0] = r[1];
  assign uo_out[1] = g[1];
  assign uo_out[2] = b[1];
  assign uo_out[3] = hsync;
  assign uo_out[4] = r[0];
  assign uo_out[5] = g[0];
  assign uo_out[6] = b[0];
  assign uo_out[7] = vsync;
  assign uio_out = 8'b0;
  assign uio_oe = 8'b0;
endmodule
