# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "PALSParserCpp"
version = v"0.0.4"

# The AtomicAndPhysicalConstantsCLib release PALSParserCpp pins in its
# CMakeLists.txt: its particle data and constants are tied to that release.
apc_version = v"0.12.0"

sources = [
    GitSource("https://github.com/pals-project/PALSParserCpp.git",
              "f1f69dff8a4561a781305ebc72d75cad6805a2c9"; tag="v$(version)"),
    GitSource("https://github.com/pals-project/AtomicAndPhysicalConstantsCLib.git",
              "3fc87cf582acec19e0a021fc1c69655d9fdbd6aa"; tag="v$(apc_version)"),
]

# Bash recipe for building across all platforms
script = raw"""
# AtomicAndPhysicalConstantsCLib has a C++-only API and no user other than
# PALSParserCpp, so it is linked in statically rather than being a JLL of its
# own. It would become one if another package needed it.
cd ${WORKSPACE}/srcdir/AtomicAndPhysicalConstantsCLib
cmake -S . -B build \
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} \
    -DCMAKE_BUILD_TYPE=Release \
    -DAPC_BUILD_TESTS=OFF
cmake --build build --target apc --parallel ${nproc}

cd ${WORKSPACE}/srcdir/PALSParserCpp
cmake -S . -B build \
    -DCMAKE_INSTALL_PREFIX=${prefix} \
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN} \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTING=OFF \
    -DPALS_BUILD_EXAMPLES=OFF \
    -DPALS_USE_SYSTEM_DEPS=ON \
    -DPALS_APC_INCLUDE_DIR=${WORKSPACE}/srcdir/AtomicAndPhysicalConstantsCLib/include \
    -DPALS_APC_LIBRARY=${WORKSPACE}/srcdir/AtomicAndPhysicalConstantsCLib/build/libapc.a
cmake --build build --parallel ${nproc}
# Installs the library, its header and its license, the last into
# share/licenses/PALSParserCpp.
cmake --install build --component PALSParserCpp
install -Dvm 644 ${WORKSPACE}/srcdir/AtomicAndPhysicalConstantsCLib/LICENSE \
    ${prefix}/share/licenses/PALSParserCpp/AtomicAndPhysicalConstantsCLib-LICENSE
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = expand_cxxstring_abis(supported_platforms())

# The products that we will ensure are always built
products = [
    LibraryProduct("libPALSParserCpp", :libPALSParserCpp),
]

# Dependencies that must be installed before this package can be built
dependencies = [
    # PALSParserCpp v0.0.4 is written against rapidyaml v0.15.
    Dependency("rapidyaml_jll"; compat="0.15.0"),
    Dependency("PCRE2_jll"; compat="10.42.0"),
]

# Build the tarballs, and possibly a `build.jl` as well.
# rapidyaml_jll needs Julia 1.10. GCC 12 is the newest whose libstdc++ Julia 1.10
# ships (GLIBCXX_3.4.30), so PALSParserCpp is not held to an older compiler's C++.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
               julia_compat="1.10", preferred_gcc_version=v"12")
