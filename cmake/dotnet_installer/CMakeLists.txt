cmake_minimum_required(VERSION 3.30)
project(install_test)

set(CPACK_WIX_VERSION 4)
set(CPACK_WIX_INSTALL_SCOPE perUser)
set(CPACK_WIX_ROOT_FOLDER_ID "LocalAppDataFolder")
set(CPACK_PACKAGE_NAME "test")
set(CPACK_PACKAGE_VERSION "1.0.0")

set(DOTNET_PROJECT_SRC ${CMAKE_SOURCE_DIR}/test)
set(DOTNET_PROJECT_OUT ${CMAKE_BINARY_DIR}/out)

add_custom_target(
	make_dotnet ALL
	COMMAND dotnet publish
		--sc -r win-x64
		-o ${DOTNET_PROJECT_OUT}
		-p:PublishSingleFile=true
	WORKING_DIRECTORY ${DOTNET_PROJECT_SRC}
)

install(DIRECTORY files/ DESTINATION ".")
install(DIRECTORY ${DOTNET_PROJECT_OUT}/ DESTINATION ".")

file(GLOB_RECURSE INSTALL_FILES "files/*")
set(MSI_OUTPUT ${CMAKE_BINARY_DIR}/${CPACK_PACKAGE_NAME}-${CPACK_PACKAGE_VERSION}-Win64.msi)

add_custom_command(
	OUTPUT ${MSI_OUTPUT}
	DEPENDS ${INSTALL_FILES} make_dotnet
	COMMAND ${CMAKE_CPACK_COMMAND}
		-G WIX
		-B ${CMAKE_BINARY_DIR}
)
add_custom_target(make_msi ALL DEPENDS ${MSI_OUTPUT})
add_dependencies(make_msi make_dotnet)

include(CPack)