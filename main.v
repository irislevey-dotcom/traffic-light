module main(
    input MAX10_CLK1_50,
    input [9:0] SW,
    input [1:0] KEY,
    output [9:0] LEDR,
    output [6:0] HEX0,
    output [6:0] HEX1,
	 output [35:0] GPIO
);

// =====================================================
// 1) DEBOUNCED KEYS
// =====================================================
wire Pushn;
wire Key1;

//'clean' both of the pushbuttons 
debounce db0(
    .clk(MAX10_CLK1_50),
    .key_in(KEY[0]),
    .key_out(Pushn)
);

debounce db1(
    .clk(MAX10_CLK1_50),
    .key_in(KEY[1]),
    .key_out(Key1)
);


//check that key1 was pressed and released 
reg key1_prev;

always @(posedge MAX10_CLK1_50) begin
    key1_prev <= Key1;   // Key1 is the debounced output
end

wire key1_pressed = (key1_prev == 1 && Key1 == 0);  // falling edge


// =====================================================
// 2) SYSTEM START LOGIC (KEY1) + RESET (SW0)
// =====================================================


reg system_started = 0;

always @(posedge MAX10_CLK1_50) begin
    if (!SW[0]) begin
        // SW0 = reset → return to startup state
        system_started <= 0;
    end 
    else begin
        // Only allow KEY1 to start the system when not started yet
			if (!system_started && key1_pressed) begin
				system_started <= 1;
			end

    end
end


// =====================================================
// 3) REAL 1 Hz CLOCK (for FSM)
// =====================================================
reg [25:0] sec_counter = 0;
reg one_hz_clk = 0;

always @(posedge MAX10_CLK1_50) begin
    if (sec_counter == 25_000_000) begin
			//reset second counter
        sec_counter <= 0;
        one_hz_clk <= ~one_hz_clk;   // toggles every 0.5s → 1 Hz
    end
    else begin
	 //increment
        sec_counter <= sec_counter + 1;
    end
end



// =====================================================
// 4) DIRECTION CONTROLLERS (LEFT + STRAIGHT)
// =====================================================

wire left_pre, straight_pre;
wire left_clear, left_enable;
wire straight_clear, straight_enable;
wire left_start, straight_start;
wire left_red_ctrl, left_yel_ctrl, left_grn_ctrl;
wire straight_red_ctrl, straight_yel_ctrl, straight_grn_ctrl;

// LEFT lights controller
direction_controller left_ctrl(
    .clk_1hz(one_hz_clk),
    .reset(SW[0]),
    .switch_up(system_started && SW[3]),
    .straight_pre(straight_pre), //gives straight priority if both are flipped up
    .bcd1(bcd1),
    .bcd0(bcd0),
	 .count_done(count_done),
	 .fsm_done(l_done),
    .bcd_clear(left_clear),
    .bcd_enable(left_enable),
    .start_fsm(left_start),
    .red_on(left_red_ctrl),
    .yellow_on(left_yel_ctrl),
    .green_on(left_grn_ctrl),
    .in_pre(left_pre)
);

// STRAIGHT lights controller (priority)
direction_controller straight_ctrl(
    .clk_1hz(one_hz_clk),
    .reset(SW[0]),
    .switch_up(system_started && SW[2]),
    .straight_pre(1'b0),   // STRAIGHT has no one above it
    .bcd1(bcd1),
    .bcd0(bcd0),
	 .count_done(count_done),
	 .fsm_done(s_done),
    .bcd_clear(straight_clear),
    .bcd_enable(straight_enable),
    .start_fsm(straight_start),
    .red_on(straight_red_ctrl),
    .yellow_on(straight_yel_ctrl),
    .green_on(straight_grn_ctrl),
    .in_pre(straight_pre)
);


// =====================================================
// 5) SHARED BCD COUNTER (STRAIGHT PRIORITY)
// =====================================================

//gives straight priority 
wire use_straight = straight_pre;
wire use_left     = left_pre && !straight_pre;

//the fsm is running if it's been told that either direction controller is started
wire fsm_running = left_start || straight_start;

//only count down if the fsm isn't running and the count isn't done, otherwise clear the countdown
wire bcd_enable = show_hex && !count_done && !fsm_running;
wire bcd_clear  = (!show_hex || fsm_running || !SW[0]);


//the countdown is done when 00 is reached 
wire [3:0] bcd1;
wire [3:0] bcd0;
wire count_done = (bcd1 == 4'd0) && (bcd0 == 4'd0);


//one instance of counter (both left and right can use)
bcd_counter shared_bcd(
    .clk(one_hz_clk),
    .clear(bcd_clear),
    .enable(bcd_enable),
    .bcd1(bcd1),
    .bcd0(bcd0)
);


// =====================================================
// 6) HEX DISPLAY (BLANK WHEN NO SWITCH REQUEST)
// =====================================================

//only show hex display when countdown is occuring and not yet done 
wire show_hex = (left_pre || straight_pre) && !count_done;

//if there's a countdown show that number, otherwise be blank
wire [3:0] active_bcd1 = show_hex ? bcd1 : 4'hF;
wire [3:0] active_bcd0 = show_hex ? bcd0 : 4'hF;


//create two converters, one for each hex display 
bcd_to_7seg seg0_display(
	.bcd(active_bcd0),
	.seg(HEX0)
	);

bcd_to_7seg seg1_display(
	.bcd(active_bcd1), 
	.seg(HEX1)
	);


// =====================================================
// 7) TRAFFIC FSMs (RUN ONLY WHEN CONTROLLER SAYS RUN)
// =====================================================

//variables for each LED color and to check if the fsms have completed running for either sensor/light
wire l_red, l_yellow, l_green;
wire s_red, s_yellow, s_green;
wire l_done, s_done; 

//fms for the left lights
timer_fsm l_fsm(
    .clk_1hz(one_hz_clk),
    .reset(SW[0]),
    .start(left_start),
    .red(l_red),
    .yellow(l_yellow),
    .green(l_green),
	 .done(l_done)
);


//fsm for the straight lights 
timer_fsm s_fsm(
    .clk_1hz(one_hz_clk),
    .reset(SW[0]),
    .start(straight_start),
    .red(s_red),
    .yellow(s_yellow),
    .green(s_green),
	 .done(s_done)
);

//tell LED 9 to turn on if the system hasn't started yet or if the fsm is running, otherwise be off
assign LEDR[9] =
    (!system_started) ? 1 :          // startup
    (left_start || straight_start) ? 1 :  // FSM running
    0;                                // idle or countdown

// =====================================================
// 8) GPIO OUTPUTS (CONTROLLER RED OR FSM OUTPUTS)
// =====================================================

// LEFT LEDs assignments for when to be on (red as default)
assign GPIO[0] = left_red_ctrl ? 1 : l_red;
assign GPIO[2] = left_yel_ctrl ? 0 : l_yellow;
assign GPIO[4] = left_grn_ctrl ? 0 : l_green;

// STRAIGHT LEDs assignments for when to be on (red as default)
assign GPIO[1] = straight_red_ctrl ? 1 : s_red;
assign GPIO[3] = straight_yel_ctrl ? 0 : s_yellow;
assign GPIO[5] = straight_grn_ctrl ? 0 : s_green;


endmodule