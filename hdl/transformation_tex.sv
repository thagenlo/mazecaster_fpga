`timescale 1ns / 1ps
`default_nettype none

/*
Version 2:
    - transformation with texture handling

QUESTIONS:
    - repitition of state code
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

                        output logic transformer_tready_out,         // tells FIFO that we're ready to receive next data (need a vcount counter)

                        output logic [15:0] ray_address_out,    // where to store the pixel value in frame buffer
                        output logic [15:0] ray_pixel_out,      // the calculated pixel value of the ray
                        output logic ray_last_pixel_out        // tells frame buffer whether we are on the last pixel or not
                        );
// STATE MACHINE
typedef enum {
	    FIFO_DATA_WAIT,     // wait for valid vertical line data from the FIFO
        FLATTENING          // iterating through all vcounts for hcount, and transmitting corresponding (v,h) pixel value
	} t_state;

t_state state;

// PARAMETERS
localparam [15:0] BACKGROUND_COLOR = 65535;
localparam [15:0] WHITE_WALL = 0;
localparam [7:0] HALF_SCREEN_HEIGHT = (SCREEN_HEIGHT >> 1);

// FROM DDA FIFO
logic [8:0] hcount_ray_in; //pipelined x_coord
logic [7:0] half_line_height; // = SCREEN_HEIGHT/perpWallDist
logic wallType_in; // 0 = X wall hit, 1 = Y wall hit
logic [3:0] mapData_in;  // value 0 -> 2^4 at map[mapX][mapY] from BROM
logic [15:0] wallX_in; //where on wall the ray hits

logic [37:0] fifo_data_store; // // 9 (hcount) + 8 (line height) + 1 (wall type) + 4 (map data) + 16 (wallX) = 38 bits = [37:0]

assign hcount_ray_in = fifo_data_store[37:29];
assign half_line_height = (fifo_data_store[28:21] >> 1);
assign wallType_in = fifo_data_store[20];
assign mapData_in = fifo_data_store[19:16];
assign wallX_in = fifo_data_store[15:0];

// TO USE IN MODULE
logic [7:0] vcount_ray;
logic [7:0] draw_start;
logic [7:0] draw_end;

logic [15:0] tex_pixel;
logic [1:0] tex_counter; // counts from 0 to 2
logic tex_req; // 1 = valid request, 0 = no request

textures texture_mod (
    .pixel_clk_in(clk_pixel),
    .rst_in(sys_rst),
    .valid_req_in(tex_req),
    .wallX_in(wallX_in),
    .vcount_ray_in(vcount_ray),
    .texture_in(mapData_in),
    .tex_pixel_out(tex_pixel)
);

always_comb begin
    case (state)
        FIFO_DATA_WAIT: begin
            transformer_tready_out = 1; // ready to receive new data
        end

        FLATTENING: begin
            transformer_tready_out = 0; // not ready to receive new data

            // ray pixel calculation
            draw_start = HALF_SCREEN_HEIGHT - half_line_height;
            draw_end = HALF_SCREEN_HEIGHT + half_line_height;
            if ((vcount_ray >= draw_start) && (vcount_ray < draw_end)) begin
                case (mapData_in) // based on map data
                    0: ray_pixel_out = BACKGROUND_COLOR; ray_pixel_valid = 1;
                    1: ray_pixel_out = WALL_COLOR;
                    2: ray_pixel_out = 
                endcase
            end else begin // out of bounds
                ray_pixel_out = BACKGROUND_COLOR;
            end

            // ray address calculation
            ray_address_out = hcount_ray_in + vcount_ray*SCREEN_WIDTH;
        end
    endcase
end

always_ff @(posedge pixel_clk_in) begin
    if (rst_in) begin
        vcount_ray <= 0;
        state <= FIFO_DATA_WAIT;
        tex_counter <= 0;
        tex_req <= 0;
    end else begin
        case (state)
            FIFO_DATA_WAIT: begin
                ray_last_pixel_out <= 0;
                if (dda_fifo_tvalid_in) begin // handshake for fifo data
                    state <= FLATTENING;
                    fifo_data_store <= dda_fifo_tdata_in; // store fifo data in a register
                end else begin
                    state <= FIFO_DATA_WAIT;
                end
            end

            FLATTENING: begin
                if ((vcount_ray >= draw_start) && (vcount_ray < draw_end)) begin // if we've hit a wall
                    case (mapData_in) // based on map data
                        // easy 1 cycle cases
                        0, 1, 2: begin
                            // method
                            case (mapData_in)
                                0: ray_pixel_out <= BACKGROUND_COLOR;
                                1: ray_pixel_out <= WHITE_WALL;
                                2: ray_pixel_out <= {hcount_ray_in >> 4, vcount_ray >> 2, hcount_ray_in >> 4 + vcount_ray >> 3};
                            endcase
                            ray_address_out <= hcount_ray_in + vcount_ray*SCREEN_WIDTH;
                            // state transitions
                            if (vcount_ray < SCREEN_HEIGHT-1) begin
                                vcount_ray <= vcount_ray + 1;
                                ray_last_pixel_out <= 0;
                                state <= FLATTENING;
                            end else begin
                                ray_last_pixel_out <= (dda_fifo_tlast_in);  // we are only at the last (h,v) pixel if vcount == SCREEN_HEIGHT and on the last hcount
                                vcount_ray <= 0;
                                state <= FIFO_DATA_WAIT;
                            end
                        end

                        // accessing texture modules
                        3, 4, 5: begin
                            if (tex_counter == 0) begin
                                tex_req <= 1;
                                tex_counter <= tex_counter + 1;
                                state <= FLATTENING;
                            end else if (tex_counter == 1) begin
                                tex_req <= 0;
                                tex_counter <= tex_counter + 1;
                                state <= FLATTENING;
                            end else if (tex_counter == 2) begin
                                // method
                                ray_last_pixel_out <= tex_pixel_out;
                                ray_address_out <= hcount_ray_in + vcount_ray*SCREEN_WIDTH;
                                tex_counter <= 0;
                                // state transitions
                                if (vcount_ray < SCREEN_HEIGHT-1) begin
                                    vcount_ray <= vcount_ray + 1;
                                    ray_last_pixel_out <= 0;
                                    state <= FLATTENING;
                                end else begin
                                    ray_last_pixel_out <= (dda_fifo_tlast_in);  // we are only at the last (h,v) pixel if vcount == SCREEN_HEIGHT and on the last hcount
                                    vcount_ray <= 0;
                                    state <= FIFO_DATA_WAIT;
                                end
                            end
                        end
                    endcase
                end else begin // out of bounds
                    ray_pixel_out <= BACKGROUND_COLOR;
                    ray_address_out <= hcount_ray_in + vcount_ray*SCREEN_WIDTH;
                    // state transitions
                    if (vcount_ray < SCREEN_HEIGHT-1) begin
                        vcount_ray <= vcount_ray + 1;
                        ray_last_pixel_out <= 0;
                        state <= FLATTENING;
                    end else begin
                        ray_last_pixel_out <= (dda_fifo_tlast_in);  // we are only at the last (h,v) pixel if vcount == SCREEN_HEIGHT and on the last hcount
                        vcount_ray <= 0;
                        state <= FIFO_DATA_WAIT;
                    end
                end
            end
        endcase
    end
end


endmodule

`default_nettype wire