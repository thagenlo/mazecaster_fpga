module countdown_timer 
#(
  parameter INITIAL_TIME = 30 // start countdown from 30 seconds
)(
    input logic clk_100MHz_in,             // 100 MHz clock
    input logic rst_in,           // reset signal
    input logic start_timer,           // start countdown signal
    output logic [31:0] time_left, // remaining time in seconds
    output logic end_timer             // signal to indicate timer has reached zero
);

    // parameters
    localparam int CLOCK_FREQ = 100_000_000; // 100 MHz

    // Registers
    logic [$clog2(CLOCK_FREQ)-1:0] clk_div_counter; // Clock divider counter
    logic clk_1Hz;                                  // 1 Hz clock signal
    logic counting;                                 // Indicates if countdown is active

    // Clock divider: Generate 1 Hz clock from 100 MHz clock
    always_ff @(posedge clk_100MHz_in) begin
        if (rst_in) begin
            clk_div_counter <= 0;
            clk_1Hz <= 0;
        end else begin
            if (clk_div_counter == CLOCK_FREQ - 1) begin
                clk_div_counter <= 0;
                clk_1Hz <= ~clk_1Hz; // Toggle 1 Hz clock signal
            end else begin
                clk_div_counter <= clk_div_counter + 1;
            end
        end
    end

    // Countdown logic
    always_ff @(posedge clk_1Hz) begin
        if (rst_in) begin
            time_left <= INITIAL_TIME; // Reset to initial time
            counting <= 0;
            end_timer <= 0;
        end else if (start_timer) begin
            counting <= 1; // Start countdown
        end

        if (counting) begin
            if (time_left > 0) begin
                time_left <= time_left - 1; // Decrement the timer
            end else begin
                counting <= 0; // Stop countdown
                end_timer <= 1;     // Signal that timer has finished
            end
        end
    end
endmodule
