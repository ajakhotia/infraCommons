# Discover NVCC via NVIDIA's /usr/local/cuda symlink and look up the
# host-compiler range supported by the installed CUDA toolkit major.
#
# Sets:
#   CMAKE_CUDA_COMPILER       — path to nvcc
#   CMAKE_CUDA_ARCHITECTURES  — SMs targeted by robotFarm (75, 80)
#   CUDA_MAJOR                — major version parsed from `nvcc --version`
#   CUDA_MIN_GNU,   CUDA_MAX_GNU      — supported g++ major range
#   CUDA_MIN_CLANG, CUDA_MAX_CLANG    — supported clang++ major range
#
# Errors out via FATAL_ERROR if the installed CUDA major has no entry in the
# table below — bumping the toolkit requires adding a new branch here.
#
# Source: https://docs.nvidia.com/cuda/cuda-installation-guide-linux/

set(CMAKE_CUDA_COMPILER /usr/local/cuda/bin/nvcc)
set(CMAKE_CUDA_ARCHITECTURES 75;80)

execute_process(
    COMMAND ${CMAKE_CUDA_COMPILER} --version
    OUTPUT_VARIABLE NVCC_VERSION_OUTPUT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
string(REGEX MATCH "release ([0-9]+)" _ "${NVCC_VERSION_OUTPUT}")
set(CUDA_MAJOR "${CMAKE_MATCH_1}")

if(CUDA_MAJOR EQUAL 13)
  set(CUDA_MIN_GNU 6)
  set(CUDA_MAX_GNU 15)
  set(CUDA_MIN_CLANG 7)
  set(CUDA_MAX_CLANG 21)
else()
  message(FATAL_ERROR "Unknown CUDA major '${CUDA_MAJOR}' from ${CMAKE_CUDA_COMPILER} — add its supported host-compiler ranges to ${CMAKE_CURRENT_LIST_FILE}. See https://docs.nvidia.com/cuda/cuda-installation-guide-linux/")
endif()
