#!/bin/bash

if [[ "$1" == "-b" ]]
then
    cd node
    ./build
    cd ../opsmgr
    ./build
    cd ..
fi

printf "Starting up the OM container - will take about 5-8 minutes to be ready\n"
cd opsmgr
docker network create mongonet
./run
