module debounce(
    input  clk,        // 50 MHz clock
    input  key_in,     // raw button (active-low)
    output reg key_out // debounced button (still active-low, cleaner)
);

    reg [19:0] cnt = 0; //20 cycles to let clock stabilize
    reg stable = 1; //tracks last known stable value

    always @(posedge clk) begin
        if (key_in != stable) begin //if button is changing
            cnt <= cnt + 1;
            if (cnt == 20'd1_000_000) begin   // ~20ms at 50MHz
				
					//update stored values and reset count
                stable <= key_in;
                key_out <= key_in;
                cnt <= 0;
            end
        end else begin
            cnt <= 0; //input returned to stable value, so ignore this
        end
    end
endmodule
