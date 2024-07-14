cmake_minimum_required(VERSION 3.10)

project(something)

set(CMAKE_CXX_STANDARD 20)

set(PREBUILT_MODULE_PATH ${CMAKE_BINARY_DIR}/modules)
set(SHARED_FLAGS "")
set(GLOBAL_MODULES "")

macro(add_shflags flag)
	list(APPEND SHARED_FLAGS ${flag})
endmacro()

macro(add_global_module module)
	list(APPEND GLOBAL_MODULES ${module})
endmacro()

function(add_module_map name module_map header_file)
	file(MAKE_DIRECTORY ${PREBUILT_MODULE_PATH})
	add_custom_command(
		OUTPUT ${PREBUILT_MODULE_PATH}/${name}.pcm
		DEPENDS
			${module_map}
			${header_file}
		COMMAND
			${CMAKE_CXX_COMPILER}
			-cc1
			-xc++
			${CMAKE_CURRENT_SOURCE_DIR}/${module_map}
			-o ${PREBUILT_MODULE_PATH}/${name}.pcm
			-emit-module
			${SHARED_FLAGS}
			
			#####
			-fmodules
			-fmodule-name=${name}
			-fprebuilt-module-path=${PREBUILT_MODULE_PATH}
			-internal-isystem /usr/include/c++/11
			-internal-isystem /usr/include/x86_64-linux-gnu/c++/11
			-internal-isystem /usr/include/c++/10/backward
			-internal-isystem /usr/lib/llvm-11/lib/clang/11.1.0/include
			-internal-isystem /usr/include/x86_64-linux-gnu
			-internal-isystem /usr/include
	)
	add_custom_target(${name} DEPENDS ${PREBUILT_MODULE_PATH}/${name}.pcm)
endfunction()

function(add_module name)
    file(MAKE_DIRECTORY ${PREBUILT_MODULE_PATH})
	add_custom_command(
		OUTPUT ${PREBUILT_MODULE_PATH}/${name}.pcm
		DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${ARGN}
		COMMAND
			${CMAKE_CXX_COMPILER}
			${SHARED_FLAGS}
			-fmodules				
			-c
			${CMAKE_CURRENT_SOURCE_DIR}/${ARGN}
			-Xclang -emit-module-interface
			-o ${PREBUILT_MODULE_PATH}/${name}.pcm
			-fprebuilt-module-path=${PREBUILT_MODULE_PATH}
	)
    add_custom_target(${name} DEPENDS ${PREBUILT_MODULE_PATH}/${name}.pcm)
	foreach(module ${GLOBAL_MODULES})
		add_dependencies(${name} ${module})
	endforeach()
endfunction()

add_shflags(-std=gnu++2a)
add_shflags(-fgnuc-version=4.2.1)
add_shflags(-fcxx-exceptions)
add_shflags(-fexceptions)
add_shflags(-fmath-errno)
add_shflags(-pthread)

add_compile_options(-fmodules)
add_compile_options(-fbuiltin-module-map)
add_compile_options(-fimplicit-module-maps)
add_compile_options(-fprebuilt-module-path=${PREBUILT_MODULE_PATH})
add_compile_options(-fgnuc-version=4.2.1)
add_compile_options(-pthread)

# generate stdlib module, amd make all future modules depend on it
add_module_map(stdlib stdlib.modmap stdlib.h)
add_global_module(stdlib)

add_module(foo.common common.cpp)
add_module(foo.util util.cpp)
add_module(something something.cpp)

add_executable(sample
	common.cpp
	util.cpp
	something.cpp
	main.cpp
)
target_compile_definitions(sample PUBLIC DEBUG)

# intra-module dependencies
add_dependencies(something foo.util)
add_dependencies(something foo.common)

add_dependencies(sample something)
target_link_libraries(sample pthread)
