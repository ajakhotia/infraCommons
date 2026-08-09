<h1 align="center">🧰 infraCommons</h1>

<p align="center">
  <strong>Shared build infrastructure for C++ projects, vendored as one submodule<br/>
  pinned toolchains&nbsp;&nbsp;·&nbsp;&nbsp;one-call CMake targets&nbsp;&nbsp;·&nbsp;&nbsp;CI-tested GitHub Actions</strong>
</p>

<p align="center">
  <a href="https://github.com/ajakhotia/infraCommons/actions/workflows/docker-snapshot-weekly.yaml"><img src="https://github.com/ajakhotia/infraCommons/actions/workflows/docker-snapshot-weekly.yaml/badge.svg" alt="docker-snapshot-weekly"/></a>
  <a href="https://github.com/ajakhotia/infraCommons/actions/workflows/docker-snapshot-monthly.yaml"><img src="https://github.com/ajakhotia/infraCommons/actions/workflows/docker-snapshot-monthly.yaml/badge.svg" alt="docker-snapshot-monthly"/></a>
  <img src="https://img.shields.io/badge/toolchain-Clang%2021%2F22%20%7C%20GCC%2014%2F15-informational" alt="Toolchains"/>
  <img src="https://img.shields.io/badge/platform-Ubuntu%2022.04%20%7C%2024.04-E95420?logo=ubuntu&logoColor=white" alt="Platform"/>
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License: MIT"/>
</p>

Every C++ project begins with the same unglamorous week: pick compiler versions and write
toolchain files, wire up clang-format and clang-tidy, get install/export rules right so
`find_package` works downstream, script the CI images, and cache Docker layers so builds don't
take an hour. None of that work differentiates your project, and once copy-pasted between
repos, all of it drifts.

***infraCommons*** is that layer, built once and shared. Vendor it as a git submodule and your
project starts on day one with a pinned toolchain, project-wide format and lint targets, exported
CMake packages, reproducible provisioning, and Docker-centric CI actions. When infraCommons
improves, every consumer picks up the improvement with a plain
`git submodule update`. Nothing is copy-pasted, so nothing drifts.

**With one submodule, your build runs a pinned compiler, your formatter and linter are build
targets, your libraries install as `find_package`-able packages, and your CI builds cached,
multi-stage Docker images.**

What's inside:

