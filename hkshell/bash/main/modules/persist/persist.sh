#!/bin/bash

prolix=false

function p_join {
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "$f" "${@/#/$d}"
  elif shift 1; then
    echo "$d"
  fi
}

function p_is_array () {
    # no argument passed
    [[ $# -ne 1 ]] && echo 'Supply a variable name as an argument'>&2 && return 2
    local var=$1
    # use a variable to avoid having to escape spaces
    local regex="^declare -[aA] ${var}(=|$)"
    [[ $(declare -p "$var" 2> /dev/null) =~ $regex ]] && return 0
}

function p_wh () {
    local msg=$1
    local color=$2
    if [ -n "$color" ]; then
        color=Null
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

    echo -e "${color}${msg}" > /dev/tty
}

function p_ehe () {
    p_wh 'administrative rights required to access host global cfg' RED
}

function p_prolix () {
    local message=$1
    local messageColor=$2
    local meta=$3
    [[ "$prolix" = "true" ]] || return 
    p_wh "    << $message" "$messageColor"
    if [[ -n "$meta" ]]; then
        p_wh "    #META#$message" YELLOW
    fi
}

function p_prolix_function () {
    local message=$1
    local messageColor=$2
    local meta=$3
    [[ "$prolix" = "true" ]] || return
    p_wh ">_ $message" "$messageColor"
    if [[ -n "$meta" ]]; then
        p_wh "    #META#$message" YELLOW
    fi
}

function p_match() {
    p_prolix_function "p_match"
    # Parameters
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    for arg in "$@"; do
        case $arg in
            -g|--getmatch)
                local getmatch=true
                ;;
            -n|--not)
                local not=true
                ;;
            *)
                if [[ -z "$string" ]]; then 
                    local string="$arg"
                    p_prolix "string set to ${string}"
                elif [[ -z "$regex" ]]; then 
                    local regex="$arg"
                    p_prolix "regex set to ${regex}"
                else
                    echo "unknown argument: $arg"
                    return 1
                fi
                ;;
        esac
    done
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    if [[ "$string" =~ $regex ]]; then
        local res=true
        local found="${BASH_REMATCH[0]}"
    else
        local res=false
        local found=""
    fi 

    if [[ "$not" = "true" ]]; then
        if [[ "$res" = "true" ]]; then
            res=false
        else
            res=true
        fi
        found=""
    fi  

    if [[ "$getmatch" = "true" ]]; then
       echo "$found" 
    else
       echo "$res"
    fi
}

p_match_array() {
    p_prolix_function "p_match_array"
    local string="$1"
    local logic="$2"
    shift 2
    local regex=$@

    [[ -z "$logic" ]] && logic=OR

    p_prolix "string: $string"
    p_prolix "regArr: ${regex[@]}"
    p_prolix "logic: $logic"

    if [[ -z "$string" || ${#regex[@]} -eq 0 ]]; then
        p_prolix "var is empty"
        echo "false"
        return
    fi

    for r in ${regex[@]}; do
        p_prolix "LOOPING"
        p_prolix "regex:$r"
        if [[ "$string" =~ $r ]]; then
            if [[ "$logic" == "OR" ]]; then
                echo "true"
                return
            fi
        else
            if [[ "$logic" == "AND" ]]; then
                echo "false"
                return
            fi
        fi
    done

    if [[ "$logic" == "OR" ]]; then
        echo "false"
    else
        echo "true"
    fi
}

p_stringify_regex() {
    local regex="$1"

    if [[ -z "$regex" ]]; then
        echo "$regex"
        return
    fi

    local needReplace=('\\' '@' '~' '%' '$' '&' '^' '*' '(' ')' '[' ']' '.' '+' '?')

    for n in ${needReplace[@]}; do
        regex="${regex//"$n"/"\\$n"}"
    done

    echo "$regex"
}

p_replace_array() {

    p_prolix_function "p_replace_array" Blue
    local string="$1"
    local replace="$2"
    shift 2
    local regex=$@

    p_prolix "string: $string"
    p_prolix "replace: $replace"
    p_prolix "regArr: $regex"

    if [[ -z "$string" || ${#regex[@]} -eq 0 ]]; then
        echo "$string"
        return
    fi

    for r in ${regex[@]}; do
        string="${string//$r/$replace}"
    done

    echo "$string"
}

p_throw() {
    code=$1
    message=$2
    meta=$3

    if [[ $p_error_action == "SilentlyContinue" ]]; then return 0; fi

    echo -e "\e[31m| persist.psm1 |\e[0m"

    case $code in
        -1|"SyntaxParseFailure")
            code=-1
            echo -e "\e[31mSyntax parse failed with code ($message)\e[0m"
            ;;
        1|"ElementAlreadyAssigned")
            code=1
            echo -e "\e[31m[$message] already assigned\e[0m"
            ;;
        10|"IllegalValueAssignment")
            code=10
            echo -e "\e[31millegal character: $message :when trying to record [$meta]\e[0m"
            ;;
        20|"IllegalRecordBefore")
            code=20
            echo -e "\e[31mCannot record [$message] before [$meta] has been defined\e[0m"
            ;;
        21|"IllegalRecordAfter")
            code=21
            echo -e "\e[31mCannot record [$message] after [$meta] has been defined\e[0m"
            ;;
        22|"IllegalRecordOrder")
            code=22
            echo -e "\e[31mCannot record in the order: $message\e[0m"
            ;;
        30|"IllegalArrayRead")
            code=30
            echo -e "\e[31mIllegal attempt to index array: $message\e[0m"
            ;;
        40|"IllegalOperationSyntax")
            code=30
            echo -e "\e[31mIllegalOperationSyntax: $message\e[0m"
            ;;
    esac

    if [[ $p_error_action == "Stop" ]]; then
        if [[ $(p_not_choice) ]]; then exit; fi
    fi

    return $code
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#               P E R S I S T  F U N C T I O N S        #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#



function p_parse_syntax () {
    p_prolix_function "p_parse_syntax" Blue
    a_="$1"
    symbols=(">" "_" "=" "\+" "-" "\*" "/" "\^" "!" "~" "\?" "\.")
    aL_=${#a_}
    local cast=""
    local name=""
    local operator=""
    local parameters=""
    local index=""
    local recording=""
    for i in {0..$aL_}; do
        a=${a_:$i:1}
        p_prolix "a_[i]: $a" Yellow

        if [[ -n "$recording" ]]; then
            if [[ "$a" = " " && "$recording" != "STRING" ]]; then
                continue
            fi
            case "$recording" in
                "CAST") 
                    if [[ "$a" = "]" ]]; then
                        recording=""
                        p_prolix "recording stopped:$cast" red
                    elif [[ ! "$a" =~ "[a-z]" ]]; then
                        return p_throw IllegalValueAssignment "$a" "cast"
                    fi
                ;;
                *) echo default
                ;;
            esac
        fi
    done
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#                 M A I N   P E R S I S T               #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

function persist () {

    p_prolix_function persist White
    p_prolix "args: $#"

    a_="$(p_join $@)"
    p_prolix "joined: $a_"

    $s_=$(p_parse_syntax "$a_")
}
