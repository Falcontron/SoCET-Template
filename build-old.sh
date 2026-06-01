#! /bin/sh
echo "Configuring RISC-V core"
pushd RISCVBusiness
python3 scripts/config_core.py ../aftx07.rvbcfg.yml
popd

./generate-version-header.sh

echo "Using fusesoc to build Verilator model"
fusesoc --cores-root . run --setup --build --build-root aft_out \
    --target sim --tool verilator socet:aft:aftx07

if hash xrun; then
    fusesoc --cores-root . run --setup --build --build-root aft_out_xcelium \
        --target sim --tool xcelium socet:aft:aftx07
else
    echo "No xrun, skipping xcelium build"
fi

echo "Build complete"
