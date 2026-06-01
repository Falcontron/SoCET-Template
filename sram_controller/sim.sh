if [ $# -lt 1 ]; then
  echo "Usage: $0 [run|compile]"
  exit 1
fi

action="$1"

if [ "$action" = "sim" ]; then
    fusesoc --cores-root .. run --no-export --target sim --tool xcelium socet:aft:sram_controller

elif [ "$action" = "wave" ]; then
    cd ./build/socet_aft_sram_controller_0.1.0/sim-xcelium
    make run-gui
elif [ "$action" = "sim_top" ]; then
    fusesoc --cores-root .. run --no-export --target sim --tool xcelium socet:aft:sram_wrapper
elif [ "$action" = "top_wave" ]; then
    cd ./build/socet_aft_sram_wrapper_0.1.0/sim-xcelium
    make run-gui
else
  echo "Invalid action: $action"
fi
