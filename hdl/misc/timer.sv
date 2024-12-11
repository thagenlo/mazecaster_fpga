module timer #(
    parameter TIMER_SECONDS = 60
)
(
    input wire clk_100mhz_in,
    input wire rst_in,
    input wire start_timer_in,

    output logic [9:0] time_out,
    output logic timer_done_out
);

typedef enum {
    NOT_COUNTING,
    COUNTING
	} t_state;

t_state state; // 0 = not counting down, 1 = counting down

localparam COUNTS_FOR_ONE_SEC = 32'h5F5E100; // 100,000,000 (cycles in a second for our clock)
// localparam COUNTS_FOR_ONE_SEC = 10;
logic [$clog2(COUNTS_FOR_ONE_SEC)-1:0] counter_to_sec;

always_ff @(posedge clk_100mhz_in) begin
    if (rst_in) begin
      counter_to_sec <= 0;
      time_out <= 60;
      timer_done_out <= 0;
      state <= NOT_COUNTING;
    end else begin
        case (state)
            NOT_COUNTING: begin
                timer_done_out <= 0;
                if (start_timer_in) begin
                    state <= COUNTING;          // start counting when we've recieved signal to start
                    counter_to_sec <= 0;
                end else begin
                    counter_to_sec <= 0;             // reset counter
                    time_out <= 60;  // reset timer
                end
            end
            COUNTING: begin
                if (time_out > 0) begin
                    if (counter_to_sec + 1 >= COUNTS_FOR_ONE_SEC) begin
                        counter_to_sec <= (counter_to_sec + 1) - COUNTS_FOR_ONE_SEC;
                        time_out <= time_out - 1;
                    end else begin
                        counter_to_sec <= counter_to_sec + 1;
                    end
                end else begin
                    timer_done_out <= 1;
                    time_out <= 0;
                    state <= NOT_COUNTING;
                end
            end
        endcase
    end
  end

endmodule