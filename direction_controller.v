module direction_controller(
    input clk_1hz,
    input reset,
    input switch_up,
    input straight_pre, 
    input [3:0] bcd1,
    input [3:0] bcd0,
	 input count_done,
	input fsm_done,

    output reg bcd_clear,
    output reg bcd_enable,
    output reg start_fsm,
    output reg red_on,
    output reg yellow_on,
    output reg green_on,
    output reg in_pre
);

	//states 
    localparam IDLE = 0, PRE = 1, RUN = 2;

    reg [1:0] state = IDLE;
    reg prev_switch = 0;

	//check for pos edge of the clock 
    wire rising_edge = switch_up && !prev_switch;

    always @(posedge clk_1hz or negedge reset) begin
		
			//if reset immediately go into idle 
        if (!reset) begin
				state <= IDLE;
				prev_switch <= 0;
			end

		  else begin
            prev_switch <= switch_up;

            case (state)

                IDLE: begin
                    // Only start on DOWN→UP edge, and only if not blocked by STRAIGHT
                    if (rising_edge && !straight_pre)
                        state <= PRE;
                end

                PRE: begin //wait for the 20s timer to finish before doing anything
						 if (count_done)
							  state <= RUN;
						end


                RUN: begin
                    // in this state until the traffic lights have cycled fully 
                    if (fsm_done)
                        state <= IDLE;
                end

            endcase
        end
    end

 
    always @(*) begin
        in_pre    = (state == PRE);
        start_fsm = (state == RUN);

        // BCD counter only active in PRE
        bcd_clear  = (state == PRE);
        bcd_enable = (state == PRE);

        // Red is ON in IDLE and PRE, FSM drives colors in RUN
        red_on    = (state == IDLE || state == PRE);
        yellow_on = 0;
        green_on  = 0s;
    end

endmodule
