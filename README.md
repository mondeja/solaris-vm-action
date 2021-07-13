# solaris-vm-action

[![Tests][tests-image]][tests-link]

Run your workflow in a SunOS 11.4 virtual machine using VirtualBox.

## Usage

```yaml
name: Run Solaris tests
on:
  push:
    branches:
      - master
    tags:
      - v*
  pull_request:
  workflow_dispatch:

jobs:
  sunos-tests:
    name: Solaris (SunOS) tests
    runs-on: macos-latest
    steps:
      - uses: mondeja/solaris-vm-action@v1
        with:
          run: |
            sh build.sh
            sh test.sh
```

## Arguments

- ``run`` (*required*): Commands to run, in multiple lines.
- ``prepare``: Optional preparation commands run in the Solaris VM before main
 execution.
- ``cpus`` (1): Number of CPUs for the virtual machine.
- ``memory`` (4096): RAM memory size for the virtual machine.


[tests-image]: https://img.shields.io/github/workflow/status/mondeja/solaris-vm-action/CI/v1?label=tests&logo=github
[tests-link]: https://github.com/mondeja/solaris-vm-action/actions/workflows/ci.yml
