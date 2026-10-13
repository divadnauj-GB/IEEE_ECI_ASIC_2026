/*
 * Copyright (c) 2024 Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module snake_game (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);


  wire trigger;
  localparam CLK_FREQ = 25000000;
  localparam DEBOUNCE_FREQ = 100000;
  localparam DEBOUNCE_TIME = CLK_FREQ / (10 * DEBOUNCE_FREQ);


  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;
  reg signed [$clog2(DEBOUNCE_TIME):0] debounce_counter;
  reg [1:0] user_dir;
  reg game_tick;
  reg [4:0] frame_count;
  wire frame_tick = (pix_x == 10'd0) && (pix_y == 10'd480);
  wire clean_key3;
  wire clean_key2;
  wire clean_key1;
  wire clean_key0;

  // TinyVGA PMOD
  assign uo_out  = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;


  wire _unused_ok = &{ena, ui_in, uio_in};

  /*VGA sync signals generation*/
  hvsync_generator hvsync_gen (
      .clk(clk),
      .reset(~rst_n),
      .hsync(hsync),
      .vsync(vsync),
      .display_on(video_active),
      .hpos(pix_x),
      .vpos(pix_y)
  );

  /*Snake game implementation sync with vga timing signals*/
  game_core snake (
      .clk(clk),
      .rst_n(rst_n),
      .cell_x(pix_x[9:5]),
      .cell_y(pix_y[8:5]),
      .video_active(video_active),
      .game_tick(game_tick),
      .user_dir(user_dir),
      .R(R),
      .G(G),
      .B(B)
  );

  /*Debounce timer logic*/
  assign trigger = (debounce_counter == DEBOUNCE_TIME) ? 1'b1 : 1'b0;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      debounce_counter <= 0;
    end else if (trigger == 1'b1) begin
      debounce_counter <= 0;  // Hold the counter value
    end else begin
      debounce_counter <= debounce_counter + 1;
    end
  end

  /*Debounce circuits for each push button*/
  debounce buttUp (
      .clk(clk),
      .rst_n(rst_n),
      .trigger(trigger),
      .input_signal(ui_in[3]),
      .clean_signal(clean_key3)
  );

  debounce buttDwn (
      .clk(clk),
      .rst_n(rst_n),
      .trigger(trigger),
      .input_signal(ui_in[2]),
      .clean_signal(clean_key2)
  );

  debounce buttL (
      .clk(clk),
      .rst_n(rst_n),
      .trigger(trigger),
      .input_signal(ui_in[1]),
      .clean_signal(clean_key1)
  );

  debounce buttR (
      .clk(clk),
      .rst_n(rst_n),
      .trigger(trigger),
      .input_signal(ui_in[0]),
      .clean_signal(clean_key0)
  );

  /*Push buttons encoder*/
  always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      user_dir <= 2'b11;  // Al resetear, la serpiente apunta a la derecha
    end else begin
      casez ({
        clean_key3, clean_key2, clean_key1, clean_key0
      })
        4'b0001: user_dir <= 2'b11;
        4'b001?: user_dir <= 2'b10;
        4'b01??: user_dir <= 2'b01;
        4'b1???: user_dir <= 2'b00;
        default: user_dir <= user_dir;
      endcase
    end
  end

  /*Game tick generation based on the VGA sync signals, the game updates every 15 frames (500ms approx)*/
  always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      frame_count <= 0;
      game_tick   <= 1'b0;
    end else begin
      if (frame_tick) begin
        game_tick   <= 1'b0;
        frame_count <= frame_count + 1;
      end else begin
        if (frame_count == 5'd20) begin
          game_tick   <= 1'b1;
          frame_count <= 0;
        end else begin
          game_tick <= 1'b0;
        end
      end
    end
  end

endmodule


`ifndef HVSYNC_GENERATOR_H
`define HVSYNC_GENERATOR_H

/*
Video sync generator, used to drive a VGA monitor.
Timing from: https://en.wikipedia.org/wiki/Video_Graphics_Array
To use:
- Wire the hsync and vsync signals to top level outputs
- Add a 3-bit (or more) "rgb" output to the top level
*/

module hvsync_generator (
    clk,
    reset,
    hsync,
    vsync,
    display_on,
    hpos,
    vpos
);

  input clk;
  input reset;
  output reg hsync, vsync;
  output display_on;
  output reg [9:0] hpos;
  output reg [9:0] vpos;

  // declarations for TV-simulator sync parameters
  // horizontal constants
  parameter H_DISPLAY = 640;  // horizontal display width
  parameter H_BACK = 48;  // horizontal left border (back porch)
  parameter H_FRONT = 16;  // horizontal right border (front porch)
  parameter H_SYNC = 96;  // horizontal sync width
  // vertical constants
  parameter V_DISPLAY = 480;  // vertical display height
  parameter V_TOP = 33;  // vertical top border
  parameter V_BOTTOM = 10;  // vertical bottom border
  parameter V_SYNC = 2;  // vertical sync # lines
  // derived constants
  parameter H_SYNC_START = H_DISPLAY + H_FRONT;
  parameter H_SYNC_END = H_DISPLAY + H_FRONT + H_SYNC - 1;
  parameter H_MAX = H_DISPLAY + H_BACK + H_FRONT + H_SYNC - 1;
  parameter V_SYNC_START = V_DISPLAY + V_BOTTOM;
  parameter V_SYNC_END = V_DISPLAY + V_BOTTOM + V_SYNC - 1;
  parameter V_MAX = V_DISPLAY + V_TOP + V_BOTTOM + V_SYNC - 1;

  wire hmaxxed = (hpos == H_MAX) || reset;  // set when hpos is maximum
  wire vmaxxed = (vpos == V_MAX) || reset;  // set when vpos is maximum

  // horizontal position counter
  always @(posedge clk) begin
    hsync <= ~(hpos >= H_SYNC_START && hpos <= H_SYNC_END);
    if (hmaxxed) hpos <= 0;
    else hpos <= hpos + 1;
  end

  // vertical position counter
  always @(posedge clk) begin
    vsync <= ~(vpos >= V_SYNC_START && vpos <= V_SYNC_END);
    if (hmaxxed)
      if (vmaxxed) vpos <= 0;
      else vpos <= vpos + 1;
  end

  // display_on is set when beam is in "safe" visible frame
  assign display_on = (hpos < H_DISPLAY) && (vpos < V_DISPLAY);

endmodule

`endif


module game_core (
    input wire clk,
    input wire rst_n,
    input wire [4:0] cell_x,
    input wire [3:0] cell_y,
    input wire video_active,
    input wire game_tick,
    input wire [1:0] user_dir,
    output reg [1:0] R,
    output reg [1:0] G,
    output reg [1:0] B
);



  localparam SNAKE_LENGHT = 9;
  localparam ABS_UP = 2'b00;
  localparam ABS_DOWN = 2'b01;
  localparam ABS_LEFT = 2'b10;
  localparam ABS_RIGHT = 2'b11;
  // FSM State Encodings

  localparam STATE_IDLE = 2'b00;
  localparam STATE_MOVE_SNAKE = 2'b01;
  localparam STATE_GROW_SNAKE = 2'b10;

  reg [8:0] snake_body[0:SNAKE_LENGHT-1];
  reg [$clog2(SNAKE_LENGHT)-1:0] tail_ptr;
  reg [$clog2(SNAKE_LENGHT)-1:0] read_ptr;


  reg gen_food;

  wire [4:0] head_x;
  wire [3:0] head_y;
  reg [1:0] head_dir;

  // State Machine and Render Registers
  reg [1:0] state;
  reg [3:0] food_x;
  reg [3:0] food_y;

  reg game_over;
  reg update_body, grow_snake;

  wire [4:0] next_head_x = (head_dir == ABS_LEFT)  ? head_x - 5'd1 : (head_dir == ABS_RIGHT) ? head_x + 5'd1 : head_x;
  wire [3:0] next_head_y = (head_dir == ABS_UP)    ? head_y - 4'd1 : (head_dir == ABS_DOWN)  ? head_y + 4'd1 : head_y;
  wire eating_food = (next_head_x == food_x) && (next_head_y == food_y);
  wire touch_body = snake_body[read_ptr] == {next_head_y, next_head_x};

  reg is_body;
  wire is_food = (cell_x == food_x) && (cell_y == food_y);

  wire feedback;
  reg [7:0] rnd_counter;
  assign feedback = rnd_counter[7] ^ rnd_counter[5] ^ rnd_counter[4] ^ rnd_counter[3];

  assign head_x   = snake_body[0][4:0];
  assign head_y   = snake_body[0][8:5];

  /*Snake body as a FIFO memory using regs, the snake updates the new coordinates by shifting the content 
and pushing a new head coordinates*/
  integer i;
  always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      for (i = 1; i < SNAKE_LENGHT; i = i + 1) begin
        snake_body[i] <= 0;
      end
      snake_body[0] <= 9'h104;
    end else begin
      if (update_body) begin
        for (i = SNAKE_LENGHT - 1; i > 0; i = i - 1) begin
          snake_body[i] <= snake_body[i-1];
        end
        snake_body[0] <= {next_head_y, next_head_x};
      end
    end
  end


  /*snake lenght updating during the game*/
  always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      tail_ptr <= 1;
    end else begin
      if (grow_snake && tail_ptr != (SNAKE_LENGHT - 1)) begin
        tail_ptr <= tail_ptr + 1;
      end
    end
  end

  /*FSM controling the game logic, missing to avoid generating food in the same coordinates
    as the snake body*/
  always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      state       <= STATE_IDLE;
      head_dir    <= ABS_RIGHT;
      gen_food    <= 0;
      read_ptr    <= 0;
      game_over   <= 1'b0;
      grow_snake  <= 0;
      update_body <= 0;
    end else begin
      case (state)
        STATE_IDLE: begin
          if ((game_tick && !game_over)) begin
            head_dir <= user_dir;
            state    <= STATE_MOVE_SNAKE;
          end
          read_ptr    <= 0;
          gen_food    <= 0;
          grow_snake  <= 0;
          update_body <= 0;
        end

        STATE_MOVE_SNAKE: begin
          // 1. Boundary Wall Collision Check
          if ((head_dir == ABS_UP    && next_head_y == 4'd15)  ||
                        (head_dir == ABS_DOWN  && next_head_y == 4'd15) ||
                        (head_dir == ABS_LEFT  && next_head_x == 5'd31)  ||
                        (head_dir == ABS_RIGHT && next_head_x == 5'd20)) begin
            game_over <= 1'b1;
            state     <= STATE_IDLE;
          end  // 2. Self-Collision Check via single-cycle lookups
          else if (touch_body) begin
            game_over <= 1'b1;
            state     <= STATE_IDLE;
          end else if (read_ptr < tail_ptr) begin
            read_ptr <= read_ptr + 5'd1;
            state    <= STATE_MOVE_SNAKE;
          end else begin
            state <= STATE_GROW_SNAKE;
            update_body <= 1'b1;
          end
        end

        STATE_GROW_SNAKE: begin
          if (eating_food) begin
            gen_food <= 1'b1;
            grow_snake <= 1'b1;
            update_body <= 1'b0;
            state <= STATE_IDLE;
          end else begin
            // Clear the cell the tail is currently leaving
            update_body <= 1'b0;
            state <= STATE_IDLE;
          end
        end

        /* TODO: add some states to check wheter the food was generated outside the snake body */
        /*TODO: Add some states for generating the Poison */
        default: begin
          state <= STATE_IDLE;
        end
      endcase
    end
  end


  /*LSFR implementation for pseudo random food generation*/
  always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      rnd_counter <= 8'hFF;
    end else begin
      rnd_counter <= {feedback, rnd_counter[7:1]};
    end
  end

  /*Food generation coordinates*/
  always @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      food_x <= 3;
      food_y <= 7;
    end else begin
      if (gen_food) begin
        food_x <= rnd_counter[7:4];
        food_y <= {rnd_counter[3:1], 1'b0};
      end
    end
  end


  /*Pixel color generation on the fly based on the current cell coordinates
    and the coordinates of the snake and the food*/
  always @(*) begin
    casez ({
      video_active, game_over, is_body, is_food
    })
      4'b0???: begin
        R = 2'b00;
        G = 2'b00;
        B = 2'b00;
      end
      4'b11??: begin
        R = 2'b00;
        G = 2'b11;
        B = 2'b11;
      end
      4'b101?: begin
        R = 2'b00;
        G = 2'b11;
        B = 2'b00;
      end
      4'b1001: begin
        R = 2'b11;
        G = 2'b00;
        B = 2'b00;
      end
      default: begin
        R = 2'b00;
        G = 2'b00;
        B = 2'b01;
      end
    endcase
  end

  /*Parallel checker of the current cell and the content stored inside the snake body*/
  integer j;
  always @(*) begin
    is_body = 1'b0;
    for (j = 0; j < SNAKE_LENGHT; j = j + 1) begin
      if (({cell_y, cell_x} == snake_body[j])) begin
        if (j < tail_ptr) is_body = 1'b1;
      end
    end
  end

endmodule


module debounce #(
    parameter CLK_FREQ = 25000000,
    parameter DEBOUNCE_FREQ = 100000
) (
    clk,
    rst_n,
    trigger,
    input_signal,
    clean_signal
);

  input clk;
  input rst_n;
  input trigger;
  input input_signal;
  output clean_signal;

  reg [7:0] shift_reg;

  wire stable_high;
  wire stable_low;
  reg clean_signal_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      shift_reg <= 8'd0;
    end else if (trigger == 1'b1) begin
      shift_reg <= {shift_reg[6:0], input_signal};
    end
  end

  assign stable_high = (shift_reg == 8'b11111111) ? 1'b1 : 1'b0;
  assign stable_low  = (shift_reg == 8'b00000000) ? 1'b1 : 1'b0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      clean_signal_reg <= 1'b0;
    end else if (stable_high == 1'b1 || stable_low == 1'b1) begin
      clean_signal_reg <= stable_high;
    end
  end

  assign clean_signal = clean_signal_reg;

endmodule
