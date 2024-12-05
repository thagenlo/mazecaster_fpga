module multiply#(
    parameter WIDTH = 16,
    parameter FRAC_WIDTH = 8
    )(input wire clk_in,
    input wire rst_in,
    input wire signed [WIDTH-1:0] arg1, 
    input wire signed [WIDTH-1:0] arg2, 
    output logic signed  [WIDTH-1:0] prod,
    output logic ovrflw);


    logic signed [2*WIDTH-1:0] tempProd;
    logic signed [WIDTH-1:0] result;
    always_comb begin
        tempProd = arg1 * arg2;
        result = tempProd[WIDTH+FRAC_WIDTH-1:FRAC_WIDTH];
        if (WIDTH == 16 && FRAC_WIDTH == 8) begin
            // 
            if (tempProd > $signed(32'h7FFF00)) begin
                // Clip to max
                prod = 16'h7FFF;
                ovrflw = 1;
            end else if (tempProd < $signed(32'hFF8000FF)) begin
                // Clip to min
                prod = 16'h8000;
                ovrflw = 1;
            end else begin
                // No clipping, take the middle `WIDTH` bits
                prod = result;
                ovrflw = 0;
            end
        end
        else if (WIDTH == 24 && FRAC_WIDTH == 12) begin
            if ($signed(tempProd) > $signed(48'h7FFFFF000)) begin
                prod = 24'h7FFFFF;
                ovrflw = 1;
            end else if ($signed(tempProd) < $signed(48'hFFF800000FFF)) begin
                prod = 24'h800000;
                ovrflw = 1;
            end else begin
                prod = tempProd[WIDTH+FRAC_WIDTH-1:FRAC_WIDTH];
                ovrflw = 0;
            end
        end
        else if (WIDTH == 32 && FRAC_WIDTH == 16) begin
            if ($signed(tempProd) > $signed(64'h7FFFFFFF0000)) begin
                prod = 32'h7FFFFFFF;
                ovrflw = 1;
            end else if ($signed(tempProd) < $signed(64'hFFFF80000000FFFF)) begin
                prod = 32'h80000000;
                ovrflw = 1;
            end else begin
                prod = tempProd[WIDTH+FRAC_WIDTH-1:FRAC_WIDTH];
                ovrflw = 0;
            end
        end
    end

endmodule
// always_comb begin
//         tempProd = arg1 * arg2;
//         prod = tempProd[WIDTH+FRAC_WIDTH-1:FRAC_WIDTH];
//     end