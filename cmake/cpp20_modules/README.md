# cpp20_modules
C++ modules with CMake 

References:

> How to use c++20 modules with CMake?\
https://stackoverflow.com/a/62499857/11782802

> How to compile/use header unit modules under CLang C++?\
https://stackoverflow.com/a/67254709/11782802

> Modules in Clang 11\
https://mariusbancila.ro/blog/2020/05/15/modules-in-clang-11/

> Using C++ Modules TS with standard headers on linux\
https://stackoverflow.com/a/48185537/11782802

Helpful commands:

##### printing default clang frontend command line: 
```shell
clang++ -v -x c++ - < /dev/null
```

##### constructing default includes list:
```shell
clang++ -v -x c++ - < /dev/null 2>&1 | grep -P "^\s+/usr" | xargs -n1 readlink -f
clang -v -x c - < /dev/null 2>&1 | grep -P "^\s+/usr" | xargs -n1 readlink -f
```
