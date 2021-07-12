#!/bin/sh

MACHINE_IP=""

if [ -z "$INPUT_CPUS" ]; then
  INPUT_CPUS=1
fi
if [ -z "$INPUT_MEMORY" ]; then
  INPUT_MEMORY=4096
fi

CURRENT_DIR_BASENAME="$(pwd | awk -F/ '{print $NF}')"

set -ex

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

wait_for_dhcp_ip() {
  MACHINE_IP="$(get_machine_ip)"
  if [ "$(echo $MACHINE_IP | cut -d'.' -f1)" = "10" ]; then
    sleep 3
    if [ "$1" -gt "200" ]; then
      printf "Error starting the Solaris VM after 10 minutes." >&2
      printf " Timeout reached.\n" >&2
      exit 1
    else
      wait_for_dhcp_ip "$(( $1 + 1 ))"
    fi
  fi
}

sync_files() {
  sshpass -p "solaris" \
  rsync \
    --exclude _actions/mondeja/solaris-vm \
    --exclude sol-11_4.ova \
    -ae "ssh -p 22 -o StrictHostKeyChecking=no" \
    $PWD \
    solaris@$MACHINE_IP:/export/home/solaris
}

run_commands() {
  sshpass -p solaris ssh \
    -o StrictHostKeyChecking=no solaris@$MACHINE_IP << EOF
set -e
cd /export/home/solaris/$CURRENT_DIR_BASENAME
$INPUT_COMMANDS
EOF
}

main() {
  prepare_ova
  import_vm
  modify_vm
  run_vm
  wait_for_dhcp_ip 1
  sync_files
  run_commands
}

main
