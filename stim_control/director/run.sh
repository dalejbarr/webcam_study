#!/bin/bash -eu
REMOTE=yap

ssh -X $REMOTE bash -c "'
export DISPLAY=:0
cd matcher
./run_matcher.sh $1
'" > log_matcher.txt &
sleep 2
./run_director.sh $1 > log_director.txt
