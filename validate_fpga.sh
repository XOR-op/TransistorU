#!/bin/sh
# build testcase
./build_test.sh $@
if [ -f .test/test.ans ]; then rm ./test/test.ans; fi
# copy test input
if [ -f ./testcase/$@.in ]; then cp ./testcase/$@.in ./test/test.in; fi
# copy test output
if [ -f ./testcase/$@.ans ]; then cp ./testcase/$@.ans ./test/test.ans; fi
# add your own test script here
# Example: assuming serial port on /dev/ttyUSB1
./ctrl/build.sh
#sudo ./ctrl/run.sh ./test/test.bin ./test/test.in /dev/ttyUSB1 -I
sudo ./ctrl/run.sh ./test/test.bin ./test/test.in /dev/ttyUSB1 -T > ./test/test.out
if [ -f ./test/test.ans ]; then diff ./test/test.ans ./test/test.out; fi
