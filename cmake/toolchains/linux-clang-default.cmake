set(CMAKE_HOST_SYSTEM_NAME "Linux")
set(CMAKE_C_COMPILER /usr/bin/clang)
set(CMAKE_CXX_COMPILER /usr/bin/clang++)
set(CMAKE_Fortran_COMPILER /usr/bin/flang)

execute_process(
    COMMAND ${CMAKE_C_COMPILER} -dumpversion
    OUTPUT_VARIABLE CLANG_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
string(REGEX MATCH "^[0-9]+" CLANG_MAJOR "${CLANG_VERSION}")

include(${CMAKE_CURRENT_LIST_DIR}/cuda.cmake)

# Pair NVCC with a clang++ that the active CUDA toolkit supports. If the
# host clang++ is in range, use it directly. Otherwise probe
# /usr/bin/clang++-N for the closest in-range version — downward from the
# max when the host is too new, upward from the min when too old — and use
# that only as the CUDA host compiler. If nothing in range is installed,
# fall back to the host compiler with -allow-unsupported-compiler and warn.
if(CLANG_MAJOR GREATER_EQUAL CUDA_MIN_CLANG AND CLANG_MAJOR LESS_EQUAL CUDA_MAX_CLANG)
  set(CMAKE_CUDA_HOST_COMPILER ${CMAKE_CXX_COMPILER})
else()
  set(CUDA_HOST_CANDIDATE "")
  if(CLANG_MAJOR GREATER CUDA_MAX_CLANG)
    set(PROBE_VERSION ${CUDA_MAX_CLANG})
    while(PROBE_VERSION GREATER_EQUAL CUDA_MIN_CLANG)
      if(EXISTS "/usr/bin/clang++-${PROBE_VERSION}")
        set(CUDA_HOST_CANDIDATE "/usr/bin/clang++-${PROBE_VERSION}")
        break()
      endif()
      math(EXPR PROBE_VERSION "${PROBE_VERSION} - 1")
    endwhile()
  else()
    set(PROBE_VERSION ${CUDA_MIN_CLANG})
    while(PROBE_VERSION LESS_EQUAL CUDA_MAX_CLANG)
      if(EXISTS "/usr/bin/clang++-${PROBE_VERSION}")
        set(CUDA_HOST_CANDIDATE "/usr/bin/clang++-${PROBE_VERSION}")
        break()
      endif()
      math(EXPR PROBE_VERSION "${PROBE_VERSION} + 1")
    endwhile()
  endif()

  if(CUDA_HOST_CANDIDATE)
    message(STATUS "Host clang++ ${CLANG_MAJOR} outside CUDA ${CUDA_MAJOR} range [${CUDA_MIN_CLANG}, ${CUDA_MAX_CLANG}] — using ${CUDA_HOST_CANDIDATE} as CUDA host compiler")
    set(CMAKE_CUDA_HOST_COMPILER ${CUDA_HOST_CANDIDATE})
  else()
    message(WARNING "*** No clang++ in CUDA ${CUDA_MAJOR} supported range [${CUDA_MIN_CLANG}, ${CUDA_MAX_CLANG}] is installed. Falling back to ${CMAKE_CXX_COMPILER} (major ${CLANG_MAJOR}) with -allow-unsupported-compiler. CUDA TUs may miscompile silently — install an in-range clang++-N to silence this. ***")
    set(CMAKE_CUDA_HOST_COMPILER ${CMAKE_CXX_COMPILER})
    set(CMAKE_CUDA_FLAGS_INIT "${CMAKE_CUDA_FLAGS_INIT} -allow-unsupported-compiler")
  endif()
endif()
