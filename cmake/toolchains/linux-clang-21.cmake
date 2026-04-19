set(CMAKE_HOST_SYSTEM_NAME "Linux")
set(CMAKE_C_COMPILER /usr/bin/clang-21)
set(CMAKE_CXX_COMPILER /usr/bin/clang++-21)
set(CMAKE_Fortran_COMPILER /usr/bin/flang-21)
set(CMAKE_EXE_LINKER_FLAGS "-L/usr/lib/llvm-21/lib -Wl,-rpath,/usr/lib/llvm-21/lib")

include(${CMAKE_CURRENT_LIST_DIR}/cuda.cmake)

if(21 LESS CUDA_MIN_CLANG OR 21 GREATER CUDA_MAX_CLANG)
  message(FATAL_ERROR "Pinned clang++-21 is outside CUDA ${CUDA_MAJOR}'s supported clang++ range [${CUDA_MIN_CLANG}, ${CUDA_MAX_CLANG}]. Pick a different host toolchain or install a compatible CUDA major.")
endif()

set(CMAKE_CUDA_HOST_COMPILER ${CMAKE_CXX_COMPILER})
