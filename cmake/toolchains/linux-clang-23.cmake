set(CMAKE_HOST_SYSTEM_NAME "Linux")
set(CMAKE_C_COMPILER /usr/bin/clang-23)
set(CMAKE_CXX_COMPILER /usr/bin/clang++-23)
set(CMAKE_Fortran_COMPILER /usr/bin/flang-21)
set(CMAKE_EXE_LINKER_FLAGS "-L/usr/lib/llvm-21/lib -Wl,-rpath,/usr/lib/llvm-21/lib")

include(${CMAKE_CURRENT_LIST_DIR}/cuda.cmake)

# clang-23 is above CUDA ${CUDA_MAJOR}'s supported clang max (${CUDA_MAX_CLANG}).
# Pin the CUDA host compiler to clang++-21 — the newest in-range clang —
# so NVCC-invoked host compiles of CUDA TUs succeed.
set(CMAKE_CUDA_HOST_COMPILER /usr/bin/clang++-21)
