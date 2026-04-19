set(CMAKE_HOST_SYSTEM_NAME "Linux")
set(CMAKE_C_COMPILER /usr/bin/clang-23)
set(CMAKE_CXX_COMPILER /usr/bin/clang++-23)
set(CMAKE_Fortran_COMPILER /usr/bin/flang-22)
set(CMAKE_EXE_LINKER_FLAGS "-L/usr/lib/llvm-22/lib -Wl,-rpath,/usr/lib/llvm-22/lib")

include(${CMAKE_CURRENT_LIST_DIR}/cuda.cmake)

# clang-23 is above CUDA 13's supported clang max (${CUDA_MAX_CLANG}). Use it
# as the CUDA host compiler anyway and pass NVCC's override so it doesn't
# refuse on version alone.
set(CMAKE_CUDA_HOST_COMPILER ${CMAKE_CXX_COMPILER})
set(CMAKE_CUDA_FLAGS_INIT "${CMAKE_CUDA_FLAGS_INIT} -allow-unsupported-compiler")
