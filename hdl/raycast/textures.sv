`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"../../data/X`"
`endif  /* ! SYNTHESIS */

module textures (
    input wire pixel_clk_in,
    input wire rst_in,
    input wire valid_req_in,
    input wire [15:0] wallX_in,
    input wire [7:0] vcount_ray_in,
    input wire [3:0] texture_in, // which texture (map_data)
    output logic [15:0] tex_pixel_out,
    output logic valid_tex_out
);

localparam [4:0] PIXEL_WIDTH = 16;
localparam [8:0] TEX_WIDTH = 320;
localparam [8:0] TEX_HEIGHT = 320;
localparam [7:0] SCREEN_HEIGHT = 180;
localparam [17:0] CONSTANT = TEX_WIDTH*TEX_HEIGHT/SCREEN_HEIGHT; // used in calc of texture address
// localparam [$clog2(CONST)-1:0] C = CONST; // 10 bits

logic [18:0] address;
logic [16:0] first_part;
logic [17:0] second_part;

logic [15:0] tex1_out;
logic [15:0] tex2_out;
logic [15:0] tex3_out;
logic [1:0] valid_out_pipe;

assign valid_tex_out = valid_out_pipe[1];

always_comb begin
    case (texture_in) 
        3: tex_pixel_out = tex1_out;
        4: tex_pixel_out = tex2_out;
        5: tex_pixel_out = tex3_out;
    endcase
    
    // calculating address (only calculate when we have a texture request)
    if (valid_req_in) begin
        first_part = (wallX_in[7:0]*TEX_WIDTH)>>8;
        second_part = vcount_ray_in*CONSTANT;
        address = first_part + second_part;
    end   
end

// pipelining  to signal 2 cycle wait for texture bram valid output
logic valid_req_past;

always_ff @(posedge pixel_clk_in) begin
    if (rst_in) begin
        valid_out_pipe <= 2'b0;
        valid_req_past <= 0;
    end else begin
        valid_req_past <= valid_req_in;
        valid_out_pipe[0] <= (valid_req_in && !valid_req_past);
        valid_out_pipe[1] <= valid_out_pipe[0];
    end
end


//TODO: insert texture files
xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(PIXEL_WIDTH),       
    .RAM_DEPTH(TEX_WIDTH*TEX_HEIGHT),               
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
    .INIT_FILE(`FPATH(red_brick.mem))                           
) texture_1 (
        .addra(address),            // address
        .dina(),                    // RAM input data = pixel_in from DDA_out buffer
        .clka(pixel_clk_in),        // Clock
        .wea(0),                    // ROM
        .ena(1),                    // RAM Enable
        .rsta(rst_in),              // Output reset
        .regcea(1),                 // Output register enable
        .douta(tex1_out)            // RAM output data
    );

xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(PIXEL_WIDTH),          
    .RAM_DEPTH(TEX_WIDTH*TEX_HEIGHT),               
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
    .INIT_FILE(`FPATH(stone_brick.mem))                        
) texture_2 (
        .addra(address),            // address
        .dina(),                    // RAM input data = pixel_in from DDA_out buffer
        .clka(pixel_clk_in),        // Clock
        .wea(0),                    // ROM
        .ena(1),                    // RAM Enable
        .rsta(rst_in),              // Output reset
        .regcea(1),                 // Output register enable
        .douta(tex2_out)            // RAM output data
    );

xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(PIXEL_WIDTH),               
    .RAM_DEPTH(TEX_WIDTH*TEX_HEIGHT),               
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
    .INIT_FILE(`FPATH(choc_cookies.mem))                        
) texture_3 (
        .addra(address),            // address
        .dina(),                    // RAM input data = pixel_in from DDA_out buffer
        .clka(pixel_clk_in),        // Clock
        .wea(0),                    // ROM
        .ena(1),                    // RAM Enable
        .rsta(rst_in),              // Output reset
        .regcea(1),                 // Output register enable
        .douta(tex3_out)            // RAM output data
    );

endmodule

`default_nettype wire