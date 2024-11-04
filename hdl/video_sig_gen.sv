module video_sig_gen
#(
  parameter ACTIVE_H_PIXELS = 1280,
  parameter H_FRONT_PORCH = 110,
  parameter H_SYNC_WIDTH = 40,
  parameter H_BACK_PORCH = 220,
  parameter ACTIVE_LINES = 720,
  parameter V_FRONT_PORCH = 5,
  parameter V_SYNC_WIDTH = 5,
  parameter V_BACK_PORCH = 20,
  parameter FPS = 60)
(
  input wire pixel_clk_in,
  input wire rst_in,
  output logic [$clog2(TOTAL_PIXELS)-1:0] hcount_out,
  output logic [$clog2(TOTAL_LINES)-1:0] vcount_out,
  output logic vs_out, //vertical sync out
  output logic hs_out, //horizontal sync out
  output logic ad_out, // active drawing indicator (low when in blanking or sync period, high when actively drawing)
  output logic nf_out, //single cycle enable signal
  output logic [5:0] fc_out); //frame

  localparam TOTAL_PIXELS = LINE_LENGTH * TOTAL_LINES; //figure this out
    //   localparam TOTAL_LINES = 750; //figure this out
  localparam LINE_LENGTH = ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH + H_BACK_PORCH;
  localparam LAST_V_INDEX = TOTAL_LINES - 1;
  localparam LAST_H_INDEX = LINE_LENGTH - 1;
  localparam TOTAL_LINES = ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH + V_BACK_PORCH;
  localparam H_PORCH_START_INDEX = ACTIVE_H_PIXELS - 1;
  localparam V_PORCH_START_INDEX = ACTIVE_LINES - 1;
  localparam H_SYNC_START = ACTIVE_H_PIXELS + H_FRONT_PORCH;
  localparam V_SYNC_START = ACTIVE_LINES + V_FRONT_PORCH;
  localparam H_SYNC_END = ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH;
  localparam V_SYNC_END = ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH;

    // V SYNC SIGNAL
    always_comb begin
        if ((vcount_out >= V_SYNC_START) && (vcount_out < V_SYNC_END)) begin
            vs_out = 1;
        end else begin
            vs_out = 0;
        end
    end

    // H SYNC SIGNAL
    always_comb begin
        if ((hcount_out >= H_SYNC_START) && (hcount_out < H_SYNC_END)) begin
                hs_out = 1;
            end else begin
                hs_out = 0;
            end
    end

    always_comb begin
        if (rst_in) begin
            ad_out = 0;
        end else begin
            if ((hcount_out >= ACTIVE_H_PIXELS) || vcount_out >= ACTIVE_LINES) begin
                ad_out = 0;
            end else begin
                ad_out = 1;
            end
        end
    end

    always_ff @(posedge pixel_clk_in) begin
        if (rst_in) begin
            vcount_out <= 0;
            hcount_out <= 0;
            fc_out <= 0;
            nf_out <= 0;
        end else begin
            // ad_out <= 1;
            case (vcount_out)
                V_PORCH_START_INDEX: begin
                    case (hcount_out)
                        H_PORCH_START_INDEX-1: begin
                            // nf_out <= 1; // right before new frame flag
                            nf_out <= 0;
                            hcount_out <= hcount_out + 1;
                        end
                        H_PORCH_START_INDEX: begin
                            // ad_out <= 0; // right before entering blank period
                            nf_out <= 0;
                            hcount_out <= hcount_out + 1;
                        end
                        LAST_H_INDEX: begin
                            vcount_out <= vcount_out + 1;
                            hcount_out <= 0;
                        end
                        default begin
                            nf_out <= 0;
                            hcount_out <= hcount_out + 1;
                        end
                    endcase
                end
                V_PORCH_START_INDEX + 1: begin
                    case (hcount_out)
                        H_PORCH_START_INDEX: begin
                            fc_out <= (fc_out < FPS-1) ? fc_out + 1: 0;// 1279 right before inc fc at 1280
                            nf_out <= 1;
                            hcount_out <= hcount_out + 1;
                        end
                        LAST_H_INDEX: begin
                            vcount_out <= vcount_out + 1;
                            nf_out <= 0;
                            hcount_out <= 0;
                        end
                        default begin
                            nf_out <= 0;
                            hcount_out <= hcount_out + 1;
                        end
                    endcase
                    // ad_out <= 0;
                end
                LAST_V_INDEX: begin
                    case (hcount_out)
                        LAST_H_INDEX: begin // (1649, 749) last pixel of entire display
                            vcount_out <= 0;
                            hcount_out <= 0;
                            // ad_out <= 1;
                        end
                        default hcount_out <= hcount_out + 1;
                    endcase
                end
                default begin // for all other parts PROBLEM: will go back here and set 
                    case (hcount_out)
                        LAST_H_INDEX: begin
                            // if (vcount_out < V_PORCH_START_INDEX) ad_out <= 1;
                            hcount_out <= 0;
                            vcount_out <= vcount_out + 1;
                        end 
                        H_PORCH_START_INDEX: begin
                            // ad_out <= 0;
                            hcount_out <= hcount_out + 1;
                        end
                        default begin
                            // ad_out <= 1;
                            hcount_out <= hcount_out + 1;
                        end
                    endcase
                end
            endcase
        end
    end
endmodule