import random
import os
import numpy as np

output_dir = "golden_pulser"
MIN_RESET_CYCLES = 3
CONFIG_SETUP_DELAY = 1
START_DELAY_AFTER_RESET = 3
FINAL_IDLE_CYCLES = 10

# ---------------------------------------------------------------------
# Golden Model for pulse_o calculation based on signal table (NumPy)
# ---------------------------------------------------------------------
def golden_model(signal_table):
    # Phase 0: Idle, phase 1: Run F1, phase 2: run F2, phase 3: run Stop, phase 4: done
    cnt_clk = 0
    cnt_pulse = 0
    phase = 0
    # running = False

    for i in range(len(signal_table)):
        sig = signal_table[i]

        # if i > 0:
        #     past_sig = signal_table[i-1]
        # else:
        #     past_sig = sig
        #     if past_sig["start_i"] or past_sig["stop_i"]:
        #         sys.exit("Error: Starting with a start or stop directly cannot be calculated with current golden model!")

        # Handle Reset
        if sig["rst_ni"] == 0:
            cnt_clk = 0
            cnt_pulse = 0
            phase = 0
            signal_table[i]["expected_pulse_o"] = 0
            # running = False

        # Handle Stop
        elif sig["stop_i"]:
            cnt_clk = 0
            cnt_pulse = 0
            phase = 0
            signal_table[i]["expected_pulse_o"] = sig["idle_out_i"]
            # running = False

        # Handle start
        elif sig["start_i"] and phase == 0 and sig["rst_ni"] == 1:
            if sig["f1_cnt_i"] > 0:
                phase = 1
            elif sig["f2_cnt_i"] > 0:
                phase = 2
            elif sig["stop_cnt_i"] > 0:
                phase = 3
            else:
                phase = 4
            signal_table[i]["expected_pulse_o"] = sig["idle_out_i"]

        # Handle pulsing
        else:
            cnt_clk += 1
            if phase == 0:
                cnt_clk = 0
                cnt_pulse = 0
                signal_table[i]["expected_pulse_o"] = sig["idle_out_i"]
            elif phase == 1:
                if sig["invert_out_i"]:
                    signal_table[i]["expected_pulse_o"] = not (cnt_clk <= sig["f1_switch_i"])
                else:
                    signal_table[i]["expected_pulse_o"] = cnt_clk <= sig["f1_switch_i"]
                if cnt_clk == sig["f1_end_i"]:
                    cnt_clk = 0
                    cnt_pulse += 1
                    if cnt_pulse == sig["f1_cnt_i"]:
                        cnt_pulse = 0
                        if sig["f2_cnt_i"] > 0:
                            phase = 2
                        elif sig["stop_cnt_i"] > 0:
                            phase = 3
                        else:
                            phase = 4
            elif phase == 2:
                if sig["invert_out_i"]:
                    signal_table[i]["expected_pulse_o"] = not (cnt_clk <= sig["f2_switch_i"])
                else:
                    signal_table[i]["expected_pulse_o"] = cnt_clk <= sig["f2_switch_i"]
                if cnt_clk == sig["f2_end_i"]:
                    cnt_clk = 0
                    cnt_pulse += 1
                    if cnt_pulse == sig["f2_cnt_i"]:
                        cnt_pulse = 0
                        if sig["stop_cnt_i"] > 0:
                            phase = 3
                        else:
                            phase = 4
            elif phase == 3:
                if sig["f2_cnt_i"] > 0 and sig["f2_end_i"] > 0:
                    compval_end = sig["f2_end_i"]
                    compval_switch = sig["f2_switch_i"]
                elif sig["f1_cnt_i"] > 0 and sig["f1_end_i"] > 0:
                    compval_end = sig["f1_end_i"]
                    compval_switch = sig["f1_switch_i"]
                else:
                    phase = 4
                    continue # todo: working?
                if sig["invert_out_i"]:
                    signal_table[i]["expected_pulse_o"] = cnt_clk <= compval_switch
                else:
                    signal_table[i]["expected_pulse_o"] = not (cnt_clk <= compval_switch)

                if cnt_clk == compval_end:
                    cnt_clk = 0
                    cnt_pulse += 1
                    if cnt_pulse == sig["stop_cnt_i"]:
                        cnt_pulse = 0
                        phase = 4

            elif phase == 4:
                phase = 0
                cnt_clk = 0
                cnt_pulse = 0
                signal_table[i]["expected_pulse_o"] = sig["idle_out_i"]

    return signal_table

