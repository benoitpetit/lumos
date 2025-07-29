#!/bin/bash

# Script to publish Lumos on LuaRocks

# Define the rockspec file
ROCKSPEC="lumos-1.0.0-1.rockspec"

# Check if the rockspec file exists
if [ ! -f "$ROCKSPEC" ]; then
  echo "Error: Rockspec file $ROCKSPEC not found."
  exit 1
fi

# Build the rockspec
luarocks build "$ROCKSPEC"
if [ $? -ne 0 ]; then
  echo "Error: Failed to build $ROCKSPEC."
  exit 1
fi

# Publish the rockspec
luarocks upload --force "$ROCKSPEC"
if [ $? -ne 0 ]; then
  echo "Error: Failed to upload $ROCKSPEC to LuaRocks."
  exit 1
fi

echo "Successfully published $ROCKSPEC to LuaRocks."

