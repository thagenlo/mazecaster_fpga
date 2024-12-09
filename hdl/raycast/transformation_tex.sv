`timescale 1ns / 1ps
`default_nettype none

/*
Outputs of dda module into DDA-out FIFO:
    output logic [10:0] hcount_ray_out, //pipelined x_coord
    output logic [15:0] lineHeight_out, // = SCREEN_HEIGHT/perpWallDist
    output logic wallType_out, // 0 = X wall hit, 1 = Y wall hit
    output logic [3:0] mapData_out;  // value 0 -> 2^4 at map[mapX][mapY] from BROM
    output logic [15:0] wallX_out; //where on wall the ray hits
    output logic valid_out, // indicates when to store (x, lineHeight, wallType, mapData) in DDA_fifo_out

Inputs of DDA-out FIFO:
    input wire 		receiver_clk,
    input wire 		receiver_axis_tready,
Outputs of DDA-out FIFO:
   output logic 	receiver_axis_tvalid,
   output logic [41:0] receiver_axis_tdata,
   output logic 	receiver_axis_tlast,

Inputs into frame_buffer module:
    input wire [15:0] ray_address_in, // from transformating / flattening module (not in order and ranges from 0 to 320*180)
    input wire [15:0] ray_pixel_in,
    input wire ray_last_pixel_in, // indicates the last computed pixel in the ray sweep
*/

/*
data from DDA-out FIFO
- 9 (hcount) + 8 (line height) + 1 (wall type) + 4 (map data) + 16 (wallX) = 38 bits = [37:0]

Version 1:
- no textures, no shading, just black and white
The Approach:
- everything can be combinational ()
>= draw start and < draw end
*/

module transformation_tex_new  #(
                        parameter [4:0] PIXEL_WIDTH = 16,
                        parameter [10:0] FULL_SCREEN_WIDTH = 1280,
                        parameter [9:0] FULL_SCREEN_HEIGHT = 720,
                        parameter [8:0] SCREEN_WIDTH = 320,
                        parameter [7:0] SCREEN_HEIGHT = 180
                        )
                        (
                        input wire pixel_clk_in,
                        input wire rst_in,

                        // TODO: GRID STUFF
                        // input wire [2:0] grid_type,
                        // input wire valid_grid_in,
                        // output logic grid_req_out,

                        input wire dda_fifo_tvalid_in,
                        input wire [37:0] dda_fifo_tdata_in,
                        input wire dda_fifo_tlast_in,
                        input wire [1:0] fb_ready_to_switch_in,

                        output logic transformer_tready_out,         // tells FIFO that we're ready to receive next data (need a vcount counter)

                        output logic [15:0] ray_address_out,    // where to store the pixel value in frame buffer
                        output logic [7:0] ray_pixel_out,      // the calculated pixel value of the ray
                        output logic ray_last_pixel_out        // tells frame buffer whether we are on the last pixel or not
                        );
// STATE MACHINE
typedef enum {
	    FIFO_DATA_WAIT,             // wait for valid vertical line data from the FIFO
        FIFO_DATA_WAIT_NEW_PACKET,  // wait for start of new packet of data from FIFO
        FLATTENING                  // iterating through all vcounts for hcount, and transmitting corresponding (v,h) pixel value
	} t_state;

t_state state;

// PARAMETERS
// colors
localparam SKY = 8'h2a; // SKY BLUE
localparam GROUND = 8'hdc; // BROWN FLOOR
localparam BLACK_WALL = 8'hFF;
localparam GREEN_WALL = 8'h97;
localparam  HALF_SCREEN_HEIGHT = (SCREEN_HEIGHT >> 1);
// region bounds
localparam GRID_SIDE = 24;
localparam TOP_DOWN_BOUND = GRID_SIDE;

// FROM DDA FIFO
logic [8:0] hcount_ray_in; //pipelined x_coord
logic [7:0] half_line_height; // = SCREEN_HEIGHT/perpWallDist

