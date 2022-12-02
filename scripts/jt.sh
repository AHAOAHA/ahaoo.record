#!/bin/bash

details=${HOME}/.config/jt.csv

function usage() {
cat << USAGE
usage: jt [OPTION] [PARAMS]
        e    jump to remote machine with ssh, default option.
        s    save remote machine details.
            -i|--ip         remote ip.
            -u|--user       remote user.
            -p|--password   remote password.
            -P|--port       remote sshd service binding port.
            -f|--focus      overwrite already exist detail.
        l    show exist detail ips.

        -h|--help   show help.
USAGE
}

function alert() {
    echo -e "\033[31m$1\033[0m"
}

function warn() {
    echo -e "\033[33m$1\033[0m"
}

function info() {
    echo -e "\033[32m$1\033[0m"
}

function s() {
    while [ $# -ne 0 ]
    do
        key=$1
        case ${key} in
            -i|--ip)
                ip=$2
                shift
                shift
                ;;
            -u|--user)
                user=$2
                shift
                shift
                ;;
            -p|--password)
                password=$2
                shift
                shift
                ;;
            -P|--port)
                port=$2
                shift
                shift
                ;;
            -f|--focus)
                focus=true
                shift
                ;;
            *)
                usage
                return 1
        esac
    done

    if [ -z "${ip}" -o -z "${port}" -o -z "${user}" -o -z "${password}" ]; then
        usage && return
    fi

    if [ ! -z "$(grep -E "^[^:]*{1}:${ip}:[^:]*{1}:[0-9]{1,5}{1}$" ${details} 2>/dev/null)" -a -z "${focus}" ]; then
        warn "ip already exist"
        return
    fi
    
    if [ $(sshpass -p ${password} ssh ${user}@${ip} -p ${port} -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null 'exit' 2>/dev/null; echo $?) -ne 0 ]; then
        alert "ssh check remote machine failed"
        return
    fi

    if [ ! -f ${details} ]; then
        mkdir -p $(dirname ${details})
    fi

    crypted=$(base64 <<< ${password})
    echo "${user}:${ip}:${crypted}:${port}" >> ${details}
    info "OK"
}

function e() {
    if [ -z "$1" ]; then
        usage
        return
    fi
    
    if [ ! -f "${details}" ]; then
        usage
        return
    fi
    detail=$(grep -E "^[^:]*{1}:[^:]*${1}{1}:[^:]*{1}:[0-9]{1,5}{1}$" ${details} 2>/dev/null)

    read user ip crypted port <<< $(echo ${detail} | awk -F ':' '{print $1,$2,$3,$4}' 2>/dev/null)
    if [ $(echo ${ip} | grep -E ".*$1$" >/dev/null 2>&1; echo $?) -eq 0 ]; then
        password=$(base64 -d <<< ${crypted})
       exec sshpass -p ${password} ssh ${user}@${ip} -p ${port} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
       # expect -c "
       #     debug 1
       #     log_user 0
       #     set timeout 60
       #     spawn ssh ${user}@${ip} -p ${port} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
       #     log_user 1
       #     expect {
       #         -re \".*(p|P)assword:\" {send \"${password}\r\";exp_continue}
       #         -re \".*#\" {}
       #         -re \".*\$\" {}
       #         eof {exit 1}
       #     }
       #     set timeout -1
       #     interact
       # "
       # exit 0
    fi

    alert "not match details. insert remote machine into ${details}"
}

function l() {
    while read line
    do
        info $(echo ${line} | awk -F ':' '{print $2}')
    done < ${details}
}

if [ $# -eq 0 ]; then
    usage
    exit 0
fi


case $1 in
    e)
        $@
        ;;
    s)
        $@
        ;;
    l)
        l
        ;;
    -h|--help)
        usage
        ;;
    *)
        e $@
esac