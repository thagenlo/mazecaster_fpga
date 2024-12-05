module add#(
    parameter WIDTH = 16,
    parameter FRAC_WIDTH = 8) 
    (input wire clk_in,
    input wire rst_in,
    input wire [WIDTH-1:0] arg1, 
    input wire [WIDTH-1:0] arg2, 
    output logic [WIDTH-1:0] sum,
    output logic ovrflw
    );

    // clippping range for two's compliment Q8.8:
    // MAX: 0x7FFF = 127.99609375 fp
    // MIN: 0x8000 = −128 in fp

    logic [WIDTH:0] tempAdd;//extra bit is for overflow detection
    always_comb begin
        tempAdd = $signed(arg1) + $signed(arg2);
        if (WIDTH == 16 && FRAC_WIDTH == 8) begin
            if ($signed(tempAdd) > $signed(16'h7FFF)) begin
                // CLIPPING MAX
                sum = 16'h7FFF; // 0x7FFF
                ovrflw = 1;
            end else if ($signed(tempAdd) < $signed(16'h8000)) begin
                // CLIPPING MIN
                sum = 16'h8000; // 0x8000
                ovrflw = 1;
            end else begin
                // NORMAL ADD *no clipping needed*
                sum = tempAdd[WIDTH-1:0];
                ovrflw = 0;
            end
        end
        else if (WIDTH == 24 && FRAC_WIDTH == 12) begin
            if ($signed(tempAdd) > $signed(24'h7FFFF)) begin
                sum = 24'h7FFFFF; // 0x7fffff
                ovrflw = 1;
            end else if ($signed(tempAdd) < $signed(24'h800000)) begin
                sum = 24'h800000; // 0x800000
                ovrflw = 1;
            end else begin
                sum = tempAdd[WIDTH-1:0];
                ovrflw = 0;
            end
        end
        else if (WIDTH == 32 && FRAC_WIDTH == 16) begin
            if ($signed(tempAdd) >  $signed(32'h7FFFFFFF)) begin
                sum = 32'h7FFFFFFF; // 0x7fffff
                ovrflw = 1;
            end else if ($signed(tempAdd) <  $signed(32'h80000000)) begin
                // CLIPPING MIN
                sum = 32'h80000000; // 0x8000
                ovrflw = 1;
            end else begin
                // NORMAL ADD *no clipping needed*
                sum = tempAdd[WIDTH-1:0];
                ovrflw = 0;
            end
        end
    end    
endmodule