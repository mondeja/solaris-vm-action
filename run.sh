#!/bin/sh

OVA_REPO_URL="https://raw.githubusercontent.com/mondeja/solaris-vm-action-ova/master"

VBOX_GA_URL="https://download.virtualbox.org/virtualbox/6.1.14/Oracle_VM_VirtualBox_Extension_Pack-6.1.14.vbox-extpack"

OVA_URL="$OVA_REPO_URL/ova/sol-11_4-part[00-75].zip"
OVA_NAME="sol-11_4-vbox"

SSH_HOST="solaris"
SSH_PORT=2223

if [ -z "$INPUT_CPUS" ]; then
  INPUT_CPUS=1
fi
if [ -z "$INPUT_MEMORY" ]; then
  INPUT_MEMORY=4096
fi

CURRENT_DIR_BASENAME="$(pwd | awk -F/ '{print $NF}')"

set -ex

get_vbox_vms_folder() {
  vboxmanage list systemproperties \
  | grep "Default machine folder:" \
  | cut -f2 -d":" \
  | sed 's/^ *//g'
}

install_vbox_guest_additions() {
  wget $VBOX_GA_URL
  vboxmanage extpack install --replace Oracle_VM_VirtualBox_Extension_Pack-6.1.14.vbox-extpack
  rm -f Oracle_VM_VirtualBox_Extension_Pack-6.1.14.vbox-extpack
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
    --parallel-max 32 \
    $OVA_URL \
    -o 'sol-11_4-part#1.zip'
}

prepare_ova() {
  if [ ! -f "sol-11_4.ova" ]; then
    download_ova_parts
    extract_ova_parts
  fi
}

prepare_ssh_config() {
  if [ ! -f "$HOME/.ssh/config" ]; then
    touch "$HOME/.ssh/config"
  fi

  echo "Host solaris" >> "$HOME/.ssh/config"
  echo " User root" >> "$HOME/.ssh/config"
  echo " HostName localhost" >> "$HOME/.ssh/config"
  echo " Port $SSH_PORT" >> "$HOME/.ssh/config"
  echo "StrictHostKeyChecking=accept-new"  >> "$HOME/.ssh/config"
  echo "SendEnv   CI  GITHUB_* " >> "$HOME/.ssh/config"

  wget https://raw.githubusercontent.com/mondeja/solaris-vm-action-ova/master/id_rsa.pub \
    -o /tmp/id_rsa.pub
  cat /tmp/id_rsa.pub > "$HOME/.ssh/authorized_keys"
  rm -f /tmp/id_rsa.pub id_rsa.pub
  chmod 700 "$HOME/.ssh"
}

import_vm() {
  _cpus_argument=""
  if [ "$INPUT_CPUS" -ne 1 ]; then
    _cpus_argument="--cpus $INPUT_CPUS"
  fi

  _memory_argument=""
  if [ "$INPUT_MEMORY" -ne 4096 ]; then
    _memory_argument="--mem $INPUT_MEMORY"
  fi

  vboxmanage import sol-11_4.ova  $_cpus_argument $_memory_argument
}

run_vm() {
  vboxmanage startvm $OVA_NAME --type headless
}

sync_files() {
  rsync \
    -avuzrtopgh \
    --exclude _actions/mondeja/solaris-vm \
    --exclude sol-11_4.ova \
    --exclude sol-11_4-backup.zip \
    $PWD \
    $SSH_HOST:/export/home/solaris && _sync=1 || _sync=0
  if [ "$_sync" -eq 0 ]; then
    sleep 1
    if [ "$1" -gt "60" ]; then
      printf "Error starting the Solaris VM after 10 minutes." >&2
      printf " Timeout reached.\n" >&2
      exit 1
    else
      sync_files "$(( $1 + 1 ))"
    fi
  fi;
}

run_prepare() {
  ssh -t $SSH_HOST << EOF
cd /export/home/solaris/$CURRENT_DIR_BASENAME
$PREPARE_COMMANDS
EOF
}

run_commands() {
  ssh -t $SSH_HOST << EOF
cd /export/home/solaris/$CURRENT_DIR_BASENAME
$INPUT_COMMANDS
EOF
}

main() {
  install_vbox_guest_additions
  prepare_ova
  import_vm
  prepare_ssh_config
  run_vm
  sync_files 1
  if [ -n "$INPUT_PREPARE" ]; then
    run_prepare
  fi
  run_commands
}

main
