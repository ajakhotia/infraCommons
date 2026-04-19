set(CMAKE_HOST_SYSTEM_NAME "Linux")
set(CMAKE_C_COMPILER /usr/bin/gcc)
set(CMAKE_CXX_COMPILER /usr/bin/g++)
set(CMAKE_Fortran_COMPILER /usr/bin/gfortran)

execute_process(
    COMMAND ${CMAKE_C_COMPILER} -dumpversion
    OUTPUT_VARIABLE GCC_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
string(REGEX MATCH "^[0-9]+" GCC_MAJOR "${GCC_VERSION}")

include(${CMAKE_CURRENT_LIST_DIR}/cuda.cmake)

# Pair NVCC with a g++ that the active CUDA toolkit supports. If the host
# g++ is in range, use it directly. Otherwise probe /usr/bin/g++-N for the
# closest in-range version — downward from the max when the host is too
# new, upward from the min when too old — and use that only as the CUDA
# host compiler. If nothing in range is installed, fall back to the host
# compiler with -allow-unsupported-compiler and warn.
if(GCC_MAJOR GREATER_EQUAL CUDA_MIN_GNU AND GCC_MAJOR LESS_EQUAL CUDA_MAX_GNU)
  set(CMAKE_CUDA_HOST_COMPILER ${CMAKE_CXX_COMPILER})
else()
  set(CUDA_HOST_CANDIDATE "")
  if(GCC_MAJOR GREATER CUDA_MAX_GNU)
    set(PROBE_VERSION ${CUDA_MAX_GNU})
    while(PROBE_VERSION GREATER_EQUAL CUDA_MIN_GNU)
      if(EXISTS "/usr/bin/g++-${PROBE_VERSION}")
        set(CUDA_HOST_CANDIDATE "/usr/bin/g++-${PROBE_VERSION}")
        break()
      endif()
      math(EXPR PROBE_VERSION "${PROBE_VERSION} - 1")
    endwhile()
  else()
    set(PROBE_VERSION ${CUDA_MIN_GNU})
    while(PROBE_VERSION LESS_EQUAL CUDA_MAX_GNU)
      if(EXISTS "/usr/bin/g++-${PROBE_VERSION}")
        set(CUDA_HOST_CANDIDATE "/usr/bin/g++-${PROBE_VERSION}")
        break()
      endif()
      math(EXPR PROBE_VERSION "${PROBE_VERSION} + 1")
    endwhile()
  endif()

  if(CUDA_HOST_CANDIDATE)
    message(STATUS "Host g++ ${GCC_MAJOR} outside CUDA ${CUDA_MAJOR} range [${CUDA_MIN_GNU}, ${CUDA_MAX_GNU}] — using ${CUDA_HOST_CANDIDATE} as CUDA host compiler")
    set(CMAKE_CUDA_HOST_COMPILER ${CUDA_HOST_CANDIDATE})
  else()
    message(WARNING "*** No g++ in CUDA ${CUDA_MAJOR} supported range [${CUDA_MIN_GNU}, ${CUDA_MAX_GNU}] is installed. Falling back to ${CMAKE_CXX_COMPILER} (major ${GCC_MAJOR}) with -allow-unsupported-compiler. CUDA TUs may miscompile silently — install an in-range g++-N to silence this. ***")
    set(CMAKE_CUDA_HOST_COMPILER ${CMAKE_CXX_COMPILER})
    set(CMAKE_CUDA_FLAGS_INIT "${CMAKE_CUDA_FLAGS_INIT} -allow-unsupported-compiler")
  endif()
endif()
