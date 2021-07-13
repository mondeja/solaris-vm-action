#!/bin/sh

set -ex

main() {
  exitcode=0
  if [ "$(uname -a)" != "SunOS" ]; then
    exitcode=1
  fi
  if [ "$(uname -o)" != "Solaris" ]; then
    exitcode=1
  fi
  exit $exitcode
}

main
