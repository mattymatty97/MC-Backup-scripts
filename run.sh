#!/bin/bash

##all the configs are here for now

runCMD="./start.sh"

backupCMD="./backup.sh save"

restoreCMD="./backup.sh restore"

listCMD="./backup.sh list"

setupCMD="./backup.sh setup"

whitelistFile="backup_whitelist.txt"

automaticBackupTime=2600

T_30Message="%d minutes to next Server Backup"

T_10Message=$T_30Message

T_5Message=$T_30Message

T_1Message="%d minute to next Server Backup, please stay in a safe spot until the backup finishes"



##needed to create shared tmp files to excange informations

myPID="$$"

#removing tmp files on close
function cleanup () {
    kill $(jobs -p)
    stty $oldtty
    if [[ -f /tmp/$myPID-input1.fifo ]]; then
        rm /tmp/$myPID-input1.fifo
    fi
    if [[ -f  /tmp/$myPID-game.tmp ]]; then
        rm /tmp/$myPID-game.tmp
    fi
   
    if [[ -f  /tmp/$myPID-output.fifo ]]; then
        rm /tmp/$myPID-output.fifo
    fi
    
    if [[ -f  /tmp/$myPID-restore.tmp ]]; then
        rm /tmp/$myPID-restore.tmp
    fi
}

#creating the enviroment
function setup () {
    mkfifo /tmp/$myPID-input1.fifo
    mkfifo /tmp/$myPID-output.fifo
    exec 3<>/tmp/$myPID-input1.fifo
    exec 4>&1
    exec 5<>/tmp/$myPID-output.fifo
    if [[ ! -f $whitelistFile ]]; then
        touch $whitelistFile
    fi
    if [[ ! -f ".gitignore" ]]; then
       echo "$0" >>.gitignore
       echo "$whitelistFile" >>.gitignore
       echo "$(dirname "$backupCMD")/$(basename $backupCMD)" >>.gitignore
       echo "$(dirname "$restoreCMD")/$(basename $restoreCMD)" >>.gitignore
       echo "$(dirname "$listCMD")/$(basename $listCMD)" >>.gitignore
       echo "$(dirname "$setupCMD")/$(basename $setupCMD)" >>.gitignore
    fi
    oldtty=$(stty -g)
    stty rprnt ^K
    trap cleanup EXIT
    $setupCMD
}


function print_to_screen () {
    local REPLY
    while read REPLY; do
        tput hpa 0
        tput el
        echo "$REPLY" >&4
    done
}

#utility to send messages to the server
function reponse () {
    if [[ $1 == $'\b' ]]; then
        echo ${@:2} >&5
    elif [[ $1 == $'\a' ]]; then
        echo "/tellraw @a [\"\",{\"text\":\"<\"},{\"text\":\"Server\",\"color\":\"red\"},{\"text\":\"> ${@:2}\",\"color\":\"gold\"}]" >&3
        echo ${@:2} >&5
    else
        echo "/tellraw $1 {\"text\":\"${@:2}\",\"color\":\"yellow\"}" >&3
        echo ${@:2} >&5
    fi
}

