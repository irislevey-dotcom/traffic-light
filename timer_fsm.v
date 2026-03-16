module timer_fsm(
    input clk_1hz,
    input reset,
    input start,
    output reg red,
    output reg yellow,
    output reg green,
	 output reg done
);



//the three states possible
    localparam S_RED   = 0;
    localparam S_GREEN = 1;
    localparam S_YEL   = 2;

    reg [1:0] state = S_RED;
    reg [2:0] timer = 0;   // enough for 0–5

    always @(posedge clk_1hz or negedge reset) begin
	 //turn red when reset and when not started - red is default
        if (!reset) begin
            state <= S_RED;
            timer <= 0;
        end else if (!start) begin
            // When not started, hold in RED
            state <= S_RED;
            timer <= 0;
        end 
		  else begin
			 case (state)
			 //slight buffer when countdown is done before transitioning to green
				  S_RED: begin
						if (timer == 1) begin
							 state <= S_GREEN;
							 timer <= 0;
						end else begin
							 timer <= timer + 1;
						end
				  end
				//show green for 5 s then go to yellow
				  S_GREEN: begin
						if (timer == 5) begin
							 state <= S_YEL;
							 timer <= 0;
						end else begin
							 timer <= timer + 1;
						end
				  end
					//show yellow for 2 seconds then go back to red
				  S_YEL: begin
						if (timer == 2) begin
							 state <= S_RED;
							 timer <= 0;
						end else begin
							 timer <= timer + 1;
						end
				  end
			 endcase
end

    end
	 
	 
	 
//assigning outputs to states 
    always @(*) begin
        red    = (state == S_RED);
        green  = (state == S_GREEN);
        yellow = (state == S_YEL);
		  
		//the lights are done doing their cycle at the final second of yellow 
    done = (state == S_YEL && timer == 3'd2);
    end

endmodule
