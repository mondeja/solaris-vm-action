#!/bin/sh

OVA_REPO_URL="https://raw.githubusercontent.com/mondeja/solaris-vm-action-ova/master"

OVA_URL="$OVA_REPO_URL/ova/sol-11_4-part[00-75].zip"
OVA_NAME=sol-11_4-vbox

ID_RSA_URL="$OVA_REPO_URL/id_rsa.pub"

SSH_HOST=solaris
SSH_PORT=2223

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

  printf "Host solaris\n" >> "$HOME/.ssh/config"
  printf " User root\n" >> "$HOME/.ssh/config"
  printf " HostName localhost\n" >> "$HOME/.ssh/config"
  printf " Port $SSH_PORT\n" >> "$HOME/.ssh/config"
  printf "StrictHostKeyChecking=accept-new\n" >> "$HOME/.ssh/config"
  printf "SendEnv   CI  GITHUB_* \n" >> "$HOME/.ssh/config"

  wget $ID_RSA_URL -o /tmp/id_rsa.pub
  cat /tmp/id_rsa.pub > "$HOME/.ssh/authorized_keys"
  rm -f /tmp/id_rsa.pub id_rsa.pub
  chmod 700 "$HOME/.ssh"
}

import_vm() {
  vboxmanage import sol-11_4.ova
}

modify_vm() {
  if [ "$INPUT_CPUS" -ne 1 ]; then
    vboxmanage modifyvm $OVA_NAME --cpus $INPUT_CPUS
  fi

  if [ "$INPUT_MEMORY" -ne 4096 ]; then
    vboxmanage modifyvm $OVA_NAME --memory $INPUT_MEMORY
  fi
}

run_vm() {
  vboxmanage startvm $OVA_NAME --type headless
}

copy_files_to_vm() {
  rsync \
    -avuzrtopgh \
    --exclude sol-11_4.ova \
    --exclude sol-11_4-backup.zip \
    --exclude sol-11_4.zip \
    --exclude _actions/ \
    --exclude _PipelineMapping \
    --exclude _temp \
    $PWD \
    $SSH_HOST:/export/home/solaris && _sync=1 || _sync=0
  if [ "$_sync" -eq 0 ]; then
    sleep 2
    if [ "$1" -gt "80" ]; then
      printf "Error starting the Solaris VM after 80 attempts." >&2
      printf " Timeout reached.\n" >&2
      exit 1
    else
      copy_files_to_vm "$(( $1 + 1 ))"
    fi
  fi;
}

copy_files_from_vm() {
  rsync -avuzrtopgh \
    "$SSH_HOST:/export/home/solaris/$CURRENT_DIR_BASENAME/*" \
    $PWD
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
  prepare_ova
  import_vm
  prepare_ssh_config
  modify_vm
  run_vm
  copy_files_to_vm 1
  if [ -n "$INPUT_PREPARE" ]; then
    run_prepare
  fi
  run_commands
  copy_files_from_vm
}

main
