
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
