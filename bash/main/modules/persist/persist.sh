#!/bin/bash

prolix=false

function p_ehe {
    echo 'administrative rights required to access host global cfg'
}

function p_prolix () {
    message=$1
    messageColor=$2
    meta=$3
    if [ "$prolix" = true ]; then
        return
    fi
    wh "    \\${message}" "${messageColor}" || echo "    \\${message}"
    if [ -z "$meta" ]; then
        metaColor="YELLOW"
        wh "    #META#${message}" "YELLOW" || echo -e "${metaColor}    #META#${message}"
    fi
}