module clock_divider(
    input clk, //super fast clock 
    output slow_clk //clock that operates closer to 1s per period
);

    reg [25:0] counter = 0; //continuously increments

    always @(posedge clk)
        counter <= counter + 1; //count increments on every pos edge of clock

    assign slow_clk = counter[25];  //full clock period is 2^26 pos edges counted
endmodule