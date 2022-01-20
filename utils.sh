#!/bin/bash

function red() {
  printf "\033[31m%s\033[0m" "$@"
}

function green() {
  printf "\033[32m%s\033[0m" "$@"
}

function yellow() {
  printf "\033[33m%s\033[0m" "${@}"
}

function run() {  
  echo "$(green [run]) $@"
  "$@"
  local errcode="$?"
  if [[ "$errcode" != "0" && "$ignore" != "_ignore_" ]]; then
    echo "$(red [err: $errcode]) $@"
    exit 1
  fi
}

# Update/create an option in a given configuration file
# Usage:
#   $ setconf CONFIG_FILE [SECTION_NAME] SETTING_NAME SETTING_VALUE
function setconf {
    if [ $# = 3 ]; then
        file=$1; key=$2; val=$3

        [ ! -f $file ] && echo "$file not found." && return 1

        echo "Setting $key to $val in file $file"

        if grep -q "^$key *= *" $file; then
            sed -ci "s/\(^$key *= *\).*/\1$val/" $file
        else
        	sed -ci "s/^$/$key=$val\n/" $file
        fi

    elif [ $# = 4 ]; then
        file=$1; sec=$2; key=$3; val=$4

        [ ! -f $file ] && echo "$file not found." && return 1

        echo "Setting $key to $val in section [$sec] in file $file"

        sed -n "/^\[$2\]$/,/^$/p" $1 | grep -q "$3 *= *"
        grep_status=$?
        if [ $grep_status = 0 ]; then
            sed -ci "/^\[$sec\]$/,/^$/ s/\(^$key *= *\).*/\1$val/" $file
        else
        	sed -ci "s/\(^\[$sec\]$\)/\1\n$key=$val/" $file
    	fi

    else
        echo "Illegal number of arguments."; return 2
    fi
    return 0
}

# request language agnostic for [Y/n]
set -- $(locale LC_MESSAGES)
yes_expr="$1"
no_expr="$2";
yes_char="${3::1}"
no_char="${4::1}"

# Usage:
#   $ yn_prompt MESSAGE [Y|N]
function yn_prompt() {
    if [ "${2^}" = "Y" ]; then
        if [ $YES ]; then
            printf "true"
            return
        fi
        local yes_char=${yes_char^}
        local yes_expr="$yes_expr|^$"
    elif [ "${2^}" = "N" ]; then
        local no_char=${no_char^}
        local no_expr="$no_expr|^$"
    fi

    msg="$1 [$yes_char/$no_char] : "
    msg=$(yellow "${msg}")
    while true; do
        read -p "$msg"; 
        if [[ $REPLY =~ $yes_expr ]]; then
            printf "true"
            break
        elif [[ $REPLY =~ $no_expr ]]; then
            printf "false"
            break
        fi
    done
}

function title() {
    padding=$(( ( $(tput cols) - 48 ) / 2 ))
    clear
    echo ""
    for i in $(seq 1 $padding); do echo -n ' '; done
    echo -e "\033[1m―――――――  \033[1;34mFedora Auto Configuration Tool\033[0m\033[1m  ―――――――\033[0m"
    echo ""
}