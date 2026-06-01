#! /bin/bash

CHIP_NAME=$(cat chip_name.txt)
GIT_TAG=$(git tag --points-at HEAD 2>/dev/null)
GIT_HASH=$(git rev-parse --short HEAD)

if [ -n "$GIT_TAG" ]; then
    VERSION_INFO="$CHIP_NAME ($(echo $GIT_TAG | awk '{print $1}'))";
else
    VERSION_INFO="$CHIP_NAME (git+$GIT_HASH)"
fi

cat <<EOL > ./top_level/tb/version.h
#ifndef VERSION_H
#define VERSION_H

#define VERSION_INFO "$VERSION_INFO"

#endif
EOL
