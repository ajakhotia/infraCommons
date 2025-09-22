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
shared files and, when updates are needed, automatically opens a low-friction pull request (PR) to sync changes.

Highlights:

- Continuous alignment via scheduled and event-driven runs.
- Low-friction updates through auto-created PRs.
- Supports intentional divergence with ignore lists.
- Clear, early feedback on drift.

See it in action:

- [robotFarm](https://github.com/ajakhotia/robotFarm)
- [nioc](https://github.com/ajakhotia/nioc)

## Reusable GitHub Actions

This repository exposes composite actions for reuse across projects. Reference them as:
- uses: ajakhotia/infraCommons/.github/actions/<action-name>@main

Actions:

- cmake-find-package
  - Purpose: Run standardized CMake package discovery in CI to fail fast on missing/misconfigured dependencies.
  - Example:
    ```yaml
    - name: find-library
      uses: ajakhotia/infraCommons/.github/actions/cmake-find-package@main
      with:
        library-name: <library-name>
        prefix-path: <cmake-prefix-path>
        image-name: <image-url>
        password: ${{ secrets.GITHUB_TOKEN }}
    ```

- docker-typical-build-push
  - Purpose: Build and push Docker images with common ergonomics (tagging, multi-arch, caching).
- Example:
  ```yaml
    - name: docker-build-and-push-stage
      uses: ajakhotia/infraCommons/.github/actions/docker-typical-build-push@main
      with:
        dockerfile: <path-to-dockerfile>
        password: ${{ secrets.GITHUB_TOKEN }}
        target-stage: <target-docker-stage>
        target-stage-id: <id-of-target-stage>
        upstream-stage-id: <id-of-upstream-stage-that-is-build-before-this> # can be empty.
        cache-type: registry # can be gha.
        build-name: <build-name>
        build-args: |
          FOO1=BAR1
          FOO2=BAR2
  ```

- normalize
  - Purpose: Normalize repository content (e.g., line endings/permissions) to keep diffs clean.
  - Example:
    ```yaml
      - name: normalizer-name
        id: normalized-name-id
        uses: ajakhotia/infraCommons/.github/actions/normalize@main
        with:
          string: ${{ inputs.target-stage-id }}
    ```

Notes:
- Pin to a version tag (e.g., @v1) for stability in consumers.
- Check each action’s action.yaml for supported inputs/outputs.
- See a real-world usage `docker-typical-build-push` and `cmake-find-package` in `robotFarm`:
  - https://github.com/ajakhotia/robotFarm/blob/main/.github/workflows/docker-image.yaml
- See a real-world usage `normalize` in .github/actions/docker-typical-build-push/action.yaml

## CMake helpers

Reusable CMake modules to standardize builds.

- exportedTargets.cmake — [cmake/utilities/exportedTargets.cmake](cmake/utilities/exportedTargets.cmake)
    - Helpers for exporting and installing CMake targets in a consistent way.
    - Encourages predictable namespace usage and proper install/export rules for libraries and headers.
    - Example:
      ```cmake
      include(cmake/utilities/exportedTargets.cmake)
      
      find_package(Boost CONFIG REQUIRED COMPONENTS headers)

      add_exported_library(
          TARGET
              exampleLibrary
          TYPE
              INTERFACE
          NAMESPACE
              ExampleNamespace::
          EXPORT
              ExampleTargetSet
          SOURCES
              ""
          HEADERS
              INTERFACE include/example/core/foo.hpp
              INTERFACE include/example/core/bar.hpp
              INTERFACE include/example/core/baz.hpp
          INCLUDE_DIRECTORIES
              ${CMAKE_CURRENT_SOURCE_DIR}/include
          LINK_LIBRARIES
              INTERFACE Boost::headers
          COMPILE_FEATURES
              INTERFACE cxx_std_20
          COMPILE_OPTIONS
              ""
          COMPILE_DEFINITIONS
              ""
      )
      ```
    - See it used in another project: [nioc/modules/messages/CMakeLists.txt](https://github.com/ajakhotia/nioc/blob/main/modules/messages/CMakeLists.txt)

- capnprotoGenerate.cmake — [cmake/utilities/capnprotoGenerate.cmake](cmake/utilities/capnprotoGenerate.cmake)
    - Thin helper around Cap’n Proto code generation.
    - Provides targets/macros to generate sources and integrate them into standard CMake build graphs with correct
      dependencies.
    - Example:
      ```cmake
      include(cmake/utilities/capnprotoGenerate.cmake)
      
      capnproto_generate_library(
          TARGET
              exampleMessagesIdl
          NAMESPACE
              ExampleNamespace::
          EXPORT
              ExampleTargetSet
          SCHEMA_FILES
              include/example/messages/idl/message_a.capnp
              include/example/messages/idl/message_b.capnp
          COMPILE_FEATURES
              PUBLIC cxx_std_20
          COMPILE_OPTIONS
              PRIVATE $<$<CXX_COMPILER_ID:Clang>:-Wall -Wextra -pedantic -Werror -Wno-unknown-pragmas>
              PRIVATE $<$<CXX_COMPILER_ID:GNU>:-Wall -Wextra -pedantic -Werror -Wno-unknown-pragmas>
              PRIVATE $<$<CXX_COMPILER_ID:MSVC>:/W4 /WX>
          COMPILE_DEFINITIONS
              ""
      )
      ```
    - See it used in another project: [nioc/modules/messages/CMakeLists.txt](https://github.com/ajakhotia/nioc/blob/main/modules/messages/CMakeLists.txt)

- clangFormat.cmake — [cmake/utilities/clangFormat.cmake](cmake/utilities/clangFormat.cmake)
    - Adds a formatting targets to your CMake project. Building the target runs clang-format on all source files.
    - Include the following in your root CMakeLists.txt:
      ```cmake
      include(cmake/utilities/clangFormat.cmake)
      add_clang_format(TARGET exampleClangFormat VERSION 19)
      ```

- clangTidy.cmake — [cmake/utilities/clangTidy.cmake](cmake/utilities/clangTidy.cmake)
    - Sets up the project to use clang-tidy for static analysis.
    - Usage:
        - Root CMakeLists.txt:
          ```cmake
          include(cmake/utilities/clangTidy.cmake)
          add_clang_tidy(VERSION 19)
          ```
        - Enable clang-tidy check for a specific target using:
          ```cmake
          if(CLANG_TIDY)
              set_target_properties(exampleLibrary PROPERTIES CXX_CLANG_TIDY ${CLANG_TIDY})
          endif() 
          ```

## Tools

- extractDependencies.sh — [tools/extractDependencies.sh](tools/extractDependencies.sh)
    - Extracts system package dependencies from a JSON descriptor and prints a normalized list.
    - Useful for generating install step inputs (e.g., apt install) or auditing transitive requirements.
    - Example `systemDependencies.json`:
      ```json
      {
        "supportedOS": [
          "ubuntu:22.04",
          "ubuntu:24.04"
        ],
        "groupTags": [
          "all",
          "skip"
        ],
        "groups": [
          {
            "group": "Basics",
            "ubuntu:22.04": "ca-certificates curl wget",
            "ubuntu:24.04": "ca-certificates curl wget",
            "tag": "all"
          },
          {
            "group": "Compilers",
            "ubuntu:22.04": "clang-19 gcc-13 g++-13 gfortran-13 libomp-19-dev",
            "ubuntu:24.04": "clang-19 gcc-14 g++-14 gfortran-14 libomp-19-dev",
            "tag": "all"
          }
        ]
      }
      ```
        - Usage:
          ```shell
          sh tools/extractDependencies.sh Compilers systemDependencies.json 
          ```

- APT repositories for GNU/Clang/NVIDIA toolchains
    - Scripts to add common upstream APT sources for toolchains:
        - GNU (GCC) toolchain repositories — [tools/apt/addGNUSources.sh](tools/apt/addGNUSources.sh)
        - LLVM/Clang repositories — [tools/apt/addLLVMSources.sh](tools/apt/addLLVMSources.sh)
        - NVIDIA CUDA/NVML toolchain repositories — [tools/apt/addNvidiaSources.sh](tools/apt/addNvidiaSources.sh)
    - Ensures reproducible compiler/toolchain provisioning across CI and local environments.

- CMake installer — [tools/installCMake.sh](tools/installCMake.sh)
    - Script to install a specific CMake version in CI or developer machines.
    - Reduces environment drift; useful when system package managers lag behind required versions.
