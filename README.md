# 🧰 infraCommons

A centralized repository of infrastructure assets shared across multiple projects. It is the single
source of truth for CI workflows, code-quality tooling, and build utilities that teams can reuse
consistently.

## ⚙️ Usage

infraCommons is consumed as a **git submodule**. Add it to your project once, then use standard
submodule commands to pull in improvements over time.

```bash
git submodule add https://github.com/ajakhotia/infraCommons.git external/infraCommons
git submodule update --init
```

- Reference files and CMake helpers directly from the submodule path (e.g.
  `external/infraCommons/cmake/utilities/...`).
- Reusable GitHub composite actions are referenced by their `@main` ref (see below) — no copying
  needed.
- Propose improvements here so all consumers benefit.
- See [robotFarm](https://github.com/ajakhotia/robotFarm)
  and [nioc](https://github.com/ajakhotia/nioc) for real-world examples.

## 🏗️ CMake helpers

Reusable CMake modules to standardize builds.

### 📦 exportedTargets.cmake — [cmake/utilities/exportedTargets.cmake](cmake/utilities/exportedTargets.cmake)

- Helpers for exporting and installing CMake targets in a consistent way.
- Encourages predictable namespace usage and proper install/export rules for libraries and headers.
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
- See it used in another
  project: [nioc/modules/messages/CMakeLists.txt](https://github.com/ajakhotia/nioc/blob/main/modules/messages/CMakeLists.txt)

### 🧬 capnprotoGenerate.cmake — [cmake/utilities/capnprotoGenerate.cmake](cmake/utilities/capnprotoGenerate.cmake)

- Thin wrapper around Cap’n Proto code generation.
- Generates sources from `.capnp` schemas and wires them into the CMake build graph with the
  correct dependencies.
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
- See it used in another
  project: [nioc/modules/messages/CMakeLists.txt](https://github.com/ajakhotia/nioc/blob/main/modules/messages/CMakeLists.txt)

### ✅ requireArguments.cmake — [cmake/utilities/requireArguments.cmake](cmake/utilities/requireArguments.cmake)

- Validates required arguments parsed by `cmake_parse_arguments` inside CMake functions.
- Emits a `FATAL_ERROR` (attributed to the calling function) listing any missing or empty arguments.
  ```cmake
  include(cmake/utilities/requireArguments.cmake)

  function(my_function)
      cmake_parse_arguments("MF_PARAM" "" "TARGET;VERSION" "" ${ARGN})
      require_arguments(PREFIX MF_PARAM ARGUMENTS TARGET VERSION)
      # ... safe to use ${MF_PARAM_TARGET} and ${MF_PARAM_VERSION} here ...
  endfunction()
  ```

### 🎨 clangFormat.cmake — [cmake/utilities/clangFormat.cmake](cmake/utilities/clangFormat.cmake)

Adds a custom target to your CMake project. Building the target runs clang-format over all source
files. In your root `CMakeLists.txt`:

```cmake
include(cmake/utilities/clangFormat.cmake)
add_clang_format(TARGET exampleClangFormat VERSION 19)
```

### 🧹 clangTidy.cmake — [cmake/utilities/clangTidy.cmake](cmake/utilities/clangTidy.cmake)

Sets up the project to use clang-tidy for static analysis. `add_clang_tidy` requires:

- `TARGET` — the name of the custom target that runs `run-clang-tidy` (with `-fix`) across the
  whole compile database.
- `VERSION` — the clang-tidy major version to locate.

Pass `REQUIRED` to fail configuration when the requested version is missing; otherwise the target
is silently skipped.

In your root `CMakeLists.txt`:

```cmake
include(cmake/utilities/clangTidy.cmake)
add_clang_tidy(TARGET exampleClangTidy VERSION 19 REQUIRED)
```

When clang-tidy is found, the helper exports a `CLANG_TIDY` variable pointing at the resolved
binary. Set it as the `CXX_CLANG_TIDY` property on a target so clang-tidy runs alongside every
compile of that target:

```cmake
if(CLANG_TIDY)
  set_target_properties(exampleLibrary PROPERTIES CXX_CLANG_TIDY ${CLANG_TIDY})
endif()
```

In short: building `exampleClangTidy` runs a one-shot pass with auto-fixes across the whole
project, while the per-target `CXX_CLANG_TIDY` property turns every build of `exampleLibrary` into
a continuous clang-tidy check.

## 🛠️ Tools

### 📃 extractDependencies.sh — [tools/extractDependencies.sh](tools/extractDependencies.sh)

- Extracts system package dependencies from a JSON descriptor and prints a normalized list.
- Useful for feeding install steps (e.g., `apt-get install`) or auditing transitive requirements.
- Example systemDependencies.json:
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
    ```bash
    sh tools/extractDependencies.sh Compilers systemDependencies.json
    ```

### 📦 APT repositories for GNU/Clang/NVIDIA toolchains

- Scripts to add common upstream APT sources for toolchains:
  - GNU (GCC) toolchain repositories — [tools/apt/addGNUSources.sh](tools/apt/addGNUSources.sh)
  - LLVM/Clang repositories — [tools/apt/addLLVMSources.sh](tools/apt/addLLVMSources.sh)
  - NVIDIA CUDA/NVML toolchain
    repositories — [tools/apt/addNvidiaSources.sh](tools/apt/addNvidiaSources.sh)
- Ensures reproducible compiler/toolchain provisioning across CI and local environments.

### 🏗️ CMake installer — [tools/installCMake.sh](tools/installCMake.sh)

- Installs a specific CMake version in CI or on developer machines.
- Reduces environment drift when system package managers lag behind the required version.

### 🎨 Pinned formatter/linter configs

Bundled config files for `clang-format`, `clang-tidy`, and shell-script formatters. Consume them
by creating a symlink at the root of your repository that points to the desired config file in the
submodule. This keeps every consumer pinned to the same canonical configuration and avoids
copy/paste drift.

Example — assuming infraCommons is checked out at `external/infraCommons`, run the following from
the repository root:

```bash
ln -s external/infraCommons/tools/clang-format-19 .clang-format
ln -s external/infraCommons/tools/clang-tidy-19 .clang-tidy
ln -s external/infraCommons/tools/shfmt-3.8-editorconfig .editorconfig
```

Once linked, `clang-format`, `clang-tidy` (including invocations driven by `clangFormat.cmake` and
`clangTidy.cmake`), and `shfmt` will all pick up the pinned settings automatically.

## ♻️ Reusable GitHub Actions

This repository exposes composite GitHub actions for reuse across projects. Reference them in your
workflows using:

```yaml
- uses: ajakhotia/infraCommons/.github/actions/<action-name>@main
```

### 🧐 Action: cmake-find-package

Verifies that a library is installed and discoverable inside a published Docker image. The action
pulls the target image, runs [ajakhotia/importTester](https://github.com/ajakhotia/importTester)
inside it, and invokes `find_package(<library-name> REQUIRED)` against the supplied
`CMAKE_PREFIX_PATH`. The CI check fails on missing or misconfigured dependencies — catching
packaging regressions before downstream consumers ever pull the image.

```yaml
- name: find-library
  uses: ajakhotia/infraCommons/.github/actions/cmake-find-package@main
  with:
    library-name: <library-name>
    prefix-path: <cmake-prefix-path>
    image-name: <image-url>
    password: ${{ secrets.GITHUB_TOKEN }}
```

See real-world usage of `cmake-find-package`
in [robotFarm](https://github.com/ajakhotia/robotFarm/blob/main/.github/workflows/docker-image.yaml).

### 🐳 Action: docker-typical-build-push

Builds and pushes a Docker image stage with sensible defaults for tagging, multi-arch builds, and
layer caching.

```yaml
- name: docker-build-and-push-stage
  uses: ajakhotia/infraCommons/.github/actions/docker-typical-build-push@main
  with:
    dockerfile: <path-to-dockerfile>
    password: ${{ secrets.GITHUB_TOKEN }}
    target-stage: <target-docker-stage>
    target-stage-id: <id-of-target-stage>
    upstream-stage-id: <id-of-upstream-stage-built-before-this> # can be omitted if no upstream stage
    cache-type: registry # or gha
    build-name: <build-name>
    build-args: |
      FOO1=BAR1
      FOO2=BAR2
```

See real-world usage of `docker-typical-build-push`
in [robotFarm](https://github.com/ajakhotia/robotFarm/blob/main/.github/workflows/docker-image.yaml).

### ✨ Action: normalize

Normalizes an arbitrary string into a form that is safe to use as part of a Docker image tag.

```yaml
- name: normalizer-name
  id: normalized-name-id
  uses: ajakhotia/infraCommons/.github/actions/normalize@main
  with:
    string: ${{ inputs.target-stage-id }}
```

See real-world usage of `normalize`
in [docker-typical-build-push/action.yaml](.github/actions/docker-typical-build-push/action.yaml).
