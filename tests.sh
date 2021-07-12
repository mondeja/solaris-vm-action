#!/bin/sh

checkDependencies() {
  if [ "$(command -v "shunit2")" = "" ]; then
    printf "You need to install shunit2 or add it to PATH to run tests.\n" >&2
    exit 1
  fi;
}

testUname() {
  assertEquals "SunOS" "$(uname -a)"
  assertEquals "Solaris" "$(uname -o)"
}

main() {
  checkDependencies
  . shunit2
}

main
