#!/bin/bash -eu

./expdebug2 -expdb data_raw/EESP4_Listener -dbdriver sqlite -session $1 -fullscreen
