#!/bin/bash

function _doHelp () {
    echo -e "Help menu of $(basename $0)"
    echo -e "Usage:"
    echo -e " - save (author) (comment)"
    echo -e "\tsave the current state"
    echo -e "\tif (author) is unspecified uses current shell user"
    echo -e "\tif (comment) is unspecified uses current date string"
    echo
    echo -e " - restore (commitID)"
    echo -e "\tresotores the files to the specified commit"
    echo -e "\tif no (commitID) is specified restores latest commit"
    echo
    echo -e " - list (arguments)"
    echo -e "\tshows a list of available commits"
    echo -e "\tif no (arguments) are specified shows only last 24h"
    echo -e "\t(arguments) are the \'git log\' arguments"
    echo
    echo -e "anything else will print this help"
}

function _setup () {
    cd $( dirname $0 )
    
    exec 3>&1
    exec 4>&2
    exec 1>/dev/null
    exec 2>/dev/null
    

    if [[ $(which git) == "" ]]; then
        echo "Error: Missing git, please install" >&4
        exit -1
    fi

    git branch
    if [ "$?" -ne 0 ]; then 
        git init
        git add .
        git commit -m "first commit ( initializing the bakcup system )" --author="$(whoami) <$(whoami)>"
    fi
    
}

function _doSave () {
    git add .
    git commit --allow-empty -m "${@:2}" --author="$1 <$(whoami)>"
    
    
    echo "backup completed" >&3
    echo "current commit: $(git rev-parse --short HEAD)" >&3
}

function _doRestore () {
    #save actual state in a separate branch
    git branch "rollback_$(date +"$dateFormat")" 
   
    #reset to the requested commit
    git reset --hard ${1:-"HEAD~1"}
    
    echo "Restore completed" >&3
    echo "current commit: $(git rev-parse --short HEAD)" >&3
}

function _doList () {
    git log --pretty=format:$'%h\t %cr\t: %s' $@ >&3
}

dateFormat="%F_%H-%M"

_setup

case "$1" in
    save)
    if [[ "$#" -ge 2 ]]; then
        if [[ "$#" -ge 3 ]];then
            _doSave ${@:2}
        else
            _doSave $2 $(date +"$dateFormat")
        fi
    else
        _doSave "$(whoami)" $(date +"$dateFormat")
    fi
    ;;
    restore)
    if [[ "$#" -ge 2 ]]; then
        _doRestore ${@:2}
    else
        _doRestore
    fi
    ;;
    list)
    if [[ "$#" -ge 2 ]]; then
        _doList ${@:2}
    else
        _doList "--since=1.day"
    fi
    ;;
    *)
        _doHelp >&3
    ;;
esac