- 🔧 **[CMake toolchains](#-cmake-toolchains)**: version-pinned Clang and GCC toolchain files
  with CUDA wired in when present.
- 🏗️ **[CMake helpers](#%EF%B8%8F-cmake-helpers)**: declare an exported, installable library in
  one call; generate Cap'n Proto sources in the build graph; format and lint the whole tree as
  build targets.
- 🧼 **[Code-quality configs](#-code-quality-configs)**: curated `clang-format`, `clang-tidy`,
  and `shfmt` configurations, consumed by symlink so every project stays on the same settings.
- 🛠️ **[Provisioning scripts](#%EF%B8%8F-toolchain-provisioning-scripts)**: one script registers
  the GNU, LLVM, NVIDIA, and Kitware APT sources; JSON-driven system-dependency resolution.
- ♻️ **[Reusable GitHub Actions](#%EF%B8%8F-reusable-github-actions)**: seven composite actions
  for Docker-centric CI pipelines, each guarded by its own test workflow.
- 📌 **[Pinned Docker image snapshots](#-pinned-docker-image-snapshots)**: weekly and monthly
  Ubuntu snapshots for `FROM` lines that don't churn your layer cache.

[nioc](https://github.com/ajakhotia/nioc) is a complete, production-shaped consumer: its
toolchains, format/tidy targets, exported packages, and its entire CI pipeline come from
infraCommons. Most sections below link to the exact lines in nioc that use them.

---

## 🔧 CMake Toolchains

A compiler picked up from `$PATH` is a moving target: builds pass on one machine and break on the
next, and "works in CI" stops meaning anything. Each toolchain file in
[`cmake/toolchains`](cmake/toolchains) pins the exact C, C++, and Fortran compiler binaries for
one compiler family and version:

- `linux-clang-21.cmake` / `linux-clang-22.cmake`: Clang, with the matching LLVM library
  directory on the linker path and rpath so the right runtime is found at build *and* run time.
- `linux-gnu-14.cmake` / `linux-gnu-15.cmake`: GCC.

Every file also probes for CUDA (`CUDA_HOME`, `CUDA_PATH`, then `/usr/local/cuda`). When `nvcc`
is present, it is configured as the CUDA compiler with pinned GPU architectures and the
toolchain's own C++ compiler as the host compiler; when absent, the toolchain works as a plain
CPU toolchain. Same file either way.

```shell
cmake -G Ninja -S . -B build \
  --toolchain external/infraCommons/cmake/toolchains/linux-clang-22.cmake
```

Real-world usage:
[nioc/docker/ubuntuNioc.dockerfile](https://github.com/ajakhotia/nioc/blob/main/docker/ubuntuNioc.dockerfile)

---

## 🏗️ CMake Helpers

Focused utilities under [`cmake/utilities`](cmake/utilities). Include the ones you need once
from the project-root `CMakeLists.txt` (see
[Using infraCommons in your project](#-using-infracommons-in-your-project)); the functions are
then available in every directory below.

### 📦 Exported Targets

[cmake/utilities/exportedTargets.cmake](cmake/utilities/exportedTargets.cmake) ·
[cmake/utilities/capnprotoGenerate.cmake](cmake/utilities/capnprotoGenerate.cmake)

Making a library properly consumable (namespaced alias, `BUILD_INTERFACE` /
`INSTALL_INTERFACE` include paths, header installation, export sets) takes a dozen scattered
`target_*` and `install()` calls, and forgetting any one of them surfaces as a downstream
`find_package` failure. `add_exported_library` and `add_exported_executable` collapse all of it
into one declaration.

`capnproto_generate_library` extends the same idea to Cap'n Proto: it runs `capnp` at build time
with correct dependencies (edit a schema, rebuild, done), compiles the generated sources, links
the Cap'n Proto runtime, and hands the result to `add_exported_library`, so a schema library
exports and installs exactly like a hand-written one. Schemas can import each other across
libraries, too: the include directories of everything in `LINK_LIBRARIES` become `--import-path`
flags, so schema libraries compose just like ordinary targets.

<table>
<tr>
<th align="left">add_exported_library</th>
<th align="left">add_exported_executable</th>
<th align="left">capnproto_generate_library</th>
</tr>
<tr>
<td>

```cmake
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
    INTERFACE include/example/foo.hpp
    INTERFACE include/example/bar.hpp
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

</td>
<td>

```cmake
add_exported_executable(
  TARGET
    exampleTool
  NAMESPACE
    ExampleNamespace::
  EXPORT
    ExampleTargetSet
  SOURCES
    src/exampleToolMain.cpp
  HEADERS
    include/example/foo.hpp
  INCLUDE_DIRECTORIES
    ${CMAKE_CURRENT_SOURCE_DIR}/include
  LINK_LIBRARIES
    ExampleNamespace::exampleLibrary
  COMPILE_FEATURES
    cxx_std_20
  COMPILE_OPTIONS
    ""
  COMPILE_DEFINITIONS
    ""
)



```

</td>
<td>

```cmake
capnproto_generate_library(
  TARGET
    exampleMessagesIdl
  NAMESPACE
    ExampleNamespace::
  EXPORT
    ExampleTargetSet
  SCHEMA_FILES
    include/example/idl/message_a.capnp
    include/example/idl/message_b.capnp
  COMPILE_FEATURES
    PUBLIC cxx_std_20
  COMPILE_OPTIONS
    ""
  COMPILE_DEFINITIONS
    ""
)








```

</td>
</tr>
</table>

Every target builds in-tree under its namespace (`ExampleNamespace::exampleLibrary`,
`ExampleNamespace::exampleTool`, `ExampleNamespace::exampleMessagesIdl`) and installs with the
same name for `find_package` consumers. Leave `TYPE` empty for compiled libraries so the person
configuring the build chooses static or shared with `-DBUILD_SHARED_LIBS`; the helper warns if
you hardcode it. `add_exported_executable` takes its values without visibility keywords. Nothing
consumes an executable's usage requirements, so the helper applies everything `PRIVATE`.

Real-world usage:
[nioc/modules/geometry/CMakeLists.txt](https://github.com/ajakhotia/nioc/blob/main/modules/geometry/CMakeLists.txt)

### 🎨 clangFormat.cmake

[cmake/utilities/clangFormat.cmake](cmake/utilities/clangFormat.cmake)

`add_clang_format` creates a build target that formats every C/C++ source in the project with a
pinned clang-format version, so "run the formatter" is the same command on every machine and in
CI. Pass `REQUIRED` to fail configuration when the tool is missing; without it the target is
skipped quietly.

```cmake
include(external/infraCommons/cmake/utilities/clangFormat.cmake)
add_clang_format(TARGET clangFormat VERSION 22)
```

```shell
cmake --build build --target clangFormat
```

Real-world usage:
[nioc/CMakeLists.txt](https://github.com/ajakhotia/nioc/blob/main/CMakeLists.txt)

### 🧹 clangTidy.cmake

[cmake/utilities/clangTidy.cmake](cmake/utilities/clangTidy.cmake)

`add_clang_tidy` sets up static analysis two complementary ways, both pinned to an exact
clang-tidy version and both excluding generated headers under the build tree:

- A custom target that runs `run-clang-tidy -fix` over the whole compile database, giving a
  project-wide sweep.
- A `CLANG_TIDY` variable ready to drop into a target's `CXX_CLANG_TIDY` property, so analysis
  runs *during* compilation and the build itself is the lint gate.

```cmake
include(external/infraCommons/cmake/utilities/clangTidy.cmake)
add_clang_tidy(TARGET clangTidy VERSION 22 REQUIRED)

if(CLANG_TIDY)
  set_target_properties(exampleLibrary PROPERTIES CXX_CLANG_TIDY ${CLANG_TIDY})
endif()
```

The sweep target has a classic failure mode: if generated headers don't exist yet, clang-tidy
parses a broken AST and `-fix` applies invalid edits. `add_clang_tidy_build_dependencies` closes
that hole by making every compiled target a build dependency of the tidy target. Call it once
from the root `CMakeLists.txt` after all `add_subdirectory` calls:

```cmake
if(TARGET clangTidy)
  add_clang_tidy_build_dependencies(clangTidy)
endif()
```

Real-world usage:
[nioc/CMakeLists.txt](https://github.com/ajakhotia/nioc/blob/main/CMakeLists.txt)

### 🗂️ collectBuildTargets.cmake

[cmake/utilities/collectBuildTargets.cmake](cmake/utilities/collectBuildTargets.cmake)

CMake's `BUILDSYSTEM_TARGETS` property is per-directory, so a single query silently misses every
target defined under `add_subdirectory`. `collect_build_targets` recurses the directory tree and
returns every target the build actually creates. It is the primitive behind
`add_clang_tidy_build_dependencies`, and it is useful anywhere you need to apply a property or
dependency project-wide.

```cmake
include(external/infraCommons/cmake/utilities/collectBuildTargets.cmake)

collect_build_targets(ALL_TARGETS "${CMAKE_SOURCE_DIR}")
foreach(TARGET IN LISTS ALL_TARGETS)
  # ...
endforeach()
```

### ✅ requireArguments.cmake

[cmake/utilities/requireArguments.cmake](cmake/utilities/requireArguments.cmake)

Validates arguments parsed with `cmake_parse_arguments`, emitting a `FATAL_ERROR` attributed to
the calling function that lists every missing or empty argument, instead of the cryptic failure
you get three lines later when an empty variable is used.

```cmake
include(external/infraCommons/cmake/utilities/requireArguments.cmake)

function(my_function)
  cmake_parse_arguments("MF_PARAM" "" "TARGET;VERSION" "" ${ARGN})
  require_arguments(PREFIX MF_PARAM ARGUMENTS TARGET VERSION)
  # ... safe to use ${MF_PARAM_TARGET} and ${MF_PARAM_VERSION} here ...
endfunction()
```

Real-world usage: [clangTidy.cmake](cmake/utilities/clangTidy.cmake)

---

## 🧼 Code Quality Configs

A formatter config that lives in each repo is a formatter config that diverges. infraCommons
keeps one curated configuration per tool per version under [`tools`](tools):
`clang-format-19` / `clang-format-22`, `clang-tidy-19` / `clang-tidy-22`, and
`shfmt-3.8-editorconfig`. Every project consumes them by symlink:

```bash
# From your repository root (assuming infraCommons is at external/infraCommons):
ln -s external/infraCommons/tools/clang-format-22        .clang-format
ln -s external/infraCommons/tools/clang-tidy-22          .clang-tidy
ln -s external/infraCommons/tools/shfmt-3.8-editorconfig .editorconfig
```

Once linked, `clang-format`, `clang-tidy` (including the `clangFormat.cmake` / `clangTidy.cmake`
targets above), IDEs, and `shfmt` all pick up the pinned settings automatically. Upgrading a tool
version across all your projects is re-pointing a symlink; refining a check in one place refines
it everywhere.

Real-world usage:
[nioc/.clang-format](https://github.com/ajakhotia/nioc/blob/main/.clang-format),
[nioc/.clang-tidy](https://github.com/ajakhotia/nioc/blob/main/.clang-tidy),
[nioc/.editorconfig](https://github.com/ajakhotia/nioc/blob/main/.editorconfig)

---

## 🛠️ Toolchain Provisioning Scripts

The toolchain files above assume the compilers exist; these scripts make that true, the same
way on a laptop, in a Dockerfile, and on a CI runner.

### 📡 APT Repository Setup

[tools/apt/addAptSources.sh](tools/apt/addAptSources.sh)

One script registers the upstream APT sources ("taps") that track the latest toolchain
releases, each through the vendor's own supported mechanism with proper `signed-by` keyrings.
The taps are OS-version agnostic: each one derives the right vendor source from your release
and architecture instead of hardcoding a support matrix, so a new Ubuntu release needs no
script changes.

| Tap       | Source                                                                                                      |
|-----------|-------------------------------------------------------------------------------------------------------------|
| `gnu`     | Ubuntu Toolchain PPA (Debian: backports) for the latest GCC.                                                |
| `llvm`    | `apt.llvm.org`, probing for the suites that exist for your release.                                         |
| `nvidia`  | NVIDIA CUDA repository for your OS release and architecture (x86_64, Jetson arm64, server sbsa). |
| `kitware` | `apt.kitware.com` for the latest CMake (Ubuntu only).                                                       |

```bash
sudo bash tools/apt/addAptSources.sh -y                # all taps
sudo bash tools/apt/addAptSources.sh -y llvm nvidia    # just these taps
```

The script prompts before touching the system; pass `-y` for non-interactive use. It only
registers sources and never installs toolchains: run `apt-get update` afterwards and install
packages resolved through `extractDependencies.sh` below.

Real-world usage:
[nioc/README.md](https://github.com/ajakhotia/nioc/blob/main/README.md)

### 📃 extractDependencies.sh

[tools/extractDependencies.sh](tools/extractDependencies.sh)

Your system dependencies belong in a reviewable file, not scattered across Dockerfiles, CI
steps, and README instructions that each list a slightly different set.
`extractDependencies.sh` reads a JSON descriptor that names package groups per OS release,
detects the host (any Linux distribution via `/etc/os-release`, plus macOS), and prints the
resolved package list to stdout. What consumes the list is up to the caller: pass it to
`apt-get install`, write it to a file, or feed it to any other tooling. One reviewable file
stays the source of truth everywhere:

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
      "ubuntu:22.04": "clang-22 gcc-15 g++-15 gfortran-15",
      "ubuntu:24.04": "clang-22 gcc-15 g++-15 gfortran-15",
      "tag": "all"
    }
  ]
}
```

```bash
sudo apt install -y --no-install-recommends \
  $(sh tools/extractDependencies.sh "Basics Compilers" systemDependencies.json)
```

Query multiple groups in one call, and expand an explicit allow-list of environment variables in
the package strings with `--expand "ROS_DISTRO"`, which is handy when package names embed a
distro name.

Resolution rules:

- A requested group is matched by exact name. A group absent from the descriptor resolves to
  nothing, with a warning on stderr. This is deliberate: a caller may derive its group list from
  elsewhere (for example, a build list of external projects, one group per project name), and
  entries that need no system packages simply contribute nothing.
- A group that exists but has no entry for the detected OS key is a hard error: the descriptor
  is incomplete for that OS, and a silent skip would surface later as a missing package deep in
  a build.

Real-world usage:
[nioc/docker/ubuntuDevBase.dockerfile](https://github.com/ajakhotia/nioc/blob/main/docker/ubuntuDevBase.dockerfile)

---

## ♻️ Reusable GitHub Actions

Composite actions distilled from real Docker-centric CI pipelines. They capture the multi-stage
build-cache-push-verify choreography that every containerized project reimplements. **Each action is
guarded by its own test workflow in [`.github/workflows`](.github/workflows), so `@main` is a
tested reference, not a hope.** Together they compose into a pipeline that builds multi-stage
images with layer caching, sequences dependent workflows, gates merges on whole build matrices,
and verifies published images before anyone pulls them.

Reference any action as:

```yaml
- uses: ajakhotia/infraCommons/.github/actions/<action-name>@main
```

### 🐳 docker-typical-build-push

Builds one stage of a multi-stage Dockerfile and pushes it with sensible tags out of the box:
the commit SHA, `latest` on the main branch, and semver tags on release. Layer caching is where
it earns its keep. Pick a backend per call:

- **`gha`** (default): the GitHub Actions cache, with the repository as a single shared scope so
  every stage and matrix entry feeds one content-addressed pool. Zero setup, but subject to the
  10 GB per-repo Actions cache limit.
- **`registry`**: an OCI registry as cache storage, with no practical size limit. Beyond the
  per-image cache, `shared-cache-from` consumes caches produced by earlier jobs read-only, and
  `shared-cache-to` maintains read-write caches shared across builds.

```yaml
- name: docker-build-and-push-stage
  uses: ajakhotia/infraCommons/.github/actions/docker-typical-build-push@main
  with:
    dockerfile: docker/ubuntu.dockerfile
    target-stage: deploy
    image-name: ghcr.io/owner/repo/deploy
    cache-backend: registry
    shared-cache-from: |
      ghcr.io/owner/repo/base:cache
    build-args: |
      OS_BASE=ubuntu:24.04
```

Set up a buildx builder once per job (`docker/setup-buildx-action`) before the first call.

Real-world usage:
[nioc/.github/workflows/docker-image.yaml](https://github.com/ajakhotia/nioc/blob/main/.github/workflows/docker-image.yaml)

### ⏳ wait-for-workflow

Workflow B needs the image workflow A publishes, but they fire on the same push. Duplicating A's
path filters into B is the copy-paste trap again, and the copies will drift.
`wait-for-workflow` polls for A's run on the same commit. It waits for completion when A was
triggered, succeeds immediately when A wasn't (GitHub creates run records at event-dispatch time,
so an absent run reliably means "not triggered"), and reports through the `succeeded` output
whether fresh artifacts exist for this commit. Polling cadence and patience are tunable via
`poll-interval-seconds` (default 30) and `timeout-seconds` (default 3600).

```yaml
- name: wait-for-dev-base-image
  uses: ajakhotia/infraCommons/.github/actions/wait-for-workflow@main
  with:
    workflow: dev-base-image.yaml
    # sha defaults to the head SHA of the triggering event, token to github.token
```

Real-world usage:
[nioc/.github/workflows/docker-image.yaml](https://github.com/ajakhotia/nioc/blob/main/.github/workflows/docker-image.yaml)

### 🎯 matrix-aggregate

Branch protection can't require "every entry of the matrix", because the entries appear
and disappear as the matrix changes. `matrix-aggregate` gives protection a single stable job
to require: it fails if any run of the upstream matrix did not succeed.

```yaml
aggregate:
  if: always()
  needs: [matrix-job]
  runs-on: ubuntu-latest
  steps:
    - uses: ajakhotia/infraCommons/.github/actions/matrix-aggregate@main
      with:
        result: ${{ needs.matrix-job.result }}
```

Real-world usage:
[nioc/.github/workflows/docker-image.yaml](https://github.com/ajakhotia/nioc/blob/main/.github/workflows/docker-image.yaml)

### 🧐 cmake-find-package

A published image with a broken CMake package config is a time bomb for downstream consumers.
This action pulls the image, runs [ajakhotia/importTester](https://github.com/ajakhotia/importTester)
inside it, and invokes `find_package(<library> REQUIRED)` for each listed library, catching
packaging regressions before anyone pulls the image. When the image needs runtime provisioning
first, the optional `pre-check` / `post-check` inputs source arbitrary bash inside the container
before and after the check (extract an archive, apt-install a dependency, dump a log), and
`volumes` mounts extra host paths into it.

```yaml
- name: find-library
  uses: ajakhotia/infraCommons/.github/actions/cmake-find-package@main
  with:
    library-names: <semicolon-delimited-library-names>
    prefix-path: <cmake-prefix-path>  # optional
    image-name: <fully-qualified-image-name>
```

Real-world usage:
[nioc/.github/workflows/docker-image.yaml](https://github.com/ajakhotia/nioc/blob/main/.github/workflows/docker-image.yaml)

### 🏷️ oci-compliant-image-name

Constructs a fully qualified, OCI-compliant image name from a registry, repository, and build
name, normalising each component along the way, so matrix values like `ubuntu:22.04/deploy`
become valid image paths without ad-hoc `sed`.

```yaml
- name: image-name
  id: image-name
  uses: ajakhotia/infraCommons/.github/actions/oci-compliant-image-name@main
  with:
    build-name: ubuntu:22.04/linux-clang-22/deploy
    # registry defaults to ghcr.io, repository defaults to the current repo

- run: echo ${{ steps.image-name.outputs.name }}
  # e.g. ghcr.io/ajakhotia/nioc/ubuntu-22-04/linux-clang-22/deploy
```

Real-world usage:
[nioc/.github/workflows/docker-image.yaml](https://github.com/ajakhotia/nioc/blob/main/.github/workflows/docker-image.yaml)

### ✨ normalize

Sanitises an arbitrary string into a form safe for Docker tags and image-path components. It is
the building block that `oci-compliant-image-name` uses on each part.

```yaml
- name: normalizer
  id: normalizer-id
  uses: ajakhotia/infraCommons/.github/actions/normalize@main
  with:
    string: ${{ inputs.target-stage-id }}

- run: echo ${{ steps.normalizer-id.outputs.string }}
```

Real-world usage:
[oci-compliant-image-name/action.yaml](.github/actions/oci-compliant-image-name/action.yaml)

### 🔄 docker-pull-retag-push

Pulls a public image, retags it, and pushes it to your registry. It is the primitive behind the
snapshot workflows below, and useful anywhere you want an upstream image mirrored under your
own control.

```yaml
- name: cache-ubuntu
  uses: ajakhotia/infraCommons/.github/actions/docker-pull-retag-push@main
  with:
    source: ubuntu:24.04
    destination: ghcr.io/ajakhotia/infracommons/monthly/ubuntu:24.04
```

Real-world usage:
[docker-snapshot-monthly.yaml](.github/workflows/docker-snapshot-monthly.yaml)

---

## 📌 Pinned Docker Image Snapshots

`FROM ubuntu:24.04` looks pinned but isn't: the tag mutates upstream every few days, and each
mutation invalidates every layer built on top of it, forcing full rebuilds for no benefit
and letting image digests change quietly between CI runs. infraCommons runs scheduled workflows that
re-publish popular base images to a fixed address on a fixed cadence:

```
ghcr.io/ajakhotia/infracommons/<cadence>/<image>:<tag>
```

| Cadence   | Schedule                             |
|-----------|--------------------------------------|
| `weekly`  | Every Sunday at 00:00 UTC            |
| `monthly` | First day of each month at 00:00 UTC |

Currently snapshotted: `ubuntu:rolling`, `ubuntu:latest`, `ubuntu:24.04`, `ubuntu:22.04`; see
the [snapshot workflows](.github/workflows) for the live matrix.

```dockerfile
FROM ghcr.io/ajakhotia/infracommons/monthly/ubuntu:24.04
```

Your base image now changes exactly once a month, on a date you can predict, while still
receiving upstream updates. Want another image or cadence? Open an
[issue](https://github.com/ajakhotia/infraCommons/issues) or send a PR updating the workflow
matrix.

---

## 🔌 Using infraCommons in your project

infraCommons is consumed as a **git submodule**. There is no package manager and no version
solver, just a pinned commit you control and update on your schedule:

```bash
git submodule add https://github.com/ajakhotia/infraCommons.git external/infraCommons
git submodule update --init
```

Then wire in the pieces you want. [nioc](https://github.com/ajakhotia/nioc) is the complete
working reference for all of the below.

**1. Include the CMake utilities** in your root `CMakeLists.txt` and create the quality targets:

```cmake
if(PROJECT_IS_TOP_LEVEL)
  include(external/infraCommons/cmake/utilities/capnprotoGenerate.cmake)
  include(external/infraCommons/cmake/utilities/clangFormat.cmake)
  include(external/infraCommons/cmake/utilities/clangTidy.cmake)
  include(external/infraCommons/cmake/utilities/exportedTargets.cmake)
  include(external/infraCommons/cmake/utilities/requireArguments.cmake)

  add_clang_format(TARGET clangFormat VERSION 22)
  add_clang_tidy(TARGET clangTidy VERSION 22)
endif()

add_subdirectory(...)   # your modules

if(TARGET clangTidy)
  add_clang_tidy_build_dependencies(clangTidy)   # after all add_subdirectory calls
endif()
```

**2. Symlink the code-quality configs** from your repository root:

```bash
ln -s external/infraCommons/tools/clang-format-22        .clang-format
ln -s external/infraCommons/tools/clang-tidy-22          .clang-tidy
ln -s external/infraCommons/tools/shfmt-3.8-editorconfig .editorconfig
```

**3. Configure with a pinned toolchain:**

```bash
cmake -G Ninja -S . -B build \
  --toolchain external/infraCommons/cmake/toolchains/linux-clang-22.cmake
```

**4. Reference the composite actions** in your workflows
([example](https://github.com/ajakhotia/nioc/blob/main/.github/workflows/docker-image.yaml)):

```yaml
- uses: ajakhotia/infraCommons/.github/actions/docker-typical-build-push@main
```

**5. Base your Dockerfiles on a pinned snapshot:**

```dockerfile
FROM ghcr.io/ajakhotia/infracommons/monthly/ubuntu:24.04
```

From here on, pulling improvements is one command in each consumer:

```bash
git submodule update --remote external/infraCommons
```

---

## 📜 License

[MIT](LICENSE). © Anurag Jakhotia. Use it, fork it, ship with it.
