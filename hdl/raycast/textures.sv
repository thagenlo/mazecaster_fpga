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
    input wire [7:0] lineheight_in,
    input wire [9:0] drawstart_in,
    input wire [7:0] vcount_ray_in,
    input wire [3:0] texture_in, // which texture (map_data)
    output logic [7:0] tex_pixel_out,
    output logic valid_tex_out
);

localparam PIXEL_WIDTH = 8;
localparam TEX_WIDTH = 64;
localparam TEX_HEIGHT = 64;
localparam SCREEN_HEIGHT = 180;

logic [18:0] address;
logic [25:0] first_part;
logic [17:0] second_part;

logic [7:0] tex2_out, tex3_out, tex4_out, tex5_out, tex6_out, tex7_out, tex8_out, tex9_out, tex10_out, tex11_out;
// logic [7:0] tex2_out, tex3_out, tex4_out, tex7_out;
logic [1:0] valid_out_pipe;

assign valid_tex_out = valid_out_pipe[1];

always_comb begin
    case (texture_in) 
        2: tex_pixel_out = tex2_out;
        3: tex_pixel_out = tex3_out;
        4: tex_pixel_out = tex4_out;
        5: tex_pixel_out = tex5_out;
        6: tex_pixel_out = tex6_out;
        7: tex_pixel_out = tex7_out;
        8: tex_pixel_out = tex8_out;
        9: tex_pixel_out = tex9_out;
        10: tex_pixel_out = tex10_out;
        11: tex_pixel_out = tex11_out;
        default : tex_pixel_out = 0;
    endcase
    
    // calculating address (calculate address when division is done)
    first_part = (wallX_in[7:0]*TEX_WIDTH)>>8; // hcount
    second_part = TEX_WIDTH*vcount_tex;
    address = first_part + second_part;
end

// pipelining  to signal 2 cycle wait for texture bram valid output
always_ff @(posedge pixel_clk_in) begin
    if (rst_in) begin
        valid_out_pipe <= 2'b0;
        past_valid_req <= 0;
    end else begin
        valid_out_pipe[0] <= div_done;
        valid_out_pipe[1] <= valid_out_pipe[0];

        past_valid_req <= valid_req_in;
    end
end

logic [15:0] numerator;
logic div_done;
logic [8:0] vcount_tex;

assign numerator = (vcount_ray_in-drawstart_in)*TEX_HEIGHT;

logic past_valid_req;
logic start_div;

assign start_div = (valid_req_in && !past_valid_req); // one cycle high to start division

divu #(
        .WIDTH(16),
        .FBITS(0)
    ) divu_inst (
        .clk(pixel_clk_in),
        .rst(rst_in),
        .start(start_div), // start division whenever we start processing the texture request
        .busy(),
        .done(div_done),
        .valid(),
        .dbz(),
        .ovf(),
        .a(numerator),
        .b(lineheight_in),
        .val(vcount_tex)
    );


//TODO: insert texture files
xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(PIXEL_WIDTH),       
    .RAM_DEPTH(TEX_WIDTH*TEX_HEIGHT),               
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
    .INIT_FILE(`FPATH(2-hedge1.mem))                           
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
    .INIT_FILE(`FPATH(3-hedge2.mem))                        
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

xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(PIXEL_WIDTH),               
    .RAM_DEPTH(TEX_WIDTH*TEX_HEIGHT),               
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
    .INIT_FILE(`FPATH(4-hedge3.mem))                        
) texture_4 (
        .addra(address),            // address
        .dina(),                    // RAM input data = pixel_in from DDA_out buffer
        .clka(pixel_clk_in),        // Clock
        .wea(0),                    // ROM
        .ena(1),                    // RAM Enable
        .rsta(rst_in),              // Output reset
        .regcea(1),                 // Output register enable
        .douta(tex4_out)            // RAM output data
    );

xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(PIXEL_WIDTH),               
    .RAM_DEPTH(TEX_WIDTH*TEX_HEIGHT),               
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
    .INIT_FILE(`FPATH(5-hedge4.mem))                        
) texture_5 (
        .addra(address),            // address
        .dina(),                    // RAM input data = pixel_in from DDA_out buffer
        .clka(pixel_clk_in),        // Clock
        .wea(0),                    // ROM
        .ena(1),                    // RAM Enable
        .rsta(rst_in),              // Output reset
        .regcea(1),                 // Output register enable
        .douta(tex5_out)            // RAM output data
    );

xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(PIXEL_WIDTH),               
    .RAM_DEPTH(TEX_WIDTH*TEX_HEIGHT),               
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
    .INIT_FILE(`FPATH(6-hedge5.mem))                        
) texture_6 (
        .addra(address),            // address
        .dina(),                    // RAM input data = pixel_in from DDA_out buffer
        .clka(pixel_clk_in),        // Clock
        .wea(0),                    // ROM
        .ena(1),                    // RAM Enable
        .rsta(rst_in),              // Output reset
        .regcea(1),                 // Output register enable
        .douta(tex6_out)            // RAM output data
    );

xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(PIXEL_WIDTH),               
    .RAM_DEPTH(TEX_WIDTH*TEX_HEIGHT),               
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
    .INIT_FILE(`FPATH(7-hedge6.mem))                        
) texture_7 (
        .addra(address),            // address
        .dina(),                    // RAM input data = pixel_in from DDA_out buffer
        .clka(pixel_clk_in),        // Clock
        .wea(0),                    // ROM
        .ena(1),                    // RAM Enable
        .rsta(rst_in),              // Output reset
        .regcea(1),                 // Output register enable
        .douta(tex7_out)            // RAM output data
    );

xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(PIXEL_WIDTH),               
    .RAM_DEPTH(TEX_WIDTH*TEX_HEIGHT),               
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
    .INIT_FILE(`FPATH(8-hedge7.mem))                        
) texture_8 (
        .addra(address),            // address
        .dina(),                    // RAM input data = pixel_in from DDA_out buffer
        .clka(pixel_clk_in),        // Clock
        .wea(0),                    // ROM
        .ena(1),                    // RAM Enable
        .rsta(rst_in),              // Output reset
        .regcea(1),                 // Output register enable
        .douta(tex8_out)            // RAM output data
    );

xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(PIXEL_WIDTH),               
    .RAM_DEPTH(TEX_WIDTH*TEX_HEIGHT),               
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
    .INIT_FILE(`FPATH(9-hedge8.mem))                        
) texture_9 (
        .addra(address),            // address
        .dina(),                    // RAM input data = pixel_in from DDA_out buffer
        .clka(pixel_clk_in),        // Clock
        .wea(0),                    // ROM
        .ena(1),                    // RAM Enable
        .rsta(rst_in),              // Output reset
        .regcea(1),                 // Output register enable
        .douta(tex9_out)            // RAM output data
    );

xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(PIXEL_WIDTH),               
    .RAM_DEPTH(TEX_WIDTH*TEX_HEIGHT),               
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
    .INIT_FILE(`FPATH(10-hedge9.mem))                        
) texture_10 (
        .addra(address),            // address
        .dina(),                    // RAM input data = pixel_in from DDA_out buffer
        .clka(pixel_clk_in),        // Clock
        .wea(0),                    // ROM
        .ena(1),                    // RAM Enable
        .rsta(rst_in),              // Output reset
        .regcea(1),                 // Output register enable
        .douta(tex10_out)            // RAM output data
    );

xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(PIXEL_WIDTH),               
    .RAM_DEPTH(TEX_WIDTH*TEX_HEIGHT),               
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
    .INIT_FILE(`FPATH(11-hedge10.mem))                        
) texture_11 (
        .addra(address),            // address
        .dina(),                    // RAM input data = pixel_in from DDA_out buffer
        .clka(pixel_clk_in),        // Clock
        .wea(0),                    // ROM
        .ena(1),                    // RAM Enable
        .rsta(rst_in),              // Output reset
        .regcea(1),                 // Output register enable
        .douta(tex11_out)            // RAM output data
    );

endmodule

`default_nettype wire