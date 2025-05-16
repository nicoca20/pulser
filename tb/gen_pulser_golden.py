import random
import os

output_dir = "golden_pulser"
MIN_RESET_CYCLES = 3
CONFIG_SETUP_DELAY = 1
START_DELAY_AFTER_RESET = 3
FINAL_IDLE_CYCLES = 10

# ---------------------------------------------------------------------
# Golden Model for pulse_o calculation based on signal table
# ---------------------------------------------------------------------
def golden_model(signal_table):
    IDLE = "IDLE"
    RUN_F1 = "RUN_F1"
    RUN_F2 = "RUN_F2"
    RUN_STOP = "RUN_STOP"
    DONE = "DONE"

    state = IDLE
    pulse_cnt = 0
    clk_cnt = 0
    current_end = 0
    current_switch = 0
    target_count = 0
    prev_pulse = 0
    reset_active = True

    for sig in signal_table:
        pulse_o = sig["idle_out_i"]

        if sig["rst_ni"] == 0:
            state = IDLE
            pulse_cnt = 0
            clk_cnt = 0
            prev_pulse = sig["idle_out_i"]
            sig["expected_pulse_o"] = prev_pulse
            reset_active = True
            continue

        if reset_active and sig["rst_ni"] == 1:
            reset_active = False

        start = sig["start_i"]
        stop = sig["stop_i"]

        if stop:
            state = IDLE
            pulse_cnt = 0
            clk_cnt = 0
        elif state == IDLE:
            if start:
                if sig["f1_cnt_i"] > 0 and sig["f1_end_i"] > 0:
                    state = RUN_F1
                    current_end = sig["f1_end_i"]
                    current_switch = sig["f1_switch_i"]
                    target_count = sig["f1_cnt_i"]
                    pulse_cnt = 0
                    clk_cnt = 0
                elif sig["f2_cnt_i"] > 0 and sig["f2_end_i"] > 0:
                    state = RUN_F2
                    current_end = sig["f2_end_i"]
                    current_switch = sig["f2_switch_i"]
                    target_count = sig["f2_cnt_i"]
                    pulse_cnt = 0
                    clk_cnt = 0
                elif sig["stop_cnt_i"] > 0:
                    current_end = sig["f2_end_i"] if sig["f2_cnt_i"] > 0 else sig["f1_end_i"]
                    current_switch = sig["f2_switch_i"] if sig["f2_cnt_i"] > 0 else sig["f1_switch_i"]
                    target_count = sig["stop_cnt_i"]
                    state = RUN_STOP
                    pulse_cnt = 0
                    clk_cnt = 0
                else:
                    state = DONE
        elif state in [RUN_F1, RUN_F2, RUN_STOP]:
            if clk_cnt == current_end - 1:
                pulse_cnt += 1
                clk_cnt = 0
            else:
                clk_cnt += 1

            if pulse_cnt == target_count:
                if state == RUN_F1:
                    if sig["f2_cnt_i"] > 0 and sig["f2_end_i"] > 0:
                        state = RUN_F2
                        current_end = sig["f2_end_i"]
                        current_switch = sig["f2_switch_i"]
                        target_count = sig["f2_cnt_i"]
                        pulse_cnt = 0
                        clk_cnt = 0
                    elif sig["stop_cnt_i"] > 0:
                        current_end = sig["f2_end_i"] if sig["f2_cnt_i"] > 0 else sig["f1_end_i"]
                        current_switch = sig["f2_switch_i"] if sig["f2_cnt_i"] > 0 else sig["f1_switch_i"]
                        target_count = sig["stop_cnt_i"]
                        state = RUN_STOP
                        pulse_cnt = 0
                        clk_cnt = 0
                    else:
                        state = DONE
                elif state == RUN_F2:
                    if sig["stop_cnt_i"] > 0:
                        current_end = sig["f2_end_i"] if sig["f2_cnt_i"] > 0 else sig["f1_end_i"]
                        current_switch = sig["f2_switch_i"] if sig["f2_cnt_i"] > 0 else sig["f1_switch_i"]
                        target_count = sig["stop_cnt_i"]
                        state = RUN_STOP
                        pulse_cnt = 0
                        clk_cnt = 0
                    else:
                        state = DONE
                elif state == RUN_STOP:
                    state = DONE
        elif state == DONE:
            state = IDLE

        if state in [RUN_F1, RUN_F2]:
            pulse_o = 1 if clk_cnt < current_switch else 0
            if sig["invert_out_i"]:
                pulse_o ^= 1
        elif state == RUN_STOP:
            pulse_o = 0 if clk_cnt < current_switch else 1
            if sig["invert_out_i"]:
                pulse_o ^= 1
        else:
            pulse_o = sig["idle_out_i"]

        sig["expected_pulse_o"] = prev_pulse
        prev_pulse = pulse_o

    return signal_table

# ---------------------------------------------------------------------
# Random configuration generator
# ---------------------------------------------------------------------
def generate_config(force_invert=None, force_idle=None, no_stop=False, no_f2=False):
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
        headers = list(signal_table[0].keys())
        f.write("# " + " ".join(headers) + "\n")
        for row in signal_table:
            f.write(" ".join(str(row[k]) for k in headers) + "\n")

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

    signal_table = []
    for t in range(total_cycles):
        rst_ni = 0 if t < MIN_RESET_CYCLES else 1
        start_i = 1 if t == MIN_RESET_CYCLES + START_DELAY_AFTER_RESET else 0
        use_cfg = t >= MIN_RESET_CYCLES + CONFIG_SETUP_DELAY

        signal_table.append({
            "rst_ni": rst_ni,
            "start_i": start_i,
            "stop_i": 0,
            "f1_cnt_i": config["f1_cnt"] if use_cfg else 0,
            "f2_cnt_i": config["f2_cnt"] if use_cfg else 0,
            "stop_cnt_i": config["stop_cnt"] if use_cfg else 0,
            "f1_end_i": config["f1_end"] if use_cfg else 0,
            "f1_switch_i": config["f1_switch"] if use_cfg else 0,
            "f2_end_i": config["f2_end"] if use_cfg else 0,
            "f2_switch_i": config["f2_switch"] if use_cfg else 0,
            "invert_out_i": config["invert"] if use_cfg else 0,
            "idle_out_i": config["idle"] if use_cfg else 0
        })

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
                cfg = generate_config(force_invert=inv, force_idle=idle)
                create_testcase(cfg, index)
                index += 1

    for _ in range(2):
        cfg = generate_config(no_stop=True)
        create_testcase(cfg, index)
        index += 1

    for _ in range(2):
        cfg = generate_config(no_f2=True)
        create_testcase(cfg, index)
        index += 1

if __name__ == "__main__":
    main()
