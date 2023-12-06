#!/bash/bin

[[ -z "_MODNAME_module_location" ]] && _MODNAME_module_location=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

prolix=false
_debug_=false

--write_host () {
    $message=$1
    $color=$2
    IFS=":" read -ra colors <<< "$message"
}

__debug () {
    [[ "$debug" = "false" ]] && return

    message=$1
    color=${2^^}
    color=${color:-"DARKYELLOW"}

}
