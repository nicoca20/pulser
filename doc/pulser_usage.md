# Pulser Configuration Guide

This guide explains how to configure and operate the pulser module.

## Parameters

Each pulser provides several parameters to control its pulsing behavior:

- **F1 End**: Sets the period for frequency 1.
- **F1 Switch**: Sets the duty cycle for F1 (the switching point within the F1 period).
- **F2 End**: Sets the period for frequency 2.
- **F2 Switch**: Sets the duty cycle for F2 (the switching point within the F2 period).
- **F1 Count**: Number of cycles for the first pulse.
- **F2 Count**: Number of cycles for the second pulse.
- **STOP Count**: Number of cycles before the pulser stops.

> **Note:**  
> - **F1** and **F2** are two independent frequencies.  
> - The `End` parameter sets the frequency, while the `Switch` parameter sets the duty cycle for each frequency.

The diagram below illustrates how these parameters affect the pulser output:

[![Pulser Parameter Effects](show_config_params.svg)](show_config_params.svg)

## Output Modes

The pulser output can be further configured:

- **Inverted Output**: The output signal can be inverted during pulsing.
- **Idle State**: The idle state can be set to either 0 or 1.

See the figure below for different output mode configurations:

[![Output Modes](different_out_modes.svg)](different_out_modes.svg)

## Operation

- **Starting and Stopping**:  
  Once started, the pulser can be stopped with a stop pulse.  
  Sending a second start signal while the pulser is running has no effect.

- **Multiple Pulsers**:  
  You can run several pulsers sequentially or start them all at the same time.

Example of multiple pulsers in action:

[![Multiple Pulsers Example](pulsing_example.svg)](pulsing_example.svg)

## Stop Pulse Behavior

When the pulser is stopped, the output generates a "stop pulse" to signal the end of the sequence. The behavior of this stop pulse depends on which frequency was active last:

- **If the last pulse was at frequency F2:**
  The stop pulse will be an inverted F2 pulse.

- **Otherwise (if F2 was not active):**
  The stop pulse will be an inverted F1 pulse.

In both cases, the stop pulse starts at 0 and transitions to 1 after the configured switch point, following the duty cycle settings of the respective frequency.

This ensures a consistent and clearly defined end-of-sequence signal, matching the timing characteristics of the last active frequency but with inverted logic.