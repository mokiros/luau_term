#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd $SCRIPT_DIR/../
darklua process -c ./darklua.json src out
rojo build --output ./luau_term.rbxm ./default.project.json
