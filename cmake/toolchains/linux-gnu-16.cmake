set(CMAKE_HOST_SYSTEM_NAME "Linux")
set(CMAKE_C_COMPILER /usr/bin/gcc-16)
set(CMAKE_CXX_COMPILER /usr/bin/g++-16)
set(CMAKE_Fortran_COMPILER /usr/bin/gfortran-16)

include(${CMAKE_CURRENT_LIST_DIR}/cuda.cmake)

# gcc-16 is above CUDA 13's supported g++ max (${CUDA_MAX_GNU}). Use it as
# the CUDA host compiler anyway and pass NVCC's override so it doesn't refuse
# on version alone.
set(CMAKE_CUDA_HOST_COMPILER ${CMAKE_CXX_COMPILER})
set(CMAKE_CUDA_FLAGS_INIT "${CMAKE_CUDA_FLAGS_INIT} -allow-unsupported-compiler")
