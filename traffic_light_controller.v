// ============================================================================
// Module Name:  traffic_light_controller
// Description:  A synthesizable Finite State Machine (FSM) based Traffic Light
//               Controller for a 4-way intersection (North-South & East-West).
//
// Features:
//   - Configurable timing parameters for Green and Yellow phases
//   - Parameterizable timer bit-width for simulation or real-time FPGA clocks
//   - 3-bit one-hot light encoding: {RED, YELLOW, GREEN}
//   - Side-street (East-West) vehicle demand sensor input (hold high for cyclic mode)
//   - Active-low asynchronous reset (rst_n)
//   - Enable signal for pause/resume or clock enable division
//   - Glitch-free registered light outputs
// ============================================================================

`timescale 1ns / 1ps

module traffic_light_controller #(
    // Phase durations (in clock cycles / ticks)
    // Default values are set for rapid simulation; can be customized on instantiation
    parameter TIMER_WIDTH      = 6,   // Bit-width of timer counter
    parameter NS_GREEN_CYCLES  = 10,  // North-South Green duration
    parameter NS_YELLOW_CYCLES = 3,   // North-South Yellow duration
    parameter EW_GREEN_CYCLES  = 6,   // East-West Green duration
    parameter EW_YELLOW_CYCLES = 3    // East-West Yellow duration
)(
    input  wire                     clk,          // System clock
    input  wire                     rst_n,        // Active-low asynchronous reset
    input  wire                     enable,       // Controller clock enable (1 = run, 0 = hold)
    input  wire                     sensor_ew,    // East-West vehicle sensor (1 = demand/active, 0 = idle)

    output reg  [2:0]               ns_lights,    // North-South: [2]=RED, [1]=YELLOW, [0]=GREEN
    output reg  [2:0]               ew_lights,    // East-West:   [2]=RED, [1]=YELLOW, [0]=GREEN
    output reg  [1:0]               state,        // Current FSM state
    output wire [TIMER_WIDTH-1:0]   timer_count   // Current timer value
);

    // ------------------------------------------------------------------------
    // Light Encodings (One-Hot: {RED, YELLOW, GREEN})
    // ------------------------------------------------------------------------
    localparam RED    = 3'b100;
    localparam YELLOW = 3'b010;
    localparam GREEN  = 3'b001;

    // ------------------------------------------------------------------------
    // FSM State Encoding
    // ------------------------------------------------------------------------
    localparam S_NS_GREEN  = 2'b00;  // North-South Green,  East-West Red
    localparam S_NS_YELLOW = 2'b01;  // North-South Yellow, East-West Red
    localparam S_EW_GREEN  = 2'b10;  // North-South Red,    East-West Green
    localparam S_EW_YELLOW = 2'b11;  // North-South Red,    East-West Yellow

    // ------------------------------------------------------------------------
    // Internal Signals
    // ------------------------------------------------------------------------
    reg [1:0]               next_state;
    reg [TIMER_WIDTH-1:0]   timer_reg;
    reg                     timer_clear;

    assign timer_count = timer_reg;

    // ------------------------------------------------------------------------
    // Timer / Counter Sequential Logic
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timer_reg <= {TIMER_WIDTH{1'b0}};
        end else if (enable) begin
            if (timer_clear) begin
                timer_reg <= {TIMER_WIDTH{1'b0}};
            end else if ((state == S_NS_GREEN) && (!sensor_ew) && (timer_reg >= (NS_GREEN_CYCLES - 1))) begin
                // Hold at threshold until side-street vehicle arrives
                timer_reg <= timer_reg;
            end else begin
                timer_reg <= timer_reg + 1'b1;
            end
        end
    end

    // ------------------------------------------------------------------------
    // FSM State Register Sequential Logic
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_NS_GREEN;
        end else if (enable) begin
            state <= next_state;
        end
    end

    // ------------------------------------------------------------------------
    // FSM Next-State Logic
    // ------------------------------------------------------------------------
    always @(*) begin
        next_state  = state;
        timer_clear = 1'b0;

        case (state)
            S_NS_GREEN: begin
                // Stays Green for at least NS_GREEN_CYCLES.
                // Transitions to Yellow if vehicle sensor on East-West is asserted.
                if (timer_reg >= (NS_GREEN_CYCLES - 1)) begin
                    if (sensor_ew) begin
                        next_state  = S_NS_YELLOW;
                        timer_clear = 1'b1;
                    end else begin
                        next_state  = S_NS_GREEN;
                        timer_clear = 1'b0;
                    end
                end
            end

            S_NS_YELLOW: begin
                if (timer_reg >= (NS_YELLOW_CYCLES - 1)) begin
                    next_state  = S_EW_GREEN;
                    timer_clear = 1'b1;
                end
            end

            S_EW_GREEN: begin
                if (timer_reg >= (EW_GREEN_CYCLES - 1)) begin
                    next_state  = S_EW_YELLOW;
                    timer_clear = 1'b1;
                end
            end

            S_EW_YELLOW: begin
                if (timer_reg >= (EW_YELLOW_CYCLES - 1)) begin
                    next_state  = S_NS_GREEN;
                    timer_clear = 1'b1;
                end
            end

            default: begin
                next_state  = S_NS_GREEN;
                timer_clear = 1'b1;
            end
        endcase
    end

    // ------------------------------------------------------------------------
    // Glitch-Free Registered Output Logic
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ns_lights <= GREEN;
            ew_lights <= RED;
        end else if (enable) begin
            case (next_state)
                S_NS_GREEN: begin
                    ns_lights <= GREEN;
                    ew_lights <= RED;
                end

                S_NS_YELLOW: begin
                    ns_lights <= YELLOW;
                    ew_lights <= RED;
                end

                S_EW_GREEN: begin
                    ns_lights <= RED;
                    ew_lights <= GREEN;
                end

                S_EW_YELLOW: begin
                    ns_lights <= RED;
                    ew_lights <= YELLOW;
                end

                default: begin
                    ns_lights <= RED;
                    ew_lights <= RED;
                end
            endcase
        end
    end

endmodule
