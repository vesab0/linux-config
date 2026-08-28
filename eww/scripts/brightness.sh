#!/bin/bash

case $1 in
  all)
    ddcutil setvcp 10 "$2"
    ;;
  left)
    ddcutil setvcp 10 "$2" --display 1
    ;;
  right)
    ddcutil setvcp 10 "$2" --display 2
    ;;
esac