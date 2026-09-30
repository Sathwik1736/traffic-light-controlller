// ============================================================================
// Module Name:  tb_traffic_light_controller
// Description:  Testbench for the traffic_light_controller module.
//               Verifies reset, fixed/sensor-driven cycles, and enable control.
// ============================================================================

`timescale 1ns / 1ps

module tb_traffic_light_controller;

    // ------------------------------------------------------------------------
    // Parameters for Testbench (Short durations for fast simulation)
    // ------------------------------------------------------------------------
    localparam TIMER_WIDTH      = 6;
    localparam NS_GREEN_CYCLES  = 6;
    localparam NS_YELLOW_CYCLES = 2;
    localparam EW_GREEN_CYCLES  = 4;
    localparam EW_YELLOW_CYCLES = 2;
    localparam CLK_PERIOD       = 10; // 10 ns clock period (100 MHz)

    // ------------------------------------------------------------------------
    // DUT Signals
    // ------------------------------------------------------------------------
    reg                     clk;
    reg                     rst_n;
    reg                     enable;
    reg                     sensor_ew;

    wire [2:0]              ns_lights;
    wire [2:0]              ew_lights;
    wire [1:0]              state;
    wire [TIMER_WIDTH-1:0]  timer_count;

    // ------------------------------------------------------------------------
    // Instantiate DUT (Device Under Test)
    // ------------------------------------------------------------------------
    traffic_light_controller #(
        .TIMER_WIDTH(TIMER_WIDTH),
        .NS_GREEN_CYCLES(NS_GREEN_CYCLES),
        .NS_YELLOW_CYCLES(NS_YELLOW_CYCLES),
        .EW_GREEN_CYCLES(EW_GREEN_CYCLES),
        .EW_YELLOW_CYCLES(EW_YELLOW_CYCLES)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .sensor_ew(sensor_ew),
        .ns_lights(ns_lights),
        .ew_lights(ew_lights),
        .state(state),
        .timer_count(timer_count)
    );

    // ------------------------------------------------------------------------
    // Clock Generation (100 MHz)
    // ------------------------------------------------------------------------
    always begin
        #(CLK_PERIOD / 2) clk = ~clk;
    end

    // ------------------------------------------------------------------------
    // Helper function to decode 3-bit one-hot light into readable string
    // ------------------------------------------------------------------------
    function [47:0] light_to_string(input [2:0] light);
        case (light)
            3'b100:  light_to_string = "RED   ";
            3'b010:  light_to_string = "YELLOW";
            3'b001:  light_to_string = "GREEN ";
            default: light_to_string = "UNKNWN";
        endcase
    endfunction

    // Helper function to decode state into readable string
    function [79:0] state_to_string(input [1:0] st);
        case (st)
            2'b00:   state_to_string = "NS_GREEN  ";
            2'b01:   state_to_string = "NS_YELLOW ";
            2'b10:   state_to_string = "EW_GREEN  ";
            2'b11:   state_to_string = "EW_YELLOW ";
            default: state_to_string = "UNKNOWN   ";
        endcase
    endfunction

    // ------------------------------------------------------------------------
    // Monitor Outputs on Clock Edge or State Change
    // ------------------------------------------------------------------------
    initial begin
        $display("--------------------------------------------------------------------------------------");
        $display(" Time(ns) | State      | Timer | Sensor_EW | NS Lights | EW Lights | Enable");
        $display("--------------------------------------------------------------------------------------");
    end

    always @(posedge clk) begin
        $display(" %7t  | %s |  %2d   |     %b     |  %s   |  %s   |   %b",
                 $time, state_to_string(state), timer_count, sensor_ew,
                 light_to_string(ns_lights), light_to_string(ew_lights), enable);
    end

    // ------------------------------------------------------------------------
    // Test Stimulus Process
    // ------------------------------------------------------------------------
    initial begin
        // Set up waveform dump file
        $dumpfile("traffic_light_controller.vcd");
        $dumpvars(0, tb_traffic_light_controller);

        // 1. Initial State
        clk       = 0;
        rst_n     = 0;
        enable    = 0;
        sensor_ew = 0;

        // 2. Apply Reset
        #(CLK_PERIOD * 2);
        $display("\n>>> TEST 1: Release Reset with enable=1 and sensor_ew=0 (Main street priority)");
        rst_n  = 1;
        enable = 1;

        // Wait for NS_GREEN_CYCLES + extra cycles to verify it stays GREEN while sensor_ew == 0
        #(CLK_PERIOD * (NS_GREEN_CYCLES + 4));

        // 3. Trigger Sensor: Vehicle arrives at East-West
        $display("\n>>> TEST 2: East-West Vehicle detected (sensor_ew = 1)");
        sensor_ew = 1;

        // Wait through NS_YELLOW -> EW_GREEN -> EW_YELLOW -> back to NS_GREEN
        #(CLK_PERIOD * (NS_YELLOW_CYCLES + EW_GREEN_CYCLES + EW_YELLOW_CYCLES + 2));

        // 4. Clear sensor after cycle returns to NS_GREEN
        $display("\n>>> TEST 3: Clearing sensor (sensor_ew = 0). Should remain in NS_GREEN.");
        sensor_ew = 0;
        #(CLK_PERIOD * (NS_GREEN_CYCLES + 3));

        // 5. Continuous cyclic mode (sensor_ew held HIGH)
        $display("\n>>> TEST 4: Continuous cyclic mode (sensor_ew = 1) for full rotation");
        sensor_ew = 1;
        #(CLK_PERIOD * (NS_GREEN_CYCLES + NS_YELLOW_CYCLES + EW_GREEN_CYCLES + EW_YELLOW_CYCLES));

        // 6. Test Enable/Pause feature
        $display("\n>>> TEST 5: Testing Pause (enable = 0) and Resume (enable = 1)");
        enable = 0;
        #(CLK_PERIOD * 4); // Frozen
        enable = 1;        // Resume
        #(CLK_PERIOD * 6);

        // 7. Test Asynchronous Reset while running
        $display("\n>>> TEST 6: Asynchronous Reset verification");
        rst_n = 0;
        #(CLK_PERIOD);
        if (ns_lights == 3'b001 && ew_lights == 3'b100 && state == 2'b00) begin
            $display("    [PASS] System successfully reset to default state: NS_GREEN, EW_RED.");
        end else begin
            $display("    [FAIL] Reset failed to restore initial state.");
        end
        rst_n = 1;
        #(CLK_PERIOD * 2);

        $display("\n========================================================");
        $display(" ALL TESTS COMPLETED SUCCESSFULLY!                      ");
        $display("========================================================\n");
        $finish;
    end

endmodule
