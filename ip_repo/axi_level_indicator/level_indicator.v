module level_indicator(
    input  wire        clk,
    input  wire        reset,
    input  wire [15:0] in_data,
    input  wire        in_valid,
    input  wire [3:0]  window,
    output reg  [15:0] peak,
    output reg  [3:0]  level
);
    
    reg [7:0][15:0] mem;
    reg [15:0]      abs_in;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            mem <= '0;
        end if (clk && in_valid) begin
            abs_in <= in_data[15] ? (~in_data + 1) : in_data;
            
            mem <= {mem[6:0], abs_in};
        end
    end

endmodule