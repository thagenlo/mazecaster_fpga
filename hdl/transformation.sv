`timescale 1ns / 1ps
`default_nettype none

/*
Outputs of DDA:
    output logic [10:0] hcount_ray_out, //pipelined x_coord
    output logic [15:0] lineHeight_out, // = SCREEN_HEIGHT/perpWallDist
    output logic wallType_out, // 0 = X wall hit, 1 = Y wall hit
    output logic [3:0] mapData_out;  // value 0 -> 2^4 at map[mapX][mapY] from BROM
    output logic [15:0] wallX_out; //where on wall the ray hits
    output logic valid_out, // indicates when to store (x, lineHeight, wallType, mapData) in DDA_fifo_out

*/

module transformation (
                        input wire [10:0] hcount_ray_in,    //pipelined x_coord
                        input wire [15:0] lineHeight_in,    // = SCREEN_HEIGHT/perpWallDist
                        input wire wallType_in,             // 0 = X wall hit, 1 = Y wall hit
                        input wire [3:0] mapData_in,        // 
                        input wire [15:0] wallX_in,
                        input wire ray_valid_in,            
                        )

endmodule

`default_nettype wire