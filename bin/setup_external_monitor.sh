#!/bin/bash
EXTERNAL_OUTPUT="HDMI1"
INTERNAL_OUTPUT="LVDS1"

xrandr |grep $EXTERNAL_OUTPUT | grep " connected "
if [ $? -eq 0 ]; then
    xrandr --output $INTERNAL_OUTPUT --off --output $EXTERNAL_OUTPUT --auto 
    feh --bg-scale ~/Pictures/kravi_pozadi.JPG
else
    xrandr --output $INTERNAL_OUTPUT --auto --output $EXTERNAL_OUTPUT --off
    feh --bg-scale ~/Pictures/kravi_pozadi.JPG
fi