logic wallType_in; // 0 = X wall hit, 1 = Y wall hit
logic [3:0] mapData_in;  // value 0 -> 2^4 at map[mapX][mapY] from BROM
logic [15:0] wallX_in; //where on wall the ray hits

logic [38:0] fifo_data_store; // // 9 (hcount) + 8 (line height) + 1 (wall type) + 4 (map data) + 16 (wallX) = 38 bits = [37:0]
logic fifo_tlast_store;

// 000000000_00101000_1_0001_0000000000000000
assign hcount_ray_in = fifo_data_store[37:29];
assign half_line_height = (fifo_data_store[28:21] >> 1);
assign wallType_in = fifo_data_store[20];
assign mapData_in = fifo_data_store[19:16];
assign wallX_in = fifo_data_store[15:0];

assign draw_start = HALF_SCREEN_HEIGHT - half_line_height;
assign draw_end = HALF_SCREEN_HEIGHT + half_line_height;

// TO USE IN MODULE
logic [7:0] vcount_ray;
logic [7:0] draw_start;
logic [7:0] draw_end;

logic [15:0] tex_pixel;
logic [1:0] tex_counter; // counts from 0 to 2
logic tex_req; // 1 = valid request, 0 = no request
logic valid_tex_out;

textures texture_module (
    .pixel_clk_in(pixel_clk_in),
    .rst_in(rst_in),
    .valid_req_in(tex_req),
    .wallX_in(wallX_in),
    .lineheight_in(fifo_data_store[28:21]),
    .drawstart_in(draw_start),
    .vcount_ray_in(vcount_ray),
    .texture_in(mapData_in),
    .tex_pixel_out(tex_pixel),
    .valid_tex_out(valid_tex_out)
);

typedef enum {
    CEILING,
    FLOOR,
    PLAIN_WALL,
    TEX_WALL,
    TOPDOWN
    // TODO: TIMER   
    } screen_region;

screen_region region;

always_comb begin
    if ((vcount_ray < TOP_DOWN_BOUND) && (hcount_ray_in < TOP_DOWN_BOUND)) begin
        region = TOPDOWN;
    end else if (vcount_ray < draw_start) begin
        region = CEILING;
    end else if (vcount_ray >= draw_end) begin
        region = FLOOR;
    end else begin
        if (mapData_in < 3) begin
            region = PLAIN_WALL;
        end else begin
            region = TEX_WALL;
        end
    end
end

