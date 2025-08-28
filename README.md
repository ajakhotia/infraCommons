[![infra-congruency-check](https://github.com/ajakhotia/infraCommons/actions/workflows/infra-congruency-check.yaml/badge.svg)](https://github.com/ajakhotia/infraCommons/actions/workflows/infra-congruency-check.yaml)

# infraCommons

A centralized repository of common files shared across multiple projects. This repository serves as the single 
source of truth for shared infrastructure components.

## Overview

infraCommons contains essential configuration and utility files that are used by various client projects.
This repository is expected to be language agnostic

## Usage

Client projects can copy required files from this repository for their specific needs. To maintain consistency,
each client project should:

1. Copy only the necessary files they need
2. Keep the relative path structure intact
3. Implement required CI tests to ensure consistency

## Consistency Validation

Each client project must implement continuous integration tests that:
- Compare their copy of shared files against this repository's main branch
- Verify that any files present in both locations are exactly identical
- Use paths relative to the root for comparison

The congruency test implementation is provided in `ci/congruency_test.py`. This script can be used to:
- Compare files between template and client directories
- Ignore specified files during comparison
- Show detailed diffs for any inconsistencies found

## Tools
### Clang Tidy
Clang Tidy configs are generated using the following command:
```shell
clang-tidy-19 \
  -checks='*,-clang-analyzer-alpha.*,-google-*,-llvm-*,-llvmlibc-*,-abseil-*,-fuchsia-*,-zircon-*,-objc-*,-android-*' \
  -warnings-as-errors='bugprone-*,cert-*,clang-analyzer-*,cppcoreguidelines-*,modernize-*,performance-*,portability-*,readability-*,security-*' \
  --dump-config > tools/clang-tidy-19
```

### Clang Format
Clang Format configs are generated using the following command:
```shell
clang-format-19 -style='{BasedOnStyle: GNU}' -dump-config > tools/clang-format-19
```

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
