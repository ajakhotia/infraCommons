set(CMAKE_HOST_SYSTEM_NAME "Linux")
set(CMAKE_C_COMPILER /usr/bin/gcc-14)
set(CMAKE_CXX_COMPILER /usr/bin/g++-14)
set(CMAKE_Fortran_COMPILER /usr/bin/gfortran-14)

include(${CMAKE_CURRENT_LIST_DIR}/cuda.cmake)

if(14 LESS CUDA_MIN_GNU OR 14 GREATER CUDA_MAX_GNU)
  message(FATAL_ERROR "Pinned g++-14 is outside CUDA ${CUDA_MAJOR}'s supported g++ range [${CUDA_MIN_GNU}, ${CUDA_MAX_GNU}]. Pick a different host toolchain or install a compatible CUDA major.")
endif()

set(CMAKE_CUDA_HOST_COMPILER ${CMAKE_CXX_COMPILER})
