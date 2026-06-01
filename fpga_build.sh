#flag variables
use_wrapper=true
ecefolder="SOCET" # /SOCET is default

# Define the options string for getopts
# 'n' for disabling the FPGA wrapper (no argument)
# 'o:' for destination repo on local machine (requires an argument)

source .venv/bin/activate

while getopts "no:" opt; do
  case $opt in
    n)
      use_wrapper=false
      ;;
    o)
      ecefolder="$OPTARG"
      ;;
    \?) # Handle invalid options
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :) # Handle missing arguments for options
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

if [ "$use_wrapper" = true ]; then
  fusesoc --cores-root . run --build --target fpga socet:aft:aftx07_wrapper
  ssh ececomp "rm -rf '${ecefolder}/fpga-quartus'"
  scp -rq quartus_automation/* build/socet_aft_aftx07_wrapper_0.2.0/fpga-quartus/ ececomp:"$ecefolder"
else
  fusesoc --cores-root . run --build --target fpga socet:aft:aftx07
  ssh ececomp "rm -rf '${ecefolder}/fpga-quartus'"
  scp -rq quartus_automation/* build/socet_aft_aftx07_2.0.0/fpga-quartus/ ececomp:"$ecefolder"
fi
