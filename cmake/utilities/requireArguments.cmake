## Internal implementation — takes the caller's function name explicitly.
function(require_arguments_impl CALLER)
    cmake_parse_arguments("RA" "" "PREFIX" "ARGUMENTS" ${ARGN})

    if(NOT RA_PREFIX)
        message(FATAL_ERROR "require_arguments: PREFIX is required.")
    endif()

    set(MISSING "")
    foreach(ARG_NAME IN LISTS RA_ARGUMENTS)
        if(NOT DEFINED ${RA_PREFIX}_${ARG_NAME} OR "${${RA_PREFIX}_${ARG_NAME}}" STREQUAL "")
            list(APPEND MISSING ${ARG_NAME})
        endif()
    endforeach()

    if(MISSING)
        message(FATAL_ERROR "${CALLER}: missing required argument(s): ${MISSING}")
    endif()
endfunction()

## Validates that arguments parsed by cmake_parse_arguments are set.
##
## Usage (call from inside a function, immediately after cmake_parse_arguments):
##   require_arguments(PREFIX <prefix> ARGUMENTS <name1> <name2> ...)
##
## PREFIX must match the prefix string previously passed to cmake_parse_arguments.
## cmake_parse_arguments stores parsed values in variables of the form
## ${<prefix>}_<argName>; this helper checks ${<prefix>}_<nameN> for each
## requested name and emits a FATAL_ERROR (attributed to the calling function)
## listing any that are undefined or empty.
##
## Example:
##   function(my_function)
##       cmake_parse_arguments("MF_PARAM" "" "TARGET;VERSION" "" ${ARGN})
##       require_arguments(PREFIX MF_PARAM ARGUMENTS TARGET VERSION)
##       # ... safe to use ${MF_PARAM_TARGET} and ${MF_PARAM_VERSION} here ...
##   endfunction()
##
##   my_function(VERSION 19)
##   # -> FATAL_ERROR: my_function: missing required argument(s): TARGET
macro(require_arguments)
    require_arguments_impl("${CMAKE_CURRENT_FUNCTION}" ${ARGN})
endmacro()
