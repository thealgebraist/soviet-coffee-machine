cmake_minimum_required(VERSION 3.18)
project(soviet_generator)

set(CMAKE_CXX_STANDARD 23)

# 1. Find LibTorch
find_package(Torch REQUIRED)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${TORCH_CXX_FLAGS}")

# 2. Add Crow (expects crow.h in include path)
include_directories(include)

# 3. Executable
add_executable(generator_server main.cpp)
target_link_libraries(generator_server "${TORCH_LIBRARIES}")
set_property(TARGET generator_server PROPERTY CXX_STANDARD 23)
