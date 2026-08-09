include(${CMAKE_CURRENT_LIST_DIR}/requireArguments.cmake)

## Records the names of the cache entries the caller handed this build tree, into
## OUTPUT_VARIABLE as a persistent INTERNAL cache entry.
##
## Usage:
##   capture_user_cache_entries(OUTPUT_VARIABLE <var>)
##
## Call this before project(). Provenance rests on two structural facts of the cache, never on
## help-string text, which CMake rewords between versions:
##   1. On the first configure of a fresh build tree, before project() runs, the cache holds
##      exactly what the caller supplied (-D definitions, a preset's cacheVariables, -C files,
##      --toolchain) plus CMake's own bookkeeping, and the bookkeeping is typed INTERNAL or
##      STATIC. Every entry outside those types is therefore the caller's and is recorded.
##   2. An untyped -D definition enters the cache with type UNINITIALIZED, which no project
##      declaration produces, so definitions added on later configures are unioned in on every
##      run. A typed -D added to an already-configured tree is indistinguishable from a project
##      declaration and is the one unsupported corner; reconfigure fresh for that.
## Entries join the recorded set when first seen and never leave, mirroring cache semantics. A
## tree configured before this mechanism existed has a polluted cache and no recorded set; that
## case aborts with instructions rather than guessing.
function(capture_user_cache_entries)
  set(OPTIONS_ARGUMENTS "")
  set(SINGLE_VALUE_ARGUMENTS OUTPUT_VARIABLE)
  set(MULTI_VALUE_ARGUMENTS "")

  cmake_parse_arguments("CUCE_PARAM"
    "${OPTIONS_ARGUMENTS}"
    "${SINGLE_VALUE_ARGUMENTS}"
    "${MULTI_VALUE_ARGUMENTS}"
    ${ARGN})

  require_arguments(PREFIX CUCE_PARAM ARGUMENTS OUTPUT_VARIABLE)

  get_cmake_property(CUCE_CACHE_ENTRIES CACHE_VARIABLES)

  if(DEFINED CACHE{${CUCE_PARAM_OUTPUT_VARIABLE}})
    set(CUCE_NAMES ${${CUCE_PARAM_OUTPUT_VARIABLE}})
  elseif(DEFINED CACHE{CMAKE_CACHEFILE_DIR})
    message(FATAL_ERROR
      "capture_user_cache_entries: this build tree was configured before caller cache entries "
      "were recorded, so they can no longer be told apart from the project's own. Configure "
      "into a fresh build tree, or delete CMakeCache.txt first.")
  else()
    set(CUCE_NAMES "")

    foreach(CUCE_NAME IN LISTS CUCE_CACHE_ENTRIES)
      get_property(CUCE_TYPE CACHE ${CUCE_NAME} PROPERTY TYPE)

      if(NOT CUCE_TYPE STREQUAL "INTERNAL" AND NOT CUCE_TYPE STREQUAL "STATIC")
        list(APPEND CUCE_NAMES ${CUCE_NAME})
      endif()
    endforeach()
  endif()

  foreach(CUCE_NAME IN LISTS CUCE_CACHE_ENTRIES)
    get_property(CUCE_TYPE CACHE ${CUCE_NAME} PROPERTY TYPE)

    if(CUCE_TYPE STREQUAL "UNINITIALIZED")
      list(APPEND CUCE_NAMES ${CUCE_NAME})
    endif()
  endforeach()

  list(REMOVE_DUPLICATES CUCE_NAMES)
  list(SORT CUCE_NAMES)

  set(${CUCE_PARAM_OUTPUT_VARIABLE} "${CUCE_NAMES}" CACHE INTERNAL
    "Names of user-specified cache entries, captured before project()" FORCE)
endfunction()