#utility to check the whitelist and run the correct scripts
function parse_command () {
    if [[ $1 == $'\b' ]] || [[ $(grep -cwF $1 $whitelistFile) -ge 1 ]]; then
        local resultArr=( "" )
        local line=""
        case $2 in
            "save")
                reponse $1 "backup started"
                echo "/save-off" >&3
                echo "/save-all" >&3
                touch /tmp/$myPID-game.tmp
                while [[ -f /tmp/$myPID-game.tmp ]]; do
                sleep 1
                done
                if [[ $# -ge 3 ]]; then
                    mapfile -t resultArr < <($backupCMD ${1/$'\b'/$(whoami)} $3)
                else
                    mapfile -t resultArr < <($backupCMD)
                fi
                echo "/save-on" >&3
                
                for line in "${resultArr[@]}"; do
                    reponse $1 $line
                done
                
            ;;
            "restore")
                echo "/stop" >&3
                
                touch /tmp/$myPID-restore.tmp
                while [[ -f /tmp/$myPID-restore.tmp ]]; do
                    sleep 1
                done
                
                reponse $'\b' "restore started"
                if [[ $# -ge 3 ]]; then
                    mapfile -t resultArr < <($restoreCMD $3)
                else
                    mapfile -t resultArr < <($restoreCMD)
                fi
                
                for line in "${resultArr[@]}"; do
                    reponse $'\b' $line
                done
                
                run_Server &
            ;;
            "list")
                reponse $1 "listing"
                if [[ $# -ge 3 ]]; then
                    mapfile -t resultArr < <($listCMD ${@:3})
                else
                    mapfile -t resultArr < <($listCMD)
                fi
                
                for line in "${resultArr[@]}"; do
                    reponse $1 $line
                done
            ;;
            *)
                reponse $1 "unknown command"
            ;;
        esac
    fi 
}


#utility to mirror the server input system + pasre backup command
function read_terminal (){
    local pat='/?backup (.*)'
    local line=""
    while read -e line; do
        if [[ "$line" =~ $pat ]]; then
            parse_command $'\b' ${BASH_REMATCH[1]} &
        else        
            echo "$line" >&3
        fi 
    done
}



#utility to parse the output from the server
function read_server () {
    local pat='\[.*\] *\[.*\]: *<(.*)> *;backup(.*)'
    local pat2='\[.*\] *\[.*\]: Saved the game.*'
    local line=""
    while read line; do
        if [[ "$line" =~ $pat ]]; then
            parse_command ${BASH_REMATCH[1]} ${BASH_REMATCH[2]} &
        elif [[ "$line" =~ $pat2 ]]; then
            if [[ -f /tmp/$myPID-game.tmp ]];then
                rm /tmp/$myPID-game.tmp
            fi
        fi
        echo $line >&5
    done
        
}

function timer () {
    local _minus30=$(expr $automaticBackupTime - 1800)
    local _minus10=$(expr $automaticBackupTime - 600)
    local _minus5=$(expr $automaticBackupTime - 300)
    local _minus1=$(expr $automaticBackupTime - 60)
    if (( ${_minus30} <= 0 )) ;then
        _minus30=0
        if (( ${_minus10} <= 0 )) ;then
            _minus10=0
            if (( ${_minus5} <= 0 )) ;then
                _minus5=0
                if (( ${_minus1} <= 0 )) ;then
                    _minus1=0
                else
                    automaticBackupTime=60
                fi
            else
                automaticBackupTime=60
                _minus1=240
            fi
        else
            automaticBackupTime=60
            _minus1=240
            _minus5=300
        fi
    else
        automaticBackupTime=60
        _minus1=240
        _minus5=300
        _minus10=1200
    fi
        
    while true; do
        if (( ${_minus30} > 0 )); then
            sleep ${_minus30}
            printf -v text "$T_30Message" 30
            reponse $'\a' $text
        fi
        if (( ${_minus10} > 0 )); then
            sleep ${_minus10}
            printf -v text "$T_10Message" 10
            reponse $'\a' $text
        fi
        if (( ${_minus5} > 0 )); then
            sleep ${_minus5}
            printf -v text "$T_5Message" 5
            reponse $'\a' $text
        fi
        if (( ${_minus1} > 0 )); then
            sleep ${_minus1}
            printf -v text "$T_1Message" 1
            reponse $'\a' $text
        fi
        sleep $automaticBackupTime
        reponse $'\a' "Saving the server"
        parse_command $'\b' "save"
        reponse $'\a' "Backup done"
    done
}


#run the server

function run_Server () {
    $runCMD <&3 | read_server
    if [[ -f /tmp/$myPID-restore.tmp ]]; then
        rm /tmp/$myPID-restore.tmp
    else
        kill -1 $myPID >/dev/null 2>&1
    fi
}


#setup the enviroment

setup


#if the backup timer is a valid number start the subprocess
if [[ $automaticBackupTime -gt 60 ]]; then
    timer &
fi

print_to_screen <&5 &

#run the server, split it from the terminal and send to background
run_Server &


#start mirroring the console
read_terminal