# ---------------------------------------------------------------------
# Random configuration generator
# ---------------------------------------------------------------------
def generate_rand_config(force_invert=None, force_idle=None, no_stop=False, no_f2=False):
    f1_cnt = random.randint(1, 5)
    f1_end = random.randint(6, 20)
    f1_switch = random.randint(1, f1_end - 1)

    f2_cnt = 0 if no_f2 else random.randint(1, 5)
    f2_end = random.randint(6, 20) if f2_cnt > 0 else 0
    f2_switch = random.randint(1, f2_end - 1) if f2_cnt > 0 else 0

    stop_cnt = 0 if no_stop else random.randint(1, 3)
    invert = force_invert if force_invert is not None else random.randint(0, 1)
    idle = force_idle if force_idle is not None else random.randint(0, 1)

    return {
        "f1_cnt": f1_cnt, "f1_end": f1_end, "f1_switch": f1_switch,
        "f2_cnt": f2_cnt, "f2_end": f2_end, "f2_switch": f2_switch,
        "stop_cnt": stop_cnt, "invert": invert, "idle": idle
    }

# ---------------------------------------------------------------------
# Writers
# ---------------------------------------------------------------------
def write_config(config, index):
    os.makedirs(output_dir, exist_ok=True)
    with open(f"{output_dir}/config_{index}.txt", "w") as f:
        for k, v in config.items():
            f.write(f"{k} = {v}\n")

def write_stimuli(signal_table, index):
    os.makedirs(output_dir, exist_ok=True)
    with open(f"{output_dir}/stimuli_{index}.txt", "w") as f:
        headers = signal_table.dtype.names
        f.write("# " + " ".join(headers) + "\n")
        for row in signal_table:
            f.write(" ".join(str(row[h]) for h in headers) + "\n")

# ---------------------------------------------------------------------
# Build signal table and run golden model
# ---------------------------------------------------------------------
def create_testcase(config, index):
    total_cycles = (
        MIN_RESET_CYCLES + START_DELAY_AFTER_RESET +
        config["f1_cnt"] * config["f1_end"] +
        config["f2_cnt"] * config["f2_end"] +
        config["stop_cnt"] * (config["f2_end"] if config["f2_cnt"] > 0 else config["f1_end"]) +
        FINAL_IDLE_CYCLES
    )

    dtype = [
        ("rst_ni", np.int32), ("start_i", np.int32), ("stop_i", np.int32),
        ("f1_cnt_i", np.int32), ("f2_cnt_i", np.int32), ("stop_cnt_i", np.int32),
        ("f1_end_i", np.int32), ("f1_switch_i", np.int32),
        ("f2_end_i", np.int32), ("f2_switch_i", np.int32),
        ("invert_out_i", np.int32), ("idle_out_i", np.int32),
        ("expected_pulse_o", np.int32)
    ]

    signal_table = np.zeros(total_cycles, dtype=dtype)

    for t in range(total_cycles):
        rst_ni = 0 if t < MIN_RESET_CYCLES else 1
        start_i = 1 if t == MIN_RESET_CYCLES + START_DELAY_AFTER_RESET else 0
        use_cfg = t >= MIN_RESET_CYCLES + CONFIG_SETUP_DELAY

        signal_table[t] = (
            rst_ni, start_i, 0,
            config["f1_cnt"] if use_cfg else 0,
            config["f2_cnt"] if use_cfg else 0,
            config["stop_cnt"] if use_cfg else 0,
            config["f1_end"] if use_cfg else 0,
            config["f1_switch"] if use_cfg else 0,
            config["f2_end"] if use_cfg else 0,
            config["f2_switch"] if use_cfg else 0,
            config["invert"] if use_cfg else 0,
            config["idle"] if use_cfg else 0,
            0
        )

    golden_model(signal_table)
    write_config(config, index)
    write_stimuli(signal_table, index)
    print(f"Test {index:02d} written with {len(signal_table)} cycles")

# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------
def main():
    random.seed(43)
    index = 0

    for inv in [0, 1]:
        for idle in [0, 1]:
            for _ in range(2):
                cfg = generate_rand_config(force_invert=inv, force_idle=idle)
                create_testcase(cfg, index)
                index += 1

    for _ in range(2):
        cfg = generate_rand_config(no_stop=True)
        create_testcase(cfg, index)
        index += 1

    for _ in range(2):
        cfg = generate_rand_config(no_f2=True)
        create_testcase(cfg, index)
        index += 1

if __name__ == "__main__":
    main()