always_ff @(posedge pixel_clk_in) begin
    if (rst_in) begin
        vcount_ray <= 0;
        state <= FIFO_DATA_WAIT;
        transformer_tready_out <= 1;
        tex_req <= 0;
    end else begin
        case (state)
            FIFO_DATA_WAIT: begin
                if (dda_fifo_tvalid_in) begin
                    transformer_tready_out <= 0;
                    state <= FLATTENING;
                    fifo_data_store <= dda_fifo_tdata_in; // store fifo data in a register
                    fifo_tlast_store <= dda_fifo_tlast_in;
                end else begin
                    state <= FIFO_DATA_WAIT;
                end
            end

            FIFO_DATA_WAIT_NEW_PACKET: begin
                ray_last_pixel_out <= 0;
                transformer_tready_out <= (fb_ready_to_switch_in == 3) ? 1 : transformer_tready_out;
                if (dda_fifo_tvalid_in && transformer_tready_out) begin // 3-way handshake --> only receive data when the fifo data is valid, the transformer is ready, and the fb is ready
                    transformer_tready_out <= 0;
                    state <= FLATTENING;
                    fifo_data_store <= dda_fifo_tdata_in; // store fifo data in a register
                    fifo_tlast_store <= dda_fifo_tlast_in;
                end else begin
                    state <= FIFO_DATA_WAIT_NEW_PACKET;
                end
            end

            FLATTENING: begin
                case (region)
                    CEILING, FLOOR, PLAIN_WALL: begin
                        if (region == CEILING || region == FLOOR) begin
                            ray_pixel_out <= (region == CEILING) ? SKY : GROUND;
                        end else begin
                            case (mapData_in)
                                0: ray_pixel_out <= SKY;
                                1: ray_pixel_out <= BLACK_WALL;
                                2: ray_pixel_out <= GREEN_WALL;
                            endcase
                        end
                        ray_address_out <= hcount_ray_in + vcount_ray*SCREEN_WIDTH;
                        // vcount updating + state transitions on same cycle
                        if (vcount_ray < SCREEN_HEIGHT-1) begin
                            vcount_ray <= vcount_ray + 1;
                            ray_last_pixel_out <= 0;
                            state <= FLATTENING;
                        end else begin
                            if (fifo_tlast_store) begin     // if we're at the end of the packet
                                ray_last_pixel_out <= 1;    // signal that we hit the last pixel of the packet
                                vcount_ray <= 0;            // reset vcount still
                                transformer_tready_out <= 0; // indicate transformer's readiness to receive new data
                                state <= FIFO_DATA_WAIT_NEW_PACKET;
                            end else begin                  // if we're not at the end of the packet
                                ray_last_pixel_out <= 0;    // reset things like normal and indicate transformer is ready to receive new data
                                transformer_tready_out <= 1;
                                vcount_ray <= 0;
                                state <= FIFO_DATA_WAIT;
                            end
                        end
                    end

                    TEX_WALL: begin
                        if (valid_tex_out) begin
                            tex_req <= 0;               // make tex_req = 0 once we've serviced the request
                            // ray_pixel + address calculation
                            ray_pixel_out <= tex_pixel;
                            ray_address_out <= hcount_ray_in + vcount_ray*SCREEN_WIDTH;

                            // vcount updating + state transitions on same cycle
                            if (vcount_ray < SCREEN_HEIGHT-1) begin
                                vcount_ray <= vcount_ray + 1;
                                ray_last_pixel_out <= 0;
                                state <= FLATTENING;
                            end else begin
                                if (fifo_tlast_store) begin     // if we're at the end of the packet
                                    ray_last_pixel_out <= 1;    // signal that we hit the last pixel of the packet
                                    vcount_ray <= 0;            // reset vcount still
                                    transformer_tready_out <= 0; // indicate transformer's readiness to receive new data
                                    state <= FIFO_DATA_WAIT_NEW_PACKET;
                                end else begin                  // if we're not at the end of the packet
                                    ray_last_pixel_out <= 0;    // reset things like normal and indicate transformer is ready to receive new data
                                    transformer_tready_out <= 1;
                                    vcount_ray <= 0;
                                    state <= FIFO_DATA_WAIT;
                                end
                            end
                        end else begin
                            tex_req <= 1;
                        end
                    end

                    TOPDOWN: begin
                        ray_pixel_out <= 8'h0a;
                        ray_address_out <= hcount_ray_in + vcount_ray*SCREEN_WIDTH;
                        // vcount updating + state transitions on same cycle
                        if (vcount_ray < SCREEN_HEIGHT-1) begin
                            vcount_ray <= vcount_ray + 1;
                            ray_last_pixel_out <= 0;
                            state <= FLATTENING;
                        end else begin
                            if (fifo_tlast_store) begin     // if we're at the end of the packet
                                ray_last_pixel_out <= 1;    // signal that we hit the last pixel of the packet
                                vcount_ray <= 0;            // reset vcount still
                                transformer_tready_out <= 0; // indicate transformer's readiness to receive new data
                                state <= FIFO_DATA_WAIT_NEW_PACKET;
                            end else begin                  // if we're not at the end of the packet
                                ray_last_pixel_out <= 0;    // reset things like normal and indicate transformer is ready to receive new data
                                transformer_tready_out <= 1;
                                vcount_ray <= 0;
                                state <= FIFO_DATA_WAIT;
                            end
                        end
                    end
                    // TOPDOWN: begin
                    //     // need to access grid bram
                    //     if (valid_grid_in) begin
                    //         grid_req_out <= 0;

                    //     end else begin
                    //         grid_req_out <= 1;
                    //         grid_address_out <= ()
                    //     end

                    // end
                endcase
            end
        endcase
    end
end


endmodule

`default_nettype wire