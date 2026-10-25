# User configuration for app_component (used by CMakeLists.txt)

# Extra compile definitions, e.g. "SIMULATION" to disable usleep in main.c
set(USER_COMPILE_DEFINITIONS
)

set(USER_UNDEFINED_SYMBOLS
)

set(USER_INCLUDE_DIRECTORIES
)

set(USER_COMPILE_SOURCES
)

set(USER_COMPILE_OPTIONS " -Wall -Wextra -O0 -g3")

set(USER_LINK_LIBRARIES
)

set(USER_LINK_DIRECTORIES
)

set(USER_LINK_OPTIONS
)

# Linker script: use the existing lscript.ld instead of generating one
set(USER_LINKER_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/lscript.ld")
