# 🧰 infraCommons

Shared build infrastructure for C++ projects. Drop it in as a submodule and get reproducible
toolchains, CI workflows, code-quality configs, and CMake helpers — all managed in one place.

---

## 🗂️ What's Inside

### 📌 Pinned Docker Image Snapshots

- Weekly and monthly snapshots of popular OS images, cached at
  `ghcr.io/ajakhotia/infracommons/<cadence>/<image>`. [See details and how to request additions.](#-pinned-docker-image-snapshots-1)

### 🔧 CMake Toolchain Files

- Pre-configured compiler toolchains for GCC and Clang on Linux, with CUDA support baked in.
- Version-pinned variants for repeatable builds, plus auto-detecting defaults that upgrade
  gracefully when the system compiler is too old.

### 🏗️ CMake Helpers

- `exportedTargets.cmake` — Declare a library or executable target with sources, headers, flags, and
  install rules all in one place. No more scattered `target_*` calls.
  ([example](https://github.com/ajakhotia/nioc/blob/main/modules/geometry/CMakeLists.txt))
- `capnprotoGenerate.cmake` — Cap'n Proto code generation wired into the CMake build graph.
  ([example](https://github.com/ajakhotia/nioc/blob/main/modules/geometry/CMakeLists.txt))
- `requireArguments.cmake` — Validates required arguments parsed by `cmake_parse_arguments`.
  ([example](cmake/utilities/clangTidy.cmake))
- `clangFormat.cmake` — Sets up a build target to run clangformat across all source files.
  ([example](https://github.com/ajakhotia/nioc/blob/main/CMakeLists.txt#L23-L35))
- `clangTidy.cmake` — Sets up the static analyser. Creates a custom target for project-wide auto fix
  and provides variables so clang-tidy can be enabled on a per-target basis.
  ([example](https://github.com/ajakhotia/nioc/blob/main/CMakeLists.txt#L23-L35))

### 🧼 Code Quality Configs

- Provides `clang-format`, `clang-tidy`, and `shfmt` configs for multiple versions of each tool.
  Projects symlink the appropriate version to their root to benefit from a curated configuration.
  ([.clang-format](https://github.com/ajakhotia/nioc/blob/main/.clang-format),
  [.clang-tidy](https://github.com/ajakhotia/nioc/blob/main/.clang-tidy),
  [.editorconfig](https://github.com/ajakhotia/nioc/blob/main/.editorconfig))

### 🛠️ Toolchain Provisioning Scripts

- APT source setup for GNU, LLVM/Clang, and NVIDIA CUDA toolchains.
- JSON-driven system dependency extraction for reproducible `apt-get install` steps.
- CMake installer to download and install CMake of a specific version.

### ♻️ Reusable GitHub Actions

- `docker-typical-build-push` — Multi-arch Docker builds with automatic tagging and layer caching.
- `cmake-find-package` — Validates library discoverability inside a published Docker image.
- `normalize` — Sanitises arbitrary strings into Docker-safe image tags.
- `oci-compliant-image-name` — Constructs fully qualified OCI image names.
- `docker-pull-retag-push` — Pulls upstream images and re-publishes them to your registry.

---

## 🚀 Getting Started

infraCommons is consumed as a **git submodule**. Add it to your project once, then pull in
improvements over time with standard submodule commands.

```bash
git submodule add https://github.com/ajakhotia/infraCommons.git external/infraCommons
git submodule update --init
```

The [nioc](https://github.com/ajakhotia/nioc) project is the best reference for how to wire
everything up. Here is what that integration looks like:

**Include CMake utilities** in your root `CMakeLists.txt`:

> Replace `<myProject>` with your project name.

```cmake
if(PROJECT_IS_TOP_LEVEL)
  include(external/infraCommons/cmake/utilities/capnprotoGenerate.cmake)
  include(external/infraCommons/cmake/utilities/clangFormat.cmake)
  include(external/infraCommons/cmake/utilities/clangTidy.cmake)
  include(external/infraCommons/cmake/utilities/exportedTargets.cmake)
  include(external/infraCommons/cmake/utilities/requireArguments.cmake)

  add_clang_format(TARGET <myProject>ClangFormat VERSION 19)
  add_clang_tidy(TARGET <myProject>ClangTidy VERSION 19)
endif()
```

**Reference toolchain files** during CMake configuration:

```bash
cmake -B build -DCMAKE_TOOLCHAIN_FILE=external/infraCommons/cmake/toolchains/linux-clang-default.cmake
```

**Symlink code quality configs** from your repository root:

```bash
ln -s external/infraCommons/tools/clang-format-19 .clang-format
ln -s external/infraCommons/tools/clang-tidy-19 .clang-tidy
ln -s external/infraCommons/tools/shfmt-3.8-editorconfig .editorconfig
```

**Reference reusable GitHub Actions** in your workflows
([example](https://github.com/ajakhotia/nioc/blob/main/.github/workflows/docker-image.yaml)):

```yaml
- uses: ajakhotia/infraCommons/.github/actions/docker-typical-build-push@main
```

---

# 📖 Details

## 📌 Pinned Docker Image Snapshots

Upstream Docker images (e.g. `ubuntu:24.04`) mutate too often — frequent upstream changes lead to
cache misses that trigger full rebuilds for no particular benefit. infraCommons runs scheduled
workflows that pull popular OS images and re-publish them to
`ghcr.io/ajakhotia/infracommons/` on a fixed cadence:

```
ghcr.io/ajakhotia/infracommons/<cadence>/<image>:<tag>
```

| Cadence   | Schedule                             |
|-----------|--------------------------------------|
| `weekly`  | Every Sunday at 00:00 UTC            |
| `monthly` | First day of each month at 00:00 UTC |

Use a monthly snapshot as the base image in your Dockerfile to get a stable, reproducible starting
point that still receives periodic updates. Browse
[`cmake/toolchains/`](cmake/toolchains) and the
[snapshot workflows](.github/workflows) for the current list of images and cadences.

Want an image or cadence added? Open an
[issue](https://github.com/ajakhotia/infraCommons/issues) or send a PR updating the workflow matrix.

---

## 🔧 CMake Toolchain Files

Pre-configured toolchain files that set the C, C++, Fortran, and CUDA compilers along with the
necessary linker flags. Pass one to CMake via `-DCMAKE_TOOLCHAIN_FILE` or through a preset.

Two flavours are provided for each supported compiler family:

- **Default / auto-detecting** — uses the system compiler when it meets the minimum version
  requirement, and transparently upgrades to a known-good suffixed binary (e.g. `gcc-13`) when it
  doesn't.
- **Version-pinned** — hardcodes a specific compiler version and its associated runtime library
  paths. Ideal for CI and release builds where exact reproducibility matters.

All toolchain files also configure CUDA via `nvcc` with pinned GPU architectures.

Browse [`cmake/toolchains`](cmake/toolchains) for the full set of available toolchains.

```bash
cmake -B build -DCMAKE_TOOLCHAIN_FILE=external/infraCommons/cmake/toolchains/linux-clang-default.cmake
```

Real-world usage:
[nioc/docker/ubuntu.dockerfile](https://github.com/ajakhotia/nioc/blob/main/docker/ubuntu.dockerfile#L86)

---

## 🏗️ CMake Helpers

### 📦 exportedTargets.cmake

[cmake/utilities/exportedTargets.cmake](cmake/utilities/exportedTargets.cmake)

Helpers for exporting and installing CMake targets in a consistent way. Encourages predictable
namespace usage and proper install/export rules for libraries and headers.

```cmake
include(external/infraCommons/cmake/utilities/exportedTargets.cmake)

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

Real-world usage:
[nioc/modules/geometry/CMakeLists.txt](https://github.com/ajakhotia/nioc/blob/main/modules/geometry/CMakeLists.txt)

### 🧬 capnprotoGenerate.cmake

[cmake/utilities/capnprotoGenerate.cmake](cmake/utilities/capnprotoGenerate.cmake)

Thin wrapper around Cap'n Proto code generation. Generates C++ sources from `.capnp` schemas and
wires them into the CMake build graph with the correct dependencies.

```cmake
include(external/infraCommons/cmake/utilities/capnprotoGenerate.cmake)

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

Real-world usage:
[nioc/modules/geometry/CMakeLists.txt](https://github.com/ajakhotia/nioc/blob/main/modules/geometry/CMakeLists.txt)

### ✅ requireArguments.cmake

[cmake/utilities/requireArguments.cmake](cmake/utilities/requireArguments.cmake)

Validates required arguments parsed by `cmake_parse_arguments` inside CMake functions. Emits a
`FATAL_ERROR` (attributed to the calling function) listing any missing or empty arguments.

```cmake
include(external/infraCommons/cmake/utilities/requireArguments.cmake)

function(my_function)
  cmake_parse_arguments("MF_PARAM" "" "TARGET;VERSION" "" ${ARGN})
  require_arguments(PREFIX MF_PARAM ARGUMENTS TARGET VERSION)
  # ... safe to use ${MF_PARAM_TARGET} and ${MF_PARAM_VERSION} here ...
endfunction()
```

Real-world usage: [clangTidy.cmake](cmake/utilities/clangTidy.cmake)

### 🎨 clangFormat.cmake

[cmake/utilities/clangFormat.cmake](cmake/utilities/clangFormat.cmake)

Adds a custom target that runs clangformat over all source files in the project.

```cmake
include(external/infraCommons/cmake/utilities/clangFormat.cmake)
add_clang_format(TARGET myProjectClangFormat VERSION 19)
```

Real-world usage:
[nioc/CMakeLists.txt](https://github.com/ajakhotia/nioc/blob/main/CMakeLists.txt#L30)

### 🧹 clangTidy.cmake

[cmake/utilities/clangTidy.cmake](cmake/utilities/clangTidy.cmake)

Sets up clang-tidy for static analysis. Creates a custom target that runs `run-clang-tidy`
(with `-fix`) across the whole compile-database. Pass `REQUIRED` to fail configuration when the
requested version is missing.

```cmake
include(external/infraCommons/cmake/utilities/clangTidy.cmake)
add_clang_tidy(TARGET myProjectClangTidy VERSION 19 REQUIRED)
```

When clang-tidy is found, the helper exports a `CLANG_TIDY` variable. Set it as the
`CXX_CLANG_TIDY` property on a target for running checks during builds:

```cmake
if(CLANG_TIDY)
  set_target_properties(exampleLibrary PROPERTIES CXX_CLANG_TIDY ${CLANG_TIDY})
endif()
```

Real-world usage:
[nioc/CMakeLists.txt](https://github.com/ajakhotia/nioc/blob/main/CMakeLists.txt#L31)

---

## 🧼 Code Quality Configs

Bundled configuration files for `clang-format`, `clang-tidy`, and `shfmt` are available. Consume
them by symlinking from your repository root to the desired config in the submodule. Every consumer
stays pinned to the same canonical configuration with zero copy/paste drift.

```bash
# From your repository root (assuming infraCommons is at external/infraCommons)
ln -s external/infraCommons/tools/<clang-format-config> .clang-format
ln -s external/infraCommons/tools/<clang-tidy-config>   .clang-tidy
ln -s external/infraCommons/tools/<shfmt-editorconfig>  .editorconfig
```

Once linked, `clang-format`, `clang-tidy` (including invocations driven by `clangFormat.cmake` and
`clangTidy.cmake`), and `shfmt` will all pick up the pinned settings automatically.

Browse [`tools`](tools) for available config versions.

Real-world usage:
[nioc/.clang-format](https://github.com/ajakhotia/nioc/blob/main/.clang-format),
[nioc/.clang-tidy](https://github.com/ajakhotia/nioc/blob/main/.clang-tidy),
[nioc/.editorconfig](https://github.com/ajakhotia/nioc/blob/main/.editorconfig)

---

## 🛠️ Toolchain Provisioning Scripts

### 📡 APT Repository Setup

Scripts to register upstream APT sources for common compiler toolchains. Ensures reproducible
provisioning across CI and local environments.

| Script                                                           | Purpose                                             |
|------------------------------------------------------------------|-----------------------------------------------------|
| [`tools/apt/addGNUSources.sh`](tools/apt/addGNUSources.sh)       | Registers upstream GCC/GNU toolchain repositories.  |
| [`tools/apt/addLLVMSources.sh`](tools/apt/addLLVMSources.sh)     | Registers `apt.llvm.org` for LLVM/Clang toolchains. |
| [`tools/apt/addNvidiaSources.sh`](tools/apt/addNvidiaSources.sh) | Registers the NVIDIA CUDA APT repository.           |

Real-world usage:
[nioc/README.md](https://github.com/ajakhotia/nioc/blob/main/README.md#L136-L148)

### 📃 extractDependencies.sh

[tools/extractDependencies.sh](tools/extractDependencies.sh)

Extracts system package dependencies from a JSON descriptor and prints a normalised, OS-specific
list. Useful for feeding `apt-get install`, or other package managers, or auditing transitive
requirements.

```json
{
  "groups": [
    {
      "group": "Basics",
      "ubuntu:22.04": "ca-certificates curl wget",
      "ubuntu:24.04": "ca-certificates curl wget",
      "tag": "all"
    },
    {
      "group": "Compilers",
      "ubuntu:22.04": "clang-19 gcc-13 g++-13 gfortran-13",
      "ubuntu:24.04": "clang-19 gcc-14 g++-14 gfortran-14",
      "tag": "all"
    }
  ]
}
```

```bash
sh tools/extractDependencies.sh Compilers systemDependencies.json
```

Real-world usage:
[nioc/docker/ubuntu.dockerfile](https://github.com/ajakhotia/nioc/blob/main/docker/ubuntu.dockerfile#L44-L48)

### 🔩 installCMake.sh

[tools/installCMake.sh](tools/installCMake.sh)

Installs a specific CMake version on CI runners or developer machines. Supports multiple
architectures. Reduces environment drift when system package managers lag behind the required
version.

```bash
sudo bash external/infraCommons/tools/installCMake.sh
```

Real-world usage:
[nioc/README.md](https://github.com/ajakhotia/nioc/blob/main/README.md#L114)

---

## ♻️ Reusable GitHub Actions

Reference these composite actions in your workflows using:

```yaml
- uses: ajakhotia/infraCommons/.github/actions/<action-name>@main
```

### 🐳 docker-typical-build-push

Builds and pushes a Docker image stage with sensible defaults for tagging, multi-arch builds, and
layer caching.

```yaml
- name: docker-build-and-push-stage
  uses: ajakhotia/infraCommons/.github/actions/docker-typical-build-push@main
  with:
    dockerfile: <path-to-dockerfile>
    target-stage: <target-docker-stage>
    image-name: <fully-qualified-image-name>
    build-args: |
      FOO1=BAR1
      FOO2=BAR2
```

Real-world usage:
[nioc/.github/workflows/docker-image.yaml](https://github.com/ajakhotia/nioc/blob/main/.github/workflows/docker-image.yaml#L45)

### 🧐 cmake-find-package

Verifies that a library is installed and discoverable inside a published Docker image. Pulls the
target image, runs
[ajakhotia/importTester](https://github.com/ajakhotia/importTester) inside it, and invokes
`find_package(<library-name> REQUIRED)` against the supplied `CMAKE_PREFIX_PATH`. Catches packaging
regressions before downstream consumers ever pull the image.

```yaml
- name: find-library
  uses: ajakhotia/infraCommons/.github/actions/cmake-find-package@main
  with:
    library-name: <library-name>
    prefix-path: <cmake-prefix-path>  # optional
    image-name: <fully-qualified-image-name>
```

Real-world usage:
[nioc/.github/workflows/docker-image.yaml](https://github.com/ajakhotia/nioc/blob/main/.github/workflows/docker-image.yaml#L181)

### ✨ normalize

Normalises an arbitrary string into a form that is safe to use as part of a Docker image tag.

```yaml
- name: normalizer
  id: normalizer-id
  uses: ajakhotia/infraCommons/.github/actions/normalize@main
  with:
    string: ${{ inputs.target-stage-id }}

# Reference the result in further steps:
- run: echo ${{ steps.normalizer-id.outputs.string }}
```

Real-world usage:
[oci-compliant-image-name/action.yaml](.github/actions/oci-compliant-image-name/action.yaml)

### 🏷️ oci-compliant-image-name

Constructs a fully qualified, OCI-compliant image name from a registry, repository, and build name.
Each component is normalised automatically.

```yaml
- name: image-name
  id: image-name
  uses: ajakhotia/infraCommons/.github/actions/oci-compliant-image-name@main
  with:
    build-name: ubuntu:22.04/linux-clang-19/deploy
    # registry defaults to ghcr.io, repository defaults to the current repo

# Reference the assembled image name in the following steps:
- run: echo ${{ steps.image-name.outputs.name }}
  # e.g. ghcr.io/ajakhotia/nioc/ubuntu-22-04/linux-clang-19/deploy
```

Real-world usage:
[nioc/.github/workflows/docker-image.yaml](https://github.com/ajakhotia/nioc/blob/main/.github/workflows/docker-image.yaml#L40)

### 🔄 docker-pull-retag-push

Pulls a public Docker image, retags it, and pushes to a target registry. Used by the snapshot
workflows to cache upstream images on a schedule.

```yaml
- name: cache-ubuntu
  uses: ajakhotia/infraCommons/.github/actions/docker-pull-retag-push@main
  with:
    source: ubuntu:24.04
    destination: ghcr.io/ajakhotia/infracommons/monthly/ubuntu:24.04
```

Real-world usage:
[docker-snapshot-monthly.yaml](.github/workflows/docker-snapshot-monthly.yaml)
