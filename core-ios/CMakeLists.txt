cmake_minimum_required(VERSION 3.20)
project(iPadUAECore LANGUAGES C CXX)

# Upstream WinUAE, unmodified; all iOS feature selection happens via
# -DWINUAE_UNIX_* cache options passed by scripts/build-ios-core.sh.
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../vendor/WinUAE" winuae)

# The iPad app supplies its own SDL_main-based entry point and calls
# real_main() itself, so exclude main() from main.cpp.
target_compile_definitions(winuae_core PRIVATE NO_MAIN_IN_MAIN_C=1)

add_library(uaecore STATIC $<TARGET_OBJECTS:winuae_core>)
