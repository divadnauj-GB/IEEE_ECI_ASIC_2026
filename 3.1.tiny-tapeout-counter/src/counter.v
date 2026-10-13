module counter(
input wire clk,
input wire rstn,
output wire [7:0] Q
);

reg [7:0] count;

always @(posedge clk, negedge rstn) begin
    if(!rstn) begin
        count <= 8'd0;
    end else begin
        count <= count + 1;
    end
end


assign Q=count;

endmodule