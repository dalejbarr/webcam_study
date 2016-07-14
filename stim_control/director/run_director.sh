#!/bin/bash -eu

exp-eyelink/src/expdebug2 -expdb data_raw/EESP4_Speaker -dbdriver sqlite -session $1 -fullscreen
