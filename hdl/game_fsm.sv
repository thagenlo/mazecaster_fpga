module game_fsm #(
    )(input wire clk_in,
    input wire rst_in,
    input wire [3:0] btn,                   // buttons for move control and rotation
    input wire [15:0] sw, 
    input wire [15:0] posX, 
    input wire [15:0] posY,
    input wire timer_done,
    output logic [1:0] screen_display,
    // output logic game_state,
    output logic start_timer
    );
    typedef enum {IDLE, START_GAME, GAME, GAME_WON, GAME_LOST} game_state_type;
    typedef enum {NEON_OUT, THREE_PIGS, FIND_DINO, HEDGE} game_selection;

    logic goal_pos_count;
    game_selection game_sel;
    game_state_type game_state;
    logic game_progress; //add which location they've hit
    logic [15:0] goal_posX1;
    logic [15:0] goal_posY1;
    logic [15:0] goal_posX2;
    logic [15:0] goal_posY2;
    logic [15:0] goal_posX3;
    logic [15:0] goal_posY3;
    // logic [15:0] goal_posX4;
    // logic [15:0] goal_posY4;
    logic found_pos1;
    logic found_pos2;
    logic found_pos3;
    // logic found_pos4; 
    localparam screen_time = 600_000_000;
    logic [$clog(screen_time):0] screen_time_count;
    


    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            game_state <= IDLE;
            goal_pos_count <= 0;
            screen_display <= 0;
            goal_posX1 <= 0;
            goal_posY1 <= 0;
            goal_posX2 <= 0;
            goal_posY2 <= 0;
            goal_posX3 <= 0;
            goal_posY3 <= 0;
            screen_time_count <= 0;
            // goal_posX4 <= 0;
            // goal_posY4 <= 0;
            game_sel <= NEON_OUT;
        end else begin
            case (game_state)
                IDLE: begin
                    screen_time_count <= 0;
                    if (sw[6]) begin
                        game_state <= START_GAME;
                        screen_display <= 1; //display start screen
                    end //else just display maps w/o timer/game logic (normal raycasting)
                end
                START_GAME: begin //put up start screen in buffer
                    if (btn[1]) begin
                        game_state <= GAME; 
                        start_timer <= 1;
                        screen_display <= 0;
                    end
                    if (sw[4] && sw[5]) begin //find dino
                        game_sel <= FIND_DINO;
                        goal_posX1 <= 0; //TODO: cathy CHANGES this
                        goal_posY1 <= 0;
                    end
                    else if (sw[4]) begin //hedge
                        game_sel <= HEDGE;
                        goal_posX1 <= 16'h00c0; //TODO: tori CHANGES this
                        goal_posY1 <= 16'h0b00;
                    end
                    else if (sw[5]) begin //3 little pigs
                        game_sel <= THREE_PIGS;
                        goal_posX1 <= 1; //TODO: tori CHANGES this
                        goal_posY1 <= 2;
                        goal_posX2 <= 3;
                        goal_posY2 <= 4;
                        goal_posX3 <= 5;
                        goal_posY3 <= 6;
                    end
                    else begin //neon out
                        game_sel <= NEON_OUT;
                        goal_posX1 <= 0; //TODO: cathy CHANGES this
                        goal_posY1 <= 0;
                    end
                end
                GAME: begin
                    start_timer <= 0;
                    if (timer_done) begin
                        game_state <= GAME_LOST;
                    end else begin
                        case (game_sel)
                            FIND_DINO: begin
                                if (found_pos1) begin
                                    game_state <= GAME_WON;
                                    screen_time_count <= 0;
                                end
                                else if ((posX == goal_posX1) && (posY == goal_posY1)) begin
                                    found_pos1 <= 1;
                                end
                            end
                            THREE_PIGS: begin
                                if (found_pos1 && found_pos2 && found_pos3) begin
                                    game_state <= GAME_WON;
                                    screen_time_count <= 0;
                                end
                                else if ((posX == goal_posX1) && (posY == goal_posY1)) begin
                                    found_pos1 <= 1;
                                end
                                else if ((posX == goal_posX2) && (posY == goal_posY2)) begin
                                    found_pos2 <= 1;
                                end
                                else if ((posX == goal_posX3) && (posY == goal_posY3)) begin
                                    found_pos3 <= 1;
                                end
                            end
                            HEDGE: begin
                                if (found_pos1) begin
                                    game_state <= GAME_WON;
                                    screen_time_count <= 0;
                                end
                                else if ((posX == goal_posX1) && (posY == goal_posY1)) begin
                                    found_pos1 <= 1;
                                end
                            end
                        endcase
                    end
                end
                GAME_LOST: begin //5 seconds
                    if (btn[2]) begin
                        screen_time_count <= screen_time_count+1;
                        screen_display <= 1;
                        game_state <= START_GAME;
                    end 
                    else if (btn[3]) begin
                        screen_display <= 0;
                        game_state <= IDLE;
                    end
                    else begin
                        screen_display <= 2; //game_lost
                        game_state <= GAME_LOST;
                    end
                end
                GAME_WON: begin //5 seconds
                    screen_time_count <= screen_time_count+1;
                    if (btn[2]) begin
                        screen_display <= 1;
                        game_state <= START_GAME;
                    else if (btn[3]) begin
                        screen_display <= 0;
                        game_state <= IDLE;
                    end
                    end else begin
                        screen_display <= 3;
                        game_state <= GAME_WON;
                    end
                end
            endcase

        end
    end


endmodule