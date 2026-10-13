module tb;

reg clk;
reg rstn;
wire [7:0] Q;

counter DUT(
    .clk(clk),
    .rstn(rstn),
    .Q(Q)
);


always begin
    clk = ~clk;
    #10;
end

initial begin
    $dumpfile("sim.vcd");
    $dumpvars;
    clk = 0;
    rstn = 0;
    #50;
    rstn = 1;
    #1000;
    $finish;
end


endmodule