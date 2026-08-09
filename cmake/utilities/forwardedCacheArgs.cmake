include(${CMAKE_CURRENT_LIST_DIR}/requireArguments.cmake)

## Records the names of every cache entry the user defined on the configure command line, which
## is also how a preset's cacheVariables arrive, into OUTPUT_VARIABLE as a persistent INTERNAL
## cache entry.
##
## Usage:
##   capture_user_cache_entries(OUTPUT_VARIABLE <var>)
##
## Call this before project(). Command-line entries are identified by the help string CMake
## assigns them, and that marker is fragile: platform initialization inside project() and any
## later set(<name> ... CACHE <type> <doc>) replaces the help string of an untyped -D entry,
## silently removing it from the identifiable set. The replaced help strings also persist into
## reconfigures, so the capture unions with its previous result to stay deterministic across
## runs: entries join the set when first seen and never leave, mirroring cache semantics.
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

  set(CUCE_NAMES ${${CUCE_PARAM_OUTPUT_VARIABLE}})
  get_cmake_property(CUCE_CACHE_ENTRIES CACHE_VARIABLES)

  foreach(CUCE_NAME IN LISTS CUCE_CACHE_ENTRIES)
    get_property(CUCE_HELP CACHE ${CUCE_NAME} PROPERTY HELPSTRING)

    if(CUCE_HELP STREQUAL "No help, variable specified on the command line.")
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
##     [USER_ENTRIES <name1> <name2> ...])
##
## Three sources feed the list, in order:
##   1. FORWARD_VARIABLES: the effective value of each named variable at the call site. This is
##      the super build's policy toward its children; compose a value (e.g. CMAKE_PREFIX_PATH)
##      by setting the variable before calling. Unset and empty variables are skipped.
##   2. USER_ENTRIES: names previously recorded by capture_user_cache_entries, forwarded at
##      their current cache value. This is the reliable route for user intent; the help-string
##      sweep below degrades after project() runs (see capture_user_cache_entries).
##   3. Every cache entry still carrying the command-line help-string marker, plus
##      CMAKE_TOOLCHAIN_FILE when one is in use. Everything else in the cache is a derived
##      conclusion (configure probes, project internals) that each child must re-derive for
##      itself and is therefore never forwarded.
##
## A name covered by an earlier source is excluded from the later ones, so a policy
## composition stays authoritative for its own name. List values are escaped with
## LIST_SEPARATOR, which defaults to the standard CMake separator ";" (making the escape a
## no-op); pass the in-band separator paired with the LIST_SEPARATOR option of
## ExternalProject_Add so the child's configure re-expands escaped values into lists.
function(compose_forwarded_cache_args)
  set(OPTIONS_ARGUMENTS "")
  set(SINGLE_VALUE_ARGUMENTS OUTPUT_VARIABLE LIST_SEPARATOR)
  set(MULTI_VALUE_ARGUMENTS FORWARD_VARIABLES USER_ENTRIES)

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

  get_cmake_property(CFCA_CACHE_ENTRIES CACHE_VARIABLES)
  set(CFCA_USER_NAMES ${CFCA_PARAM_USER_ENTRIES})

  foreach(CFCA_NAME IN LISTS CFCA_CACHE_ENTRIES)
    get_property(CFCA_HELP CACHE ${CFCA_NAME} PROPERTY HELPSTRING)

    if(CFCA_HELP STREQUAL "No help, variable specified on the command line.")
      list(APPEND CFCA_USER_NAMES ${CFCA_NAME})
    endif()
  endforeach()

  list(REMOVE_DUPLICATES CFCA_USER_NAMES)

  foreach(CFCA_NAME IN LISTS CFCA_USER_NAMES)
    if(CFCA_NAME IN_LIST CFCA_FORWARDED_NAMES)
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

  set(${CFCA_PARAM_OUTPUT_VARIABLE} "${CFCA_RESULT}" PARENT_SCOPE)
endfunction()
