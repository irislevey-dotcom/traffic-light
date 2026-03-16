module bcd_counter(
    input clk,
    input clear,
    input enable,
    output reg [3:0] bcd1 = 2,
    output reg [3:0] bcd0 = 0
);
    always @(posedge clk) begin
			//start at 20
        if (clear) begin
            bcd1 <= 2;
            bcd0 <= 0;
        end
		  
		  //if at 00 go back to 20
        else if (enable) begin
            if (bcd1 == 0 && bcd0 == 0) begin
                bcd1 <= 2;
                bcd0 <= 0;
            end
				
				//otherwise count down from 9 to 0 in 1s place
				//increment down by one in the 10s place once 0 is hit in 1s place
            else if (bcd0 == 0) begin
                bcd0 <= 9;
                bcd1 <= (bcd1 == 0) ? 9 : bcd1 - 1;
            end
            else
                bcd0 <= bcd0 - 1;
        end
    end
endmodule
