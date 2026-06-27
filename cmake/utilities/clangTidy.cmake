include(${CMAKE_CURRENT_LIST_DIR}/collectBuildTargets.cmake)

## Make every compiled target a build dependency of TIDY_TARGET, so the build graph brings the tree
## (including generated headers) up to date before clang-tidy parses it; otherwise a missing
## generated header breaks the AST and -fix applies invalid edits. UTILITY targets are skipped.
##
## Call once from the root CMakeLists.txt after all add_subdirectory calls. add_clang_tidy creates
## no target when clang-tidy is missing, so guard on it: if(TARGET clangTidy) ... endif().
function(add_clang_tidy_build_dependencies TIDY_TARGET)
  collect_build_targets(ACT_ALL_TARGETS "${CMAKE_SOURCE_DIR}")

  foreach(ACT_TARGET IN LISTS ACT_ALL_TARGETS)
    if(ACT_TARGET STREQUAL TIDY_TARGET)
      continue()
    endif()

    get_target_property(ACT_TARGET_TYPE ${ACT_TARGET} TYPE)
    if(ACT_TARGET_TYPE STREQUAL "UTILITY")
      continue()
    endif()

    add_dependencies(${TIDY_TARGET} ${ACT_TARGET})
  endforeach()
endfunction()

function(add_clang_tidy)
  set(OPTIONS_ARGUMENTS REQUIRED)
  set(SINGLE_VALUE_ARGUMENTS TARGET VERSION)
  set(MULTI_VALUE_ARGUMENTS "")

  cmake_parse_arguments("ACT_PARAM"
    "${OPTIONS_ARGUMENTS}"
    "${SINGLE_VALUE_ARGUMENTS}"
    "${MULTI_VALUE_ARGUMENTS}"
    ${ARGN})

  require_arguments(PREFIX ACT_PARAM ARGUMENTS TARGET VERSION)

  find_program(ACT_CLANG_TIDY clang-tidy-${ACT_PARAM_VERSION})
  find_program(ACT_RUN_CLANG_TIDY run-clang-tidy-${ACT_PARAM_VERSION})

  if(ACT_CLANG_TIDY AND ACT_RUN_CLANG_TIDY)
    message(STATUS "Found clang-tidy version ${ACT_PARAM_VERSION} at ${ACT_CLANG_TIDY}")
    message(STATUS "Found run-clang-tidy version ${ACT_PARAM_VERSION} at ${ACT_RUN_CLANG_TIDY}")
    message(STATUS "Setting up custom target '${ACT_PARAM_TARGET}' to run clang-tidy.")

    # The build tree must stay off-limits.
    string(REGEX REPLACE "([][.^$*+?(){}|])" "\\\\\\1" ACT_BINARY_DIR_REGEX "${CMAKE_BINARY_DIR}")

    add_custom_target(${ACT_PARAM_TARGET}
      COMMAND
        ${ACT_RUN_CLANG_TIDY}
          -p ${CMAKE_BINARY_DIR}
          -clang-tidy-binary ${ACT_CLANG_TIDY}
          -exclude-header-filter "^${ACT_BINARY_DIR_REGEX}"
          -fix
          "^(?!${ACT_BINARY_DIR_REGEX}).*"
      WORKING_DIRECTORY
        ${PROJECT_SOURCE_DIR}
      COMMENT
        "Running clang-tidy with fixes in ${PROJECT_SOURCE_DIR} using clang-tidy at: ${ACT_CLANG_TIDY}"
      VERBATIM)

    set(CLANG_TIDY "${ACT_CLANG_TIDY};--exclude-header-filter=^${ACT_BINARY_DIR_REGEX}" PARENT_SCOPE)
  else()
    if(ACT_PARAM_REQUIRED)
      message(FATAL_ERROR "Unable to find clang-tidy for version ${ACT_PARAM_VERSION}.")
    else()
      message(STATUS "Unable to find clang-tidy for version ${ACT_PARAM_VERSION}. Skipping ${ACT_PARAM_TARGET} setup.")
    endif()
  endif()
endfunction()
