cmake_minimum_required(VERSION 3.10)
set(PROJECT_NAME "directory_bookmarks")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "directory_bookmarks_plugin")

# Use C++17 for std::filesystem
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(${PLUGIN_NAME} SHARED
  "directory_bookmarks_plugin.cc"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)

target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)

# Link the filesystem library (needed for std::filesystem on some systems)
target_link_libraries(${PLUGIN_NAME} PRIVATE stdc++fs)

# List of absolute paths to libraries that should be bundled with the plugin
set(directory_bookmarks_bundled_libraries
  ""
  PARENT_SCOPE
)
