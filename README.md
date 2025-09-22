[![infra-congruency-check](https://github.com/ajakhotia/infraCommons/actions/workflows/infra-congruency-check.yaml/badge.svg)](https://github.com/ajakhotia/infraCommons/actions/workflows/infra-congruency-check.yaml)

# infraCommons

A centralized repository of infrastructure assets shared across multiple projects. It serves as the single source of
truth for CI workflows, code quality tooling, and build utilities that teams can consistently reuse.

## Usage

- Copy required files/directories (preserve relative paths).
- Add a CI congruency check to ensure your copies remain identical to infraCommons.
- Propose improvements here so all clients benefit.

## CI: infra-congruency-check

Keeps common files in downstream projects in lockstep with infraCommons as development progresses. The workflow compares
shared files and, when updates are needed, automatically opens a low-friction merge request/PR to sync changes.

Highlights:

- Continuous alignment via scheduled and event-driven runs.
- Low-friction updates through auto-created PRs.
- Supports intentional divergence with ignore lists.
- Clear, early feedback on drift.

See it in action:

- [robotFarm](https://github.com/ajakhotia/robotFarm)
- [nioc](https://github.com/ajakhotia/nioc)

## CMake: utilities

Reusable CMake modules to standardize builds.

- exportedTargets.cmake
    - Helpers for exporting and installing CMake targets in a consistent way.
    - Encourages predictable namespace usage and proper install/export rules for libraries and headers.

- capnprotoGenerate.cmake
    - Thin helper around Cap’n Proto code generation.
    - Provides targets/macros to generate sources and integrate them into standard CMake build graphs with correct
      dependencies.

- clangFormat.cmake
    - Adds formatting targets (e.g., format, format-check).
    - Integrates clang-format with include/exclude globs for consistent code style in CI and locally.

- clangTidy.cmake
    - Adds linting targets (e.g., tidy, tidy-all).
    - Integrates clang-tidy with project targets and sensible defaults suitable for CI enforcement.

## Tools

- extractDependencies.sh
    - Extracts system package dependencies from a JSON descriptor and prints a normalized list.
    - Useful for generating install step inputs (e.g., apt install) or auditing transitive requirements.

- APT sources installer
    - Scripts to add common upstream APT sources (e.g., GNU, LLVM, vendor).
    - Ensures reproducible toolchain provisioning across CI and local environments.

- CMake installer
    - Script to install a specific CMake version in CI or developer machines.
    - Reduces environment drift; useful when system package managers lag behind required versions.