## Composes the initial-cache definition list (-D<name>:<type>=<value>) that a super build
## forwards to the configure step of its ExternalProject children.
##
## Usage:
##   compose_forwarded_cache_args(
##     OUTPUT_VARIABLE <var>
##     [LIST_SEPARATOR <sep>]
##     [FORWARD_VARIABLES <name1> <name2> ...]
##     [USER_ENTRIES <name1> <name2> ...]
##     [EXCLUDE_PREFIXES <prefix1> <prefix2> ...])
##
## Three sources feed the list, in order:
##   1. FORWARD_VARIABLES: the effective value of each named variable at the call site. This is
##      the super build's policy toward its children; compose a value (e.g. CMAKE_PREFIX_PATH)
##      by setting the variable before calling. Unset and empty variables are skipped.
##   2. USER_ENTRIES: names previously recorded by capture_user_cache_entries, forwarded at
##      their current cache value. Names matching any EXCLUDE_PREFIXES entry are dropped: a
##      super build passes its own option namespace here, because those names are its interface,
##      consumed at its level, and are never the children's business.
##   3. Two names with documented special semantics are swept explicitly as a backstop:
##      CMAKE_TOOLCHAIN_FILE when one is in use, and a caller-chosen CMAKE_INSTALL_PREFIX
##      (CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT distinguishes it from the platform
##      default). Everything else in the cache is a derived conclusion (configure probes,
##      project internals) that each child must re-derive for itself and is never forwarded.
##
## A name covered by an earlier source is excluded from the later ones, so a policy
## composition stays authoritative for its own name. List values are escaped with
## LIST_SEPARATOR, which defaults to the standard CMake separator ";" (making the escape a
## no-op); pass the in-band separator paired with the LIST_SEPARATOR option of
## ExternalProject_Add so the child's configure re-expands escaped values into lists.
function(compose_forwarded_cache_args)
  set(OPTIONS_ARGUMENTS "")
  set(SINGLE_VALUE_ARGUMENTS OUTPUT_VARIABLE LIST_SEPARATOR)
  set(MULTI_VALUE_ARGUMENTS FORWARD_VARIABLES USER_ENTRIES EXCLUDE_PREFIXES)

  cmake_parse_arguments("CFCA_PARAM"
    "${OPTIONS_ARGUMENTS}"
    "${SINGLE_VALUE_ARGUMENTS}"
    "${MULTI_VALUE_ARGUMENTS}"
    ${ARGN})

  require_arguments(PREFIX CFCA_PARAM ARGUMENTS OUTPUT_VARIABLE)

  if(NOT CFCA_PARAM_LIST_SEPARATOR)
    set(CFCA_PARAM_LIST_SEPARATOR ";")
  endif()

  set(CFCA_RESULT "")
  set(CFCA_FORWARDED_NAMES "")

  foreach(CFCA_NAME IN LISTS CFCA_PARAM_FORWARD_VARIABLES)
    if(NOT DEFINED ${CFCA_NAME} OR "${${CFCA_NAME}}" STREQUAL "")
      continue()
    endif()

    set(CFCA_TYPE "STRING")
    get_property(CFCA_CACHE_TYPE CACHE ${CFCA_NAME} PROPERTY TYPE)

    if(CFCA_CACHE_TYPE AND NOT CFCA_CACHE_TYPE STREQUAL "UNINITIALIZED")
      set(CFCA_TYPE ${CFCA_CACHE_TYPE})
    endif()

    string(REPLACE ";" "${CFCA_PARAM_LIST_SEPARATOR}" CFCA_VALUE "${${CFCA_NAME}}")
    list(APPEND CFCA_RESULT "-D${CFCA_NAME}:${CFCA_TYPE}=${CFCA_VALUE}")
    list(APPEND CFCA_FORWARDED_NAMES ${CFCA_NAME})
  endforeach()

  set(CFCA_USER_NAMES ${CFCA_PARAM_USER_ENTRIES})
  list(REMOVE_DUPLICATES CFCA_USER_NAMES)

  foreach(CFCA_NAME IN LISTS CFCA_USER_NAMES)
    if(CFCA_NAME IN_LIST CFCA_FORWARDED_NAMES)
      continue()
    endif()

    set(CFCA_EXCLUDED FALSE)

    foreach(CFCA_PREFIX IN LISTS CFCA_PARAM_EXCLUDE_PREFIXES)
      string(FIND "${CFCA_NAME}" "${CFCA_PREFIX}" CFCA_PREFIX_POSITION)

      if(CFCA_PREFIX_POSITION EQUAL 0)
        set(CFCA_EXCLUDED TRUE)
        break()
      endif()
    endforeach()

    if(CFCA_EXCLUDED)
      continue()
    endif()

    get_property(CFCA_CACHE_VALUE CACHE ${CFCA_NAME} PROPERTY VALUE)

    if("${CFCA_CACHE_VALUE}" STREQUAL "")
      continue()
    endif()

    get_property(CFCA_CACHE_TYPE CACHE ${CFCA_NAME} PROPERTY TYPE)

    if(NOT CFCA_CACHE_TYPE OR CFCA_CACHE_TYPE STREQUAL "UNINITIALIZED")
      set(CFCA_CACHE_TYPE "STRING")
    endif()

    string(REPLACE ";" "${CFCA_PARAM_LIST_SEPARATOR}" CFCA_VALUE "${CFCA_CACHE_VALUE}")
    list(APPEND CFCA_RESULT "-D${CFCA_NAME}:${CFCA_CACHE_TYPE}=${CFCA_VALUE}")
    list(APPEND CFCA_FORWARDED_NAMES ${CFCA_NAME})
  endforeach()

  # A toolchain file given via --toolchain or a preset's toolchainFile lands in the cache with
  # its own help string rather than the command-line marker, so sweep it up explicitly.
  if(CMAKE_TOOLCHAIN_FILE AND NOT "CMAKE_TOOLCHAIN_FILE" IN_LIST CFCA_FORWARDED_NAMES)
    list(APPEND CFCA_RESULT "-DCMAKE_TOOLCHAIN_FILE:FILEPATH=${CMAKE_TOOLCHAIN_FILE}")
  endif()

  # Newer CMake assigns CMAKE_INSTALL_PREFIX its own descriptive help string even when the value
  # arrives via -D or a preset's cacheVariables, so the command-line marker misses it and the
  # children would fall back to the platform default prefix. A caller-chosen prefix is
  # distinguished from that default by CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT, so sweep it
  # up explicitly.
  if(CMAKE_INSTALL_PREFIX
      AND NOT CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT
      AND NOT "CMAKE_INSTALL_PREFIX" IN_LIST CFCA_FORWARDED_NAMES)
    list(APPEND CFCA_RESULT "-DCMAKE_INSTALL_PREFIX:PATH=${CMAKE_INSTALL_PREFIX}")
  endif()

  set(${CFCA_PARAM_OUTPUT_VARIABLE} "${CFCA_RESULT}" PARENT_SCOPE)
endfunction()
