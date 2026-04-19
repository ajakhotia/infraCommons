set(CMAKE_HOST_SYSTEM_NAME "Linux")
set(CMAKE_C_COMPILER /usr/bin/clang)
set(CMAKE_CXX_COMPILER /usr/bin/clang++)

# apt.llvm.org ships flang only as per-major packages whose libmlir-N runtime
# is mutually exclusive, so the image carries a single flang version. Fortran
# ABI to C/C++ (BIND(C) / name-mangling) is independent of the clang major,
# so pairing any clang with flang-21 is safe. Add the flang-21 runtime dir to
# the linker path/rpath so clang-driven links of mixed C++/Fortran targets
# resolve libFortranRuntime and friends at link and load time.
set(CMAKE_Fortran_COMPILER /usr/bin/flang-21)
set(CMAKE_EXE_LINKER_FLAGS "-L/usr/lib/llvm-21/lib -Wl,-rpath,/usr/lib/llvm-21/lib")

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

    # The fallback clang++-N would otherwise pick up libstdc++ from the newest
    # GCC install on the system. If that GCC is too new for this clang++-N to
    # parse (e.g. clang-21 cannot handle libstdc++-16 constructs in the C++17
    # mode used by cudafe++), cudafe++ fails during CUDA compiler identification.
    # Pin clang++'s libstdc++ lookup to an installed GCC dir within CUDA's
    # supported range, probing downward from CUDA_MAX_GNU.
    set(CUDA_HOST_GCC_DIR "")
    set(GCC_PROBE ${CUDA_MAX_GNU})
    while(GCC_PROBE GREATER_EQUAL CUDA_MIN_GNU)
      if(IS_DIRECTORY "/usr/lib/gcc/x86_64-linux-gnu/${GCC_PROBE}")
        set(CUDA_HOST_GCC_DIR "/usr/lib/gcc/x86_64-linux-gnu/${GCC_PROBE}")
        break()
      endif()
      math(EXPR GCC_PROBE "${GCC_PROBE} - 1")
    endwhile()
    if(CUDA_HOST_GCC_DIR)
      message(STATUS "Pinning CUDA host clang++ libstdc++ to ${CUDA_HOST_GCC_DIR} (gcc-${GCC_PROBE})")
      set(CMAKE_CUDA_FLAGS_INIT "${CMAKE_CUDA_FLAGS_INIT} -Xcompiler=--gcc-install-dir=${CUDA_HOST_GCC_DIR}")
    else()
      message(WARNING "*** No GCC install dir in CUDA ${CUDA_MAJOR} supported range [${CUDA_MIN_GNU}, ${CUDA_MAX_GNU}] found under /usr/lib/gcc/x86_64-linux-gnu/. CUDA host ${CUDA_HOST_CANDIDATE} will use libstdc++ from the newest installed GCC, which may be too new to parse. ***")
    endif()
  else()
    message(WARNING "*** No clang++ in CUDA ${CUDA_MAJOR} supported range [${CUDA_MIN_CLANG}, ${CUDA_MAX_CLANG}] is installed. Falling back to ${CMAKE_CXX_COMPILER} (major ${CLANG_MAJOR}) with -allow-unsupported-compiler. CUDA TUs may miscompile silently — install an in-range clang++-N to silence this. ***")
    set(CMAKE_CUDA_HOST_COMPILER ${CMAKE_CXX_COMPILER})
    set(CMAKE_CUDA_FLAGS_INIT "${CMAKE_CUDA_FLAGS_INIT} -allow-unsupported-compiler")
  endif()
endif()
