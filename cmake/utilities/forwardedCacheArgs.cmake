include(${CMAKE_CURRENT_LIST_DIR}/requireArguments.cmake)

## Composes the initial-cache definition list (-D<name>:<type>=<value>) that a super build
## forwards to the configure step of its ExternalProject children.
##
## Usage:
##   compose_forwarded_cache_args(
##     OUTPUT_VARIABLE <var>
##     LIST_SEPARATOR <sep>
##     [FORWARD_VARIABLES <name1> <name2> ...])
##
## Two sources feed the list, in order:
##   1. FORWARD_VARIABLES: the effective value of each named variable at the call site. This is
##      the super build's policy toward its children; compose a value (e.g. CMAKE_PREFIX_PATH)
##      by setting the variable before calling. Unset and empty variables are skipped.
##   2. Every cache entry the user defined on the configure command line, which is also how a
##      preset's cacheVariables arrive, plus CMAKE_TOOLCHAIN_FILE when one is in use. Cache
##      entries whose help string marks them as command-line definitions are user intent;
##      everything else in the cache is a derived conclusion (configure probes, project
##      internals) that each child must re-derive for itself and is therefore never forwarded.
##
## A name covered by FORWARD_VARIABLES is excluded from the user-entry sweep, so a policy
## composition stays authoritative for its own name. Values are escaped with LIST_SEPARATOR;
## pair the same separator with the LIST_SEPARATOR option of ExternalProject_Add so the child's
## configure re-expands them into lists.
function(compose_forwarded_cache_args)
  set(OPTIONS_ARGUMENTS "")
  set(SINGLE_VALUE_ARGUMENTS OUTPUT_VARIABLE LIST_SEPARATOR)
  set(MULTI_VALUE_ARGUMENTS FORWARD_VARIABLES)

  cmake_parse_arguments("CFCA_PARAM"
    "${OPTIONS_ARGUMENTS}"
    "${SINGLE_VALUE_ARGUMENTS}"
    "${MULTI_VALUE_ARGUMENTS}"
    ${ARGN})

  require_arguments(PREFIX CFCA_PARAM ARGUMENTS OUTPUT_VARIABLE LIST_SEPARATOR)

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

  foreach(CFCA_NAME IN LISTS CFCA_CACHE_ENTRIES)
    if(CFCA_NAME IN_LIST CFCA_FORWARDED_NAMES)
      continue()
    endif()

    get_property(CFCA_HELP CACHE ${CFCA_NAME} PROPERTY HELPSTRING)

    if(NOT CFCA_HELP STREQUAL "No help, variable specified on the command line.")
      continue()
    endif()

    get_property(CFCA_CACHE_TYPE CACHE ${CFCA_NAME} PROPERTY TYPE)
    get_property(CFCA_CACHE_VALUE CACHE ${CFCA_NAME} PROPERTY VALUE)

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
