module fixed_point_multiplier (
    input signed [15:0] a,
    input signed [15:0] b,
    output signed [15:0] result
);

    wire signed [31:0] product;

    assign product = a * b; //need to doubke lenth for fractional part when multiplying 

    // rounding out fractional bits to nearest numbers
    assign result = product[23:8]; //

endmodule