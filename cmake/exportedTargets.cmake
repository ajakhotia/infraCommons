function(add_exported_library)

    set(OPTIONS_ARGUMENTS "")

    set(SINGLE_VALUE_ARGUMENTS
            TARGET
            TYPE
            NAMESPACE
            EXPORT)

    set(MULTI_VALUE_ARGUMENTS
            SOURCES
            HEADERS
            INCLUDE_DIRECTORIES
            LINK_LIBRARIES
            COMPILE_FEATURES
            COMPILE_OPTIONS
            COMPILE_DEFINITIONS)

    cmake_parse_arguments("AEL_PARAM"
            "${OPTIONS_ARGUMENTS}"
            "${SINGLE_VALUE_ARGUMENTS}"
            "${MULTI_VALUE_ARGUMENTS}"
            ${ARGN})

    add_library(${AEL_PARAM_TARGET} ${AEL_PARAM_TYPE} ${AEL_PARAM_SOURCES})

    if(AEL_PARAM_NAMESPACE)
        add_library(${AEL_PARAM_NAMESPACE}${AEL_PARAM_TARGET} ALIAS ${AEL_PARAM_TARGET})
    endif()

    if(AEL_PARAM_TYPE STREQUAL "INTERFACE")
        target_include_directories(${AEL_PARAM_TARGET} INTERFACE
                $<BUILD_INTERFACE:${AEL_PARAM_INCLUDE_DIRECTORIES}>
                $<INSTALL_INTERFACE:include>)
    else()
        target_include_directories(${AEL_PARAM_TARGET} PUBLIC
                $<BUILD_INTERFACE:${AEL_PARAM_INCLUDE_DIRECTORIES}>
                $<INSTALL_INTERFACE:include>)
    endif()

    target_link_libraries(${AEL_PARAM_TARGET} ${AEL_PARAM_LINK_LIBRARIES})

    if(AEL_PARAM_COMPILE_FEATURES)
        target_compile_features(${AEL_PARAM_TARGET} ${AEL_PARAM_COMPILE_FEATURES})
    endif()

    if(AEL_PARAM_COMPILE_OPTIONS)
        target_compile_options(${AEL_PARAM_TARGET} ${AEL_PARAM_COMPILE_OPTIONS})
    endif()

    if(AEL_PARAM_COMPILE_DEFINITIONS)
        target_compile_definitions(${AEL_PARAM_TARGET} ${AEL_PARAM_COMPILE_DEFINITIONS})
    endif()

    # The trailing / is important to avoid having install path that look like <prefix>/include/include.
    install(DIRECTORY ${AEL_PARAM_INCLUDE_DIRECTORIES}/
            DESTINATION include
            FILES_MATCHING PATTERN "*.h*")

    install(TARGETS ${AEL_PARAM_TARGET} EXPORT ${AEL_PARAM_EXPORT})

endfunction()


function(add_exported_executable)

    set(OPTIONS_ARGUMENTS "")

    set(SINGLE_VALUE_ARGUMENTS
            TARGET
            NAMESPACE
            EXPORT)

    set(MULTI_VALUE_ARGUMENTS
            SOURCES
            HEADERS
            INCLUDE_DIRECTORIES
            LINK_LIBRARIES
            COMPILE_FEATURES
            COMPILE_OPTIONS
            COMPILE_DEFINITIONS)

    cmake_parse_arguments("AEE_PARAM"
            "${OPTIONS_ARGUMENTS}"
            "${SINGLE_VALUE_ARGUMENTS}"
            "${MULTI_VALUE_ARGUMENTS}"
            ${ARGN})

    add_executable(${AEE_PARAM_TARGET} ${AEE_PARAM_SOURCES})

    if(AEE_PARAM_NAMESPACE)
        add_executable(${AEE_PARAM_NAMESPACE}${AEE_PARAM_TARGET} ALIAS ${AEE_PARAM_TARGET})
    endif()

    target_include_directories(${AEE_PARAM_TARGET} PRIVATE ${AEE_PARAM_INCLUDE_DIRECTORIES})
    target_link_libraries(${AEE_PARAM_TARGET} PRIVATE ${AEE_PARAM_LINK_LIBRARIES})
    target_compile_features(${AEE_PARAM_TARGET} PRIVATE ${AEE_PARAM_COMPILE_FEATURES})
    target_compile_options(${AEE_PARAM_TARGET} PRIVATE ${AEE_PARAM_COMPILE_OPTIONS})
    target_compile_definitions(${AEE_PARAM_TARGET} PRIVATE ${AEE_PARAM_COMPILE_DEFINITIONS})

    install(TARGETS ${AEE_PARAM_TARGET} EXPORT ${AEE_PARAM_EXPORT})

endfunction()
