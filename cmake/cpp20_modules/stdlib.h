#include "common.h"

#pragma region libstdc++
#include <iostream>
#include <vector>
#include <queue>
#include <memory>
#include <stdexcept>
#include <sstream>
#pragma endregion

#pragma region gpio
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#pragma endregion

#pragma region networking
#include <arpa/inet.h>
#pragma endregion

#include <cassert>
#include <cstring>
#include <cerrno>

#include <thread>
