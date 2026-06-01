import sys

def main():
    try:
        num_channels = int(sys.argv[1])
        if num_channels < 1: raise
    except:
        print("Input argument for number of channels is not a number greater than 0")
        print("Default number of channels of 1 will be used")
        num_channels = 1

    # Set NUM_CHANNELS param in top level tb file
    with open('pwm_tb_top.sv', 'r') as f:
        lines = f.readlines()
    lines[7] = lines[7][0:30] + str(num_channels) + ";\n"
    with open('pwm_tb_top.sv', 'w') as f:
        f.writelines(lines)

    # Set NUM_CHANNELS param in pwm_test file
    with open('pwm_test.svh', 'r') as f:
        lines = f.readlines()
    lines[10] = lines[10][0:30] + str(num_channels) + ";\n"
    with open('pwm_test.svh', 'w') as f:
        f.writelines(lines)

    # Set NUM_CHANNELS param in pwm_monitor file
    with open('pwm_agent/pwm_monitor.svh', 'r') as f:
        lines = f.readlines()
    lines[7] = lines[7][0:30] + str(num_channels) + ";\n"
    with open('pwm_agent/pwm_monitor.svh', 'w') as f:
        f.writelines(lines)

    # Create NUM_CHANNELS pwm agents and scoreboards
    with open('pwm_env.svh', 'r') as f:
        lines = f.readlines()

    lines[32] = "class environment extends environment_base;\n\t`uvm_component_utils(environment)\n\n"
    for i in range(1, num_channels):  # add agent and scoreboard declarations
        pwm_agt_decl = "pwm_agent pwm_agt"+str(i)+";\n"
        scrb_decl = "scoreboard scrb"+str(i)+";\n"
        lines[32] = lines[32] + pwm_agt_decl + scrb_decl
    lines[32] = lines[32] + "\n\tfunction new(string name, uvm_component parent);\n\t\tsuper.new(name, parent);\n\tendfunction\n\n"
    lines[32] = lines[32] + "\tfunction void build_phase(uvm_phase phase);\n\t\tsuper.build_phase(phase);\n"
    for i in range(1, num_channels):  # build phase
        pwm_agt_build = "pwm_agt"+str(i)+" = pwm_agent::type_id::create(\"pwm_agt"+str(i)+"\", this);\n"
        pwm_config_set = "uvm_config_db#(int)::set(pwm_agt"+str(i)+", \"mon.*\", \"channel_num\", "+str(i)+");\n"
        scrb_build = "scrb"+str(i)+" = scoreboard::type_id::create(\"scoreboard"+str(i)+"\", this);\n"
        scrb_config_set = "uvm_config_db#(int)::set(scrb"+str(i)+", \"\", \"channel_num\", "+str(i)+");\n"
        lines[32] = lines[32] + pwm_agt_build + pwm_config_set + scrb_build + scrb_config_set
    lines[32] = lines[32] + "\tendfunction\n\n"
    lines[32] = lines[32] + "\tfunction void connect_phase(uvm_phase phase);\n\t\tsuper.connect_phase(phase);\n"
    for i in range(1, num_channels):  # connect phase
        agt_scrb_connect = "pwm_agt"+str(i)+".mon.pwm_ap.connect(scrb"+str(i)+".pwm_export);\n"
        lines[32] = lines[32] + agt_scrb_connect
    lines[32] = lines[32] + "\tendfunction\nendclass : environment\n"
    
    with open('pwm_env.svh', 'w') as f:
        f.writelines(lines[0:33])

    return

if __name__ == '__main__':
    main()
