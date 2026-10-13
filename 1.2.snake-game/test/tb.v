module tb;
    reg clk;
    reg rstn;
    reg [7:0] ui_in;    // Dedicated inputs
    wire [7:0] uo_out;   // Dedicated outputs
    reg [7:0] uio_in;   // IOs: Input path
    wire [7:0] uio_out;  // IOs: Output path
    wire [7:0] uio_oe;   // IOs: Enable path (active high: 0=input, 1=output)

    wire hsync;
    wire vsync;
    wire [1:0] R, G, B;

    always begin
        clk = ~clk;
        #20;
    end


    snake_game uut(
    .ui_in(ui_in),    // Dedicated inputs
    .uo_out(uo_out),   // Dedicated outputs
    .uio_in(uio_in),   // IOs: Input path
    .uio_out(uio_out),  // IOs: Output path
    .uio_oe(uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
    .ena(1'b1),      // always 1 when the design is powered, so you can ignore it
    .clk(clk),      // clock
    .rst_n(rstn)     // reset_n - low to reset
);

    assign R = {uo_out[0],uo_out[4]};
    assign G = {uo_out[1],uo_out[5]};
    assign B = {uo_out[2],uo_out[3]};
    assign hsync = uo_out[7];
    assign vsync = uo_out[3];
    
    initial begin
        $dumpfile("sim.vcd");
        $dumpvars;
    end

    integer i;
    initial begin
        ui_in = 0;
        uio_in = 0;
        clk=0;
        rstn=0;
        #20;
        rstn=1;
        #1;
        repeat (400000) begin
            @(posedge clk);
        end
        $finish;
    end

endmodule