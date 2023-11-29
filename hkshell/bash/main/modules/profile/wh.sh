#!/bin/bash
msg=$1
color=$2
if [ -n "$color" ]; then
    color=Null
    true
fi

color=$(echo "$color" | tr "[:lower:]" "[:upper:]")

case $color in
    NULL)
        color='\033[0m'
    ;;
    RED)
        color='\033[0;31m'
    ;;
    BLACK)
        color='\033[0;30m'
    ;;
    GREEN)
        color='\033[0;32m'
    ;;
    ORANGE)
        color='\033[0;33m'
    ;;
    BLUE)
        color='\033[0;34m'
    ;;
    PURPLE)
        color='\033[0;35m'
    ;;
    CYAN)
        color='\033[0;36m'
    ;;
    LIGHTGRAY)
        color='\033[0;37m'
    ;;
    DARKGRAY)
        color='\033[1;30m'
    ;;
    LIGHTRED)
        color='\033[1;31m'
    ;;
    LIGHTGREEN)
        color='\033[1;32m'
    ;;
    YELLOW)
        color='\033[1;33m'
    ;;
    LIGHTBLUE)
        color='\033[1;34m'
    ;;
    LIGHTPURPLE)
        color='\033[1;35m'
    ;;
    LIGHTCYAN)
        color='\033[1;36m'
    ;;
    WHITE)
        color='\033[1;37m'
    ;;

esac

echo -e "${color}${msg}"