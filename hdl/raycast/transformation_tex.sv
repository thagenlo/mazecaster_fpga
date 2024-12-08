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

module transformation_tex  #(
                        parameter [4:0] PIXEL_WIDTH = 16,
                        parameter [10:0] FULL_SCREEN_WIDTH = 1280,
                        parameter [9:0] FULL_SCREEN_HEIGHT = 720,
                        parameter [8:0] SCREEN_WIDTH = 320,
                        parameter [7:0] SCREEN_HEIGHT = 180
                        )
                        (
                        input wire pixel_clk_in,
                        input wire rst_in,

                        input wire dda_fifo_tvalid_in,
                        input wire [37:0] dda_fifo_tdata_in,
                        input wire dda_fifo_tlast_in,
                        input wire [1:0] fb_ready_to_switch_in,

                        output logic transformer_tready_out,         // tells FIFO that we're ready to receive next data (need a vcount counter)

                        output logic [15:0] ray_address_out,    // where to store the pixel value in frame buffer
                        output logic [15:0] ray_pixel_out,      // the calculated pixel value of the ray
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
localparam [15:0] BACKGROUND_COLOR = 65535;
localparam [15:0] BLACK_WALL = 0;
localparam [15:0] GREEN_WALL = 30320;
localparam [7:0] HALF_SCREEN_HEIGHT = (SCREEN_HEIGHT >> 1);

// FROM DDA FIFO
logic [8:0] hcount_ray_in; //pipelined x_coord
logic [7:0] half_line_height; // = SCREEN_HEIGHT/perpWallDist

logic wallType_in; // 0 = X wall hit, 1 = Y wall hit
logic [3:0] mapData_in;  // value 0 -> 2^4 at map[mapX][mapY] from BROM
logic [15:0] wallX_in; //where on wall the ray hits

logic [38:0] fifo_data_store; // // 9 (hcount) + 8 (line height) + 1 (wall type) + 4 (map data) + 16 (wallX) = 38 bits = [37:0]
logic fifo_tlast_store;

assign hcount_ray_in = fifo_data_store[37:29];
assign half_line_height = (fifo_data_store[28:21] >> 1);
assign wallType_in = fifo_data_store[20];
assign mapData_in = fifo_data_store[19:16];
assign wallX_in = fifo_data_store[15:0];

assign draw_start = HALF_SCREEN_HEIGHT - half_line_height;
assign draw_end = HALF_SCREEN_HEIGHT + half_line_height;

// TO USE IN MODULE
logic [9:0] vcount_ray;
logic [9:0] draw_start;
logic [9:0] draw_end;

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
                // ray pixel calculation
                // create a state where 
                case (mapData_in)
                    0, 1, 2: begin
                        // ray_pixel + address calculation
                        if ((vcount_ray >= draw_start) && (vcount_ray < draw_end)) begin
                            case (mapData_in)
                                0: ray_pixel_out <= BACKGROUND_COLOR;
                                1: ray_pixel_out <= BLACK_WALL;
                                2: ray_pixel_out <= GREEN_WALL;
                            endcase
                        end else begin
                            ray_pixel_out <= BACKGROUND_COLOR;
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
                                transformer_tready_out <= 1; // indicate transformer's readiness to receive new data
                                state <= FIFO_DATA_WAIT_NEW_PACKET;
                            end else begin                  // if we're not at the end of the packet
                                ray_last_pixel_out <= 0;    // reset things like normal and indicate transformer is ready to receive new data
                                transformer_tready_out <= 1;
                                vcount_ray <= 0;
                                state <= FIFO_DATA_WAIT;
                            end
                        end

                    end

                    3, 4, 5: begin
                        if ((vcount_ray >= draw_start) && (vcount_ray < draw_end)) begin
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
                        end else begin
                            ray_pixel_out <= BACKGROUND_COLOR;
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
                                    transformer_tready_out <= 1; // indicate transformer's readiness to receive new data
                                    state <= FIFO_DATA_WAIT_NEW_PACKET;
                                end else begin                  // if we're not at the end of the packet
                                    ray_last_pixel_out <= 0;    // reset things like normal and indicate transformer is ready to receive new data
                                    transformer_tready_out <= 1;
                                    vcount_ray <= 0;
                                    state <= FIFO_DATA_WAIT;
                                end
                            end
                        end
                    end
                endcase

            end
            // default : vcount_ray <= 0;
        endcase
    end
end


endmodule

`default_nettype wire