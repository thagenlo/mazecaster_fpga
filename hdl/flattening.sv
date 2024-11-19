module dda
#(
  parameter SCREEN_WIDTH = 320,
  parameter SCREEN_HEIGHT = 240,
  parameter N = 24
)
(
  input wire pixel_clk_in, //TODO check if correct clock
  input wire rst_in,

  input logic [7:0] hcount_ray_in, // screen x_coord (not pipelines)
  input logic [15:0] lineHeight_in, // = SCREEN_HEIGHT/perpWallDist
  input logic wallType_in, // 0 = X wall hit, 1 = Y wall hit
  input logic [7:0] mapData_in;  // value 0 -> 2^8 at map[mapX][mapY] from BROM //TODO store in intermediate register?
  input logic [15:0] wallX_in; //wh

  output logic [7:0] screenX_out; //pipelined x_coord
  output logic [7:0] screenY_out; //pipelined y_coord
  output logic [7:0] screenData_out; //pixel color
  );

endmodule