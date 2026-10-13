/*
 * Copyright (c) 2024 Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_vga_example (
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
