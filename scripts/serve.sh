#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd $SCRIPT_DIR/../
darklua process -w -c ./darklua.json src out &

rojo serve ./test.project.json &

cd $SCRIPT_DIR/../example_proxy
npm start
