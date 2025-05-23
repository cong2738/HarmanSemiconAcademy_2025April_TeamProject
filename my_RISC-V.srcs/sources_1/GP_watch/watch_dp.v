`timescale 1ns / 1ps

module watch_dp #(
    parameter COUNT_100HZ = 1_000_000,
    parameter MSEC_MAX = 100,
    parameter SEC_MAX = 60,
    parameter MIN_MAX = 60,
    parameter HOUR_MAX = 24
) (
    input clk,
    input reset,
    input [2:0] hms,
    output [31:0] msec,
    output [31:0] sec,
    output [31:0] min,
    output [31:0] hour,
    input  [31:0] set_msec,
    input  [31:0] set_sec,
    input  [31:0] set_min,
    input  [31:0] set_hour,
    input         setSig
);
    wire w_tick_100hz;
    // 100Hz tick generator
    watch_tick_100hz #(
        .COUNT_100HZ(COUNT_100HZ)
    ) U_Tick_100hz (
        .clk(clk),  // 100Mhz
        .reset(reset),
        .o_tick_100hz(w_tick_100hz)
    );

    wire [$clog2(MSEC_MAX)-1:0] w_msec;
    wire w_msec_clk;
    watch_counter_tick #(
        .TICK_COUNT(MSEC_MAX)
    ) U_Count_Msec (  // msec
        .clk(clk),
        .reset(reset),
        .add_time(0),
        .tick(w_tick_100hz),  //100hz => 0.01sec
        .setSig(setSig),
        .set_data(set_msec),
        .counter(w_msec),
        .o_tick(w_msec_clk)  // 100hz/100 = 1hz => 1sec
    );

    wire [$clog2(SEC_MAX)-1:0] w_sec;
    wire w_sec_clk;
    watch_counter_tick #(
        .TICK_COUNT(SEC_MAX)
    ) U_Count_sec0 (  // sec
        .clk(clk),
        .reset(reset),
        .add_time(hms[0]),
        .tick(w_msec_clk),  //1hz
        .setSig(setSig),
        .set_data(set_sec),
        .counter(w_sec),
        .o_tick(w_sec_clk)  // 1/60hz => 60sec
    );

    wire [$clog2(MIN_MAX)-1:0] w_min;
    wire w_min_clk;
    watch_counter_tick #(
        .TICK_COUNT(MIN_MAX)
    ) U_Count_Min0 (
        .clk(clk),
        .reset(reset),
        .add_time(hms[1]),
        .tick(w_sec_clk),
        .setSig(setSig),
        .set_data(set_min),
        .counter(w_min),
        .o_tick(w_min_clk)  //60min
    );

    wire [$clog2(HOUR_MAX)-1:0] w_hour;
    wire w_hour_clk;
    watch_counter_tick #(
        .TICK_COUNT(HOUR_MAX)
    ) U_Count_Hour0 (
        .clk(clk),
        .reset(reset),
        .add_time(hms[2]),
        .tick(w_min_clk),
        .setSig(setSig),
        .set_data(set_hour),
        .counter(w_hour),
        .o_tick(w_hour_clk)  //60min
    );
    assign msec = w_msec;
    assign sec  = w_sec;
    assign min  = w_min;
    assign hour = w_hour;
endmodule

// 100Hz tick generator
module watch_tick_100hz #(
    parameter COUNT_100HZ = 1_000_000
) (
    input clk,  // 100Mhz
    input reset,
    output o_tick_100hz
);

    reg [$clog2(COUNT_100HZ)-1:0] r_counter;
    reg r_tick_100hz;

    assign o_tick_100hz = r_tick_100hz;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_counter <= 0;
            r_tick_100hz <= 0;
        end else begin
            if (r_counter == (COUNT_100HZ - 1)) begin // 100_000_000 / 1_000_000 = 100hz
                r_counter <= 0;
                r_tick_100hz <= 1'b1;
            end else begin
                r_counter <= r_counter + 1;
                r_tick_100hz <= 1'b0;
            end
        end
    end

endmodule

module watch_counter_tick #(
    parameter TICK_COUNT = 10_000
) (
    input clk,
    input reset,
    input add_time,
    input tick,
    input setSig,
    input [31:0]set_data,
    output [31 : 0] counter,
    output o_tick
);
    //         state        next
    reg [31:0] counter_reg, counter_next;
    reg r_tick;

    assign counter = counter_reg;
    assign o_tick  = r_tick;

    // state
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
        end else begin      
            if (counter_reg == TICK_COUNT) begin
                counter_reg <= 0;
            end else counter_reg <= counter_next + add_time;
        end
    end

    // next
    always @(*) begin
        r_tick = 1'b0;
        counter_next = counter_reg;
        if(setSig) begin
            counter_next = set_data;
        end else if (tick == 1'b1) begin  // tick count
            if (counter_reg == TICK_COUNT - 1) begin
                counter_next = 0;
                r_tick = 1'b1;
            end else begin
                counter_next = counter_reg + 1;
                r_tick = 1'b0;
            end
        end
    end

endmodule
