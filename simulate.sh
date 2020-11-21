#!/bin/sh
# build testcase
./build_test.sh $@
# copy test input
if [ -f ./testcase/$@.in ]; then cp ./testcase/$@.in ./test/test.in; fi
# copy test output
if [ -f ./testcase/$@.ans ]; then cp ./testcase/$@.ans ./test/test.ans; fi
# add your own test script here
# Example:
# - iverilog/gtkwave/vivado
# - diff ./test/test.ans ./test/test.out
cd src/
iverilog cpu.v common/*/*.v ../sim/testbench.v -o ../test_simulation/a.out
cd ../test_simulation/
vvp a.out
