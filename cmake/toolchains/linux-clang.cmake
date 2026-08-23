set(CMAKE_HOST_SYSTEM_NAME "Linux")
set(CMAKE_C_COMPILER /usr/bin/clang)
set(CMAKE_CXX_COMPILER /usr/bin/clang++)
set(CMAKE_Fortran_COMPILER /usr/bin/flang)

find_program(NVCC_EXECUTABLE nvcc HINTS ENV CUDA_HOME ENV CUDA_PATH /usr/local/cuda PATH_SUFFIXES bin)

if(NVCC_EXECUTABLE)
  set(CMAKE_CUDA_COMPILER "${NVCC_EXECUTABLE}")
  # Every SASS target CUDA 13.3 supports (nvcc --list-gpu-arch): the products prefer the
  # maximum fat binary, and a build wanting a narrower set overrides this. Spelled out
  # rather than the special value "all" because OpenCV rejects the special values.
  set(CMAKE_CUDA_ARCHITECTURES 75;80;86;87;88;89;90;100;103;110;120;121)
  set(CMAKE_CUDA_HOST_COMPILER ${CMAKE_CXX_COMPILER})
  set(CMAKE_CUDA_FLAGS_INIT "${CMAKE_CUDA_FLAGS_INIT} -allow-unsupported-compiler")
endif()
