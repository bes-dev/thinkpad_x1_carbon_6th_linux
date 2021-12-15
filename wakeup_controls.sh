#!/bin/bash

tee /sys/bus/serio/devices/serio1/drvctl < <(printf none)
tee /sys/bus/serio/devices/serio1/drvctl < <(printf reconnect)
