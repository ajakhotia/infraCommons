## Recursively collect every build-system target at or below a directory.
##
## Usage:
##   collect_build_targets(<out-var> <directory>)
##
## Gathers the BUILDSYSTEM_TARGETS of <directory> and, recursively, of all of its subdirectories,
## and stores the combined list in <out-var> in the caller's scope. <directory> is typically
## ${CMAKE_SOURCE_DIR} to enumerate the whole project.
##
## BUILDSYSTEM_TARGETS is a per-directory property: it lists only the targets created in that one
## directory, never those of its subdirectories, so a single non-recursive query misses every
## target defined under add_subdirectory. IMPORTED and ALIAS targets are not reported by
## BUILDSYSTEM_TARGETS, so the result holds only targets this build actually creates.
##
## Call this after the relevant add_subdirectory calls have run, so the targets to collect exist.
##
## Example:
##   collect_build_targets(ALL_TARGETS "${CMAKE_SOURCE_DIR}")
##   foreach(TARGET IN LISTS ALL_TARGETS)
##       # ...
##   endforeach()
function(collect_build_targets OUT_VAR DIR)
  set(CBT_COLLECTED "")

  get_property(CBT_DIR_TARGETS DIRECTORY "${DIR}" PROPERTY BUILDSYSTEM_TARGETS)
  list(APPEND CBT_COLLECTED ${CBT_DIR_TARGETS})

  get_property(CBT_SUBDIRS DIRECTORY "${DIR}" PROPERTY SUBDIRECTORIES)
  foreach(CBT_SUBDIR IN LISTS CBT_SUBDIRS)
    collect_build_targets(CBT_CHILD_TARGETS "${CBT_SUBDIR}")
    list(APPEND CBT_COLLECTED ${CBT_CHILD_TARGETS})
  endforeach()

  set(${OUT_VAR} "${CBT_COLLECTED}" PARENT_SCOPE)
endfunction()
