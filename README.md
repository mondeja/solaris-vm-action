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
    runs-on: macos-10.15
    steps:
      - uses: actions/checkout@v2
      - uses: actions/cache@v2
        with:
          key: sol-11_4
          path: |
            sol-11_4.ova
      - uses: mondeja/solaris-vm-action@v1
        with:
          run: |
            sh build.sh
            sh test.sh
```

> The optional [`actions/cache`][actions-cache-github-link] step saves ~3 min
 for subsequents runs of the action under the same branch, but takes 3.5GB of
 your cache storage when each repository has a limit of 5GB (see
 [Cache Limits][cache-limits-link]).

## Arguments

- ``run`` (*required*): Commands to run, in multiple lines.
- ``prepare``: Optional preparation commands to run in the Solaris VM before main
 execution.
- ``cpus`` (1): Number of CPUs for the virtual machine.
- ``memory`` (4096): RAM memory size for the virtual machine.


[tests-image]: https://img.shields.io/github/workflow/status/mondeja/solaris-vm-action/CI/v1?label=tests&logo=github
[tests-link]: https://github.com/mondeja/solaris-vm-action/actions/workflows/ci.yml
[actions-cache-github-link]: https://github.com/actions/cache
[cache-limits-link]: https://github.com/actions/cache#cache-limits
