#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info_print()    { echo -e "${BLUE}$1${NC}"; }
error_print()   { echo -e "${RED}ERROR: $1${NC}" >&2; }
success_print() { echo -e "${GREEN}$1${NC}"; }
warn_print()    { echo -e "${YELLOW}WARNING: $1${NC}"; }

if [ ! -f "./config.env" ]; then
    error_print "config.env not found"
    exit 1
fi

source ./config.env

check_tool() {
    local tool="$1"

    if ! command -v "$tool" >/dev/null 2>&1; then
        error_print "$tool not found"
        return 1
    fi
}

install_fusesoc_libraries() {
    local lib_file="fusesoc_libraries.txt"

    if [ "${INSTALL_FUSESOC_LIBRARIES:-0}" != "1" ]; then
        warn_print "FuseSoC library installation disabled, skipping"
        return 0
    fi

    if [ ! -f "$lib_file" ]; then
        warn_print "$lib_file not found, skipping FuseSoC library installation"
        return 0
    fi

    check_tool fusesoc

    if [ -d "./fusesoc_libraries" ]; then
        info_print "Cleaning existing fusesoc_libraries"
        rm -rf ./fusesoc_libraries
    fi

    if [ -f "./fusesoc.conf" ]; then
        info_print "Cleaning existing fusesoc.conf"
        rm -f ./fusesoc.conf
    fi

    info_print "Installing FuseSoC libraries"

    while read -r name repo sync_version; do
        [[ -z "${name:-}" ]] && continue
        [[ "$name" =~ ^# ]] && continue

        if [ -z "${sync_version:-}" ]; then
            error_print "Invalid line in $lib_file: $name $repo"
            exit 1
        fi

        info_print "Adding FuseSoC library $name"
        fusesoc library add "$name" "$repo" --sync-version "$sync_version"
    done < "$lib_file"
}

apply_patch() {
    local repo_dir="$1"
    local patch_file="$2"
    local repo_name
    repo_name=$(basename "$repo_dir")

    if [ ! -d "$repo_dir" ]; then
        error_print "Directory '$repo_dir' does not exist"
        error_print "Did you forget to initialize submodules?"
        return 1
    fi

    pushd "$repo_dir" >/dev/null

    if [ ! -f "$patch_file" ]; then
        error_print "Patch file '$patch_file' does not exist"
        popd >/dev/null
        return 1
    fi

    if git apply --reverse --check "$patch_file" 2>/dev/null; then
        warn_print "Patch already applied in $repo_name, skipping"
    elif git apply --check "$patch_file" 2>/dev/null; then
        info_print "Applying patch to $repo_name"
        git apply "$patch_file"
    else
        error_print "Patch failed to apply in $repo_name"
        popd >/dev/null
        return 1
    fi

    popd >/dev/null
}

apply_patches_from_list() {
    local patch_list="patches/patch_list.txt"

    if [ "${APPLY_PATCHES:-0}" != "1" ]; then
        warn_print "Patch application disabled, skipping"
        return 0
    fi

    if [ ! -f "$patch_list" ]; then
        warn_print "$patch_list not found, skipping patches"
        return 0
    fi

    info_print "Applying patches from $patch_list"

    while read -r repo_dir patch_file; do
        [[ -z "${repo_dir:-}" ]] && continue
        [[ "$repo_dir" =~ ^# ]] && continue

        apply_patch "$repo_dir" "$patch_file"
    done < "$patch_list"
}

run_prebuild_config() {
    if [ "${PREBUILD_CONFIG_ENABLED:-0}" != "1" ]; then
        warn_print "Pre-build configuration disabled, skipping"
        return 0
    fi

    if [ -z "${PREBUILD_CONFIG_CMD:-}" ]; then
        error_print "PREBUILD_CONFIG_ENABLED=1 but PREBUILD_CONFIG_CMD is empty"
        exit 1
    fi

    info_print "Running pre-build configuration"
    bash -lc "$PREBUILD_CONFIG_CMD"
}

generate_version_header() {
    if [ "${GENERATE_VERSION_HEADER_ENABLED:-0}" != "1" ]; then
        warn_print "Version header generation disabled, skipping"
        return 0
    fi

    if [ -z "${GENERATE_VERSION_HEADER_CMD:-}" ]; then
        error_print "GENERATE_VERSION_HEADER_ENABLED=1 but GENERATE_VERSION_HEADER_CMD is empty"
        exit 1
    fi

    info_print "Generating version header"
    bash -lc "$GENERATE_VERSION_HEADER_CMD"
}

main() {
    if [ "${SETUP_ENABLED:-1}" != "1" ]; then
        warn_print "Setup disabled by config.env, skipping"
        exit 0
    fi

    info_print "Setting up ${PROJECT_NAME:-project}"

    if [ "${INIT_SUBMODULES:-0}" = "1" ]; then
        info_print "Initializing git submodules"
        git submodule update --init --recursive
    else
        warn_print "Submodule initialization disabled, skipping"
    fi

    install_fusesoc_libraries
    apply_patches_from_list
    run_prebuild_config
    generate_version_header

    success_print "Setup complete"
}

main "$@"