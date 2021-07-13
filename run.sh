#!/bin/sh

MACOSX=0
LINUX=0

MACHINE_IP="127.0.0.1"
SSH_PORT=2522

if [ -z "$INPUT_CPUS" ]; then
  INPUT_CPUS=1
fi
if [ -z "$INPUT_MEMORY" ]; then
  INPUT_MEMORY=4096
fi
if [ -z "$RUNNING_AS_ACTION" ]; then
  RUNNING_AS_ACTION=0
fi

CURRENT_DIR_BASENAME="$(pwd | awk -F/ '{print $NF}')"

case "$(uname -s)" in

   Darwin)
     MACOSX=1
     ;;

   Linux)
     LINUX=1
     ;;
esac

set -ex

prepare_dependencies() {
  if [ -z "$(command -v sshpass)" ]; then
    if [ "$MACOSX" -eq 1 ]; then
      brew install hudochenkov/sshpass/sshpass &
    else
      echo "You must install sshpass before run this script." >&2
      exit 1
    fi
  fi
}

wait_for_dependencies() {
  SSHPASS="$(command -v sshpass)"
  if [ -z "$SSHPASS" ]; then
    sleep 2
    if [ "$1" -gt "300" ]; then
      printf "Error installing 'sshpass' dependency after 10 minutes." >&2
      printf " Timeout reached.\n" >&2
      exit 1
    else
      wait_for_dependencies "$(( $1 + 1 ))"
    fi
  fi
}

clean_ova_parts() {
  rm -f sol-11_4-part*.zip
}

extract_ova_parts() {
  cat sol-11_4-part* > sol-11_4.zip
  unzip sol-11_4.zip
  rm -f sol-11_4.zip
  clean_ova_parts
}

download_ova_parts() {
  clean_ova_parts
  curl -Z \
    --parallel-max 16 \
    https://raw.githubusercontent.com/mondeja/solaris-vm-action-ova/master/ova/sol-11_4-part[00-78].zip \
    -o 'sol-11_4-part#1.zip'
}

prepare_ova() {
  if [ ! -f "sol-11_4.ova" ]; then
    download_ova_parts
    extract_ova_parts
  fi
}

prepare_ssh_config() {
#  if [ "$RUNNING_AS_ACTION" -eq 1 ]; then
#    DEVICE_NAME="$(networksetup -listallhardwareports | grep "Device:" | cut -d' ' -f2)"
#  else
#    DEVICE_NAME="wlp3s0"
#  fi
#  vboxmanage modifyvm sol-11_4 \
#    --nic1 bridged \
#    --cableconnected1 on \
#    --bridgeadapter1 $DEVICE_NAME

}

import_vm() {
  vboxmanage import sol-11_4.ova
}

modify_vm() {
  if [ "$INPUT_CPUS" -ne 1 ]; then
    vboxmanage modifyvm sol-11_4 --cpus "$INPUT_CPUS"
  fi
  if [ "$INPUT_MEMORY" -ne 4096 ]; then
    vboxmanage modifyvm sol-11_4 --mem "$INPUT_MEMORY"
  fi
}

run_vm() {
  vboxmanage startvm sol-11_4 --type headless
}

get_machine_ip() {
  vboxmanage guestproperty get sol-11_4 "/VirtualBox/GuestInfo/Net/0/V4/IP" \
  | cut -d' ' -f2
}

wait_for_ssh_enter() {
  #MACHINE_IP="$(get_machine_ip)"
  if ! nc --wait 5 127.0.0.1 $SSH_PORT < /dev/null &> /dev/null; then
    sleep 10
    if [ "$1" -gt "60" ]; then
      printf "Error starting the Solaris VM after 10 minutes." >&2
      printf " Timeout reached.\n" >&2
      exit 1
    else
      wait_for_ssh_enter "$(( $1 + 1 ))"
    fi
  fi

#  if [ "$CONNECT" != "OK" ]; then
#    MACHINE_IP="$(nmap -p 22 --open -sV 10.79.15.0/24 | grep "scan report for" | cut -d' ' -f5)"
#    if [ -n "$MACHINE_IP" ]; then
#      CONNECT="$(sshpass -p solaris ssh \
#        -p 22 \
#        -o StrictHostKeyChecking=no \
#        -o ConnectTimeout=10 \
#        solaris@$MACHINE_IP "printf 'OK'" || true)"
#      if [ "$CONNECT" != "OK" ]; then
#        if [ "$1" -gt "60" ]; then
#          printf "Error starting the Solaris VM after 10 minutes." >&2
#          printf " Timeout reached.\n" >&2
#          exit 1
#        else
#          wait_for_ssh_enter "$(( $1 + 1 ))"
#        fi
#      fi
#    else
#      if [ "$1" -gt "60" ]; then
#        printf "Error starting the Solaris VM after 10 minutes." >&2
#        printf " Timeout reached.\n" >&2
#        exit 1
#      else
#        wait_for_ssh_enter "$(( $1 + 1 ))"
#      fi
#    fi
#  fi
}

sync_files() {
  sshpass -p "solaris" \
  rsync \
    --exclude _actions/mondeja/solaris-vm \
    --exclude sol-11_4.ova \
    --exclude sol-11_4-backup.zip \
    -ae "ssh -p $SSH_PORT -o StrictHostKeyChecking=accept-new" \
    $PWD \
    solaris@127.0.0.1:/export/home/solaris && _sync=1 || _sync=0
  if [ "$_sync" -eq 0 ]; then
    sleep 10
    if [ "$1" -gt "60" ]; then
      printf "Error starting the Solaris VM after 10 minutes." >&2
      printf " Timeout reached.\n" >&2
      exit 1
    else
      sync_files "$(( $1 + 1 ))"
    fi
  fi;
}

run_commands() {
  sshpass -p solaris ssh \
    -p $SSH_PORT \
    -o StrictHostKeyChecking=accept-new \
    solaris@127.0.0.1 << EOF
set -e
cd /export/home/solaris/$CURRENT_DIR_BASENAME
$INPUT_COMMANDS
EOF
}

main() {
  prepare_dependencies
  prepare_ova
  import_vm
  prepare_ssh_config
  modify_vm
  run_vm
  wait_for_dependencies 1
  sync_files 1
  run_commands
}

main
