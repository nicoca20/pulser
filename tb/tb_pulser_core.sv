`timescale 1ns/1ps

module tb_pulser_core;
  localparam ClkPeriod    = 10ns;
  localparam ClkHigh      = ClkPeriod / 2;

  // Clock & Reset
  logic clk = 0;
  logic rst;

  always #ClkHigh clk = ~clk;

  // DUT inputs
  logic start, stop;
  logic [7:0] f1_cnt, f2_cnt, stop_cnt;
  logic [15:0] f1_end, f1_switch, f2_end, f2_switch;
  logic invert_out, idle_out;

  // DUT outputs
  logic pulse;
  logic [2:0] state;

  // Test control
  int testconfig_num;
  string stimuli_file;
  int ref_fd;
  int cycle = 0, errors = 0;
  int expected_pulse;

  // Instantiate DUT
  pulser_core dut (
    .clk_i(clk),
    .rst_ni(rst),
    .start_i(start),
    .stop_i(stop),
    .f1_cnt_i(f1_cnt),
    .f2_cnt_i(f2_cnt),
    .stop_cnt_i(stop_cnt),
    .f1_end_i(f1_end),
    .f1_switch_i(f1_switch),
    .f2_end_i(f2_end),
    .f2_switch_i(f2_switch),
    .invert_out_i(invert_out),
    .idle_out_i(idle_out),
    .pulse_o(pulse),
    .state_o(state)
  );

  initial begin
    if (!$value$plusargs("testconfig=%d", testconfig_num)) begin
      $fatal("Missing +testconfig=<N> argument");
    end
    $display("Running test config %0d", testconfig_num);

    stimuli_file = $sformatf("golden_pulser/stimuli_%0d.txt", testconfig_num);

    $display("Opening stimuli file: %s", stimuli_file);
    ref_fd = $fopen(stimuli_file, "r");
    if (ref_fd == 0) begin
      $fatal("Failed to open stimuli file: %s", stimuli_file);
    end

    @(posedge clk);

    // Read input values and apply them to DUT
    while (!$feof(ref_fd)) begin
      // Read one line from the stimuli file
      int rst_s, start_s, stop_s, f1_cnt_s, f2_cnt_s, stop_cnt_s, f1_end_s, f1_switch_s, f2_end_s, f2_switch_s, invert_out_s, idle_out_s, expected_pulse_s;
      string line;
      void'($fgets(line, ref_fd));
      if ($sscanf(line, "%b %b %b %d %d %d %d %d %d %d %d %d %d", 
          rst_s, start_s, stop_s, f1_cnt_s, f2_cnt_s, stop_cnt_s, f1_end_s, f1_switch_s, f2_end_s, f2_switch_s, invert_out_s, idle_out_s, expected_pulse_s) == 13) begin

        // Apply the stimulus to DUT inputs
        @(posedge clk); // Wait for the rising edge of the clock
        
        // Apply the stimulus values
        // (wait 1ns, otherwise start will instantly start the pulser )
        #1 rst = rst_s[0];
        start = start_s[0];
        stop = stop_s[0];
        f1_cnt = f1_cnt_s[7:0];
        f2_cnt = f2_cnt_s[7:0];
        stop_cnt = stop_cnt_s[7:0];
        f1_end = f1_end_s[15:0];
        f1_switch = f1_switch_s[15:0];
        f2_end = f2_end_s[15:0];
        f2_switch = f2_switch_s[15:0];
        invert_out = invert_out_s[0];
        idle_out = idle_out_s[0];
        #1 expected_pulse = expected_pulse_s[0];

        // Read the expected pulse from the stimuli file
        // void'($fscanf(ref_fd, "%d\n", expected_pulse));
        
        // Check the output against the expected pulse value
        if (pulse !== expected_pulse) begin
          $display("Mismatch at t=%0t | cycle=%0d | DUT Pulse=%0b | Expected Pulse=%0b", $time, cycle, pulse, expected_pulse);
          errors++;
        end
        
        cycle++;
      end
    end

    $fclose(ref_fd);
    $display("Test config %0d completed: %0d cycles, %0d errors", testconfig_num, cycle, errors);
    if (errors == 0) $display("PASS");
    else $display("FAIL");

    $finish;
  end

  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, tb_pulser_core);
  end

endmodule
