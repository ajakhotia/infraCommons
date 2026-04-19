set(CMAKE_HOST_SYSTEM_NAME "Linux")
set(CMAKE_C_COMPILER /usr/bin/gcc-15)
set(CMAKE_CXX_COMPILER /usr/bin/g++-15)
set(CMAKE_Fortran_COMPILER /usr/bin/gfortran-15)

set(CMAKE_CUDA_COMPILER /usr/local/cuda/bin/nvcc)
set(CMAKE_CUDA_ARCHITECTURES 75;80)
set(CMAKE_CUDA_HOST_COMPILER ${CMAKE_CXX_COMPILER})
