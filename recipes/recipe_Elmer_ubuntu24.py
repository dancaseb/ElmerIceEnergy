import json
from pathlib import Path

import hpccm
import hpccm.building_blocks as bb
from hpccm.primitives import baseimage, comment

# Get correct config
# config_file = Path(USERARG.get("config-file", "../configs/ubuntu24_thea.json"))
config_file = Path(USERARG.get("config-file", "../configs/ubuntu24_leonardo.json"))
# config_file = Path(USERARG.get("config-file", "../configs/ubuntu24_jedi.json"))
if not config_file.exists():
    raise RuntimeError(
        "cannot access {}: No such file or directory".format(config_file)
    )

with open(config_file, "r") as json_file:
    config = json.load(json_file)

# Set base image
Stage0 += baseimage(
    image="docker.io/{}@{}".format(config["base_image"], config["digest_devel"]),
    _distro=config["base_os"],
    _arch=config["arch"],
    _as="devel",
)

# Microarchitecture specification
hpccm.config.set_cpu_target(config["march"])

################################################################################
Stage0 += comment("step1: start")
Stage0 += comment("Install build tools over base image")

# Install Python
python = bb.python(python2=False)
Stage0 += python

# Install gcc and zlib libraries
Stage0 += bb.packages(
    ospackages=[
        "gcc-13-offload-nvptx",
        "gfortran",
        "zlib1g",
        "zlib1g-dev",
    ],
)

# Install CMake
Stage0 += bb.cmake(eula=True, version="3.31.4")

# Install Git and pkgconf
Stage0 += comment("Git, Pkgconf")
Stage0 += bb.packages(ospackages=["git", "pkgconf"])


################################################################################

Stage0 += comment("step2: start")
Stage0 += comment("Install network stack packages and OpenMPI")

# Get network stack configuration
netconfig = config["network_stack"]

# Install Mellanox OFED userspace libraries
mlnx_ofed = bb.mlnx_ofed(version=netconfig["mlnx_ofed"], oslabel="ubuntu24.04")
Stage0 += mlnx_ofed

# Install KNEM headers
if netconfig["knem"]:
    knem_prefix = "/opt/knem"
    knem = bb.knem(prefix=knem_prefix)
    Stage0 += knem
else:
    knem_prefix = False

# Install XPMEM userspace library
if netconfig["xpmem"]:
    xpmem_prefix = "/opt/xpmem"
    xpmem = bb.xpmem(prefix=xpmem_prefix)
    Stage0 += xpmem
else:
    xpmem_prefix = False

# Install gdrcopy userspace library
if netconfig["gdrcopy"]:
    gdrcopy_prefix = "/opt/gdrcopy"
    gdrcopy = bb.gdrcopy(prefix=gdrcopy_prefix)
    Stage0 += gdrcopy
else:
    gdrcopy_prefix = False

# Install UCX
ucx_prefix = "/opt/ucx"
ucx = bb.ucx(
    prefix=ucx_prefix,
    repository="https://github.com/openucx/ucx.git",
    branch="v{}".format(netconfig["ucx"]),
    cuda=True,
    ofed=True,
    knem=knem_prefix,
    xpmem=xpmem_prefix,
    gdrcopy=gdrcopy_prefix,
    enable_mt=True,
)
Stage0 += ucx

# Install PMIx
match netconfig["pmix"]:
    case "internal":
        pmix_prefix = "internal"
    case version:
        pmix_prefix = "/opt/pmix"
        pmix = bb.pmix(prefix=pmix_prefix, version=netconfig["pmix"])
        Stage0 += pmix

# Install OpenMPI
ompi = bb.openmpi(
    prefix="/opt/openmpi",
    version=netconfig["ompi"],
    ucx=ucx_prefix,
    pmix=pmix_prefix,
)
Stage0 += ompi


################################################################################

Stage0 += comment("step3: start")
Stage0 += comment("Install I/O, meshing and math libraries")

# Install METIS
Stage0 += bb.packages(
    ospackages=[
        "libmetis-dev",
    ],
)


# Install ParMETIS
parmetis_prefix = "/opt/parmetis"
parmetis_env = {
    "PATH": "{}/bin:$PATH".format(parmetis_prefix),
    "CPATH": "{}/include:$CPATH".format(parmetis_prefix),
    "LIBRARY_PATH": "{}/lib:$LIBRARY_PATH".format(parmetis_prefix),
    "LD_LIBRARY_PATH": "{}/lib:$LD_LIBRARY_PATH".format(parmetis_prefix),
}

parmetis = bb.generic_build(
    url="https://ftp.mcs.anl.gov/pub/pdetools/spack-pkgs/parmetis-4.0.3.tar.gz",
    prefix=parmetis_prefix,
    directory="parmetis-4.0.3",
    build=[
        "CC=mpicc CXX=mpic++ make config shared=1 prefix={}".format(parmetis_prefix),
        "make -j$(nproc)",
        "make -j$(nproc) install",
        "cp /usr/lib/{}-linux-gnu/libmetis.so.5.1.0 {}/lib/libmetis.so".format(
            config["arch"], parmetis_prefix
        ),
        "cp /usr/include/metis.h {}/include/metis.h".format(parmetis_prefix),
    ],
    devel_environment=parmetis_env,
    runtime_environment=parmetis_env,
)
Stage0 += parmetis

# Install GMSH
gmsh_prefix = "/opt/gmsh"
gmsh_env = {
    "PATH": "{}/bin:$PATH".format(gmsh_prefix),
}

gmsh = bb.generic_build(
    url="https://gmsh.info/src/gmsh-4.13.1-source.tgz",
    prefix=gmsh_prefix,
    directory="gmsh-4.13.1-source",
    build=[
        "mkdir -p build",
        "cd build",
        'cmake -DCMAKE_INSTALL_PREFIX="{}" -DCMAKE_C_COMPILER=gcc -DCMAKE_Fortran_COMPILER=gfortran -DCMAKE_CXX_COMPILER=g++ ..'.format(
            gmsh_prefix
        ),
        "make -j$(nproc)",
        "make -j$(nproc) install",
    ],
    devel_environment=gmsh_env,
    runtime_environment=gmsh_env,
)
Stage0 += gmsh


# Install HYPRE
hypre_prefix = "/opt/hypre"
hypre_env = {
    "PATH": "{}/bin:$PATH".format(hypre_prefix),
    "CPATH": "{}/include:$CPATH".format(hypre_prefix),
    "LIBRARY_PATH": "{}/lib:$LIBRARY_PATH".format(hypre_prefix),
    "LD_LIBRARY_PATH": "{}/lib:$LD_LIBRARY_PATH".format(hypre_prefix),
    "CMAKE_PREFIX_PATH": "{}:$CMAKE_PREFIX_PATH".format(hypre_prefix),
}

hypre = bb.generic_build(
    url="https://github.com/hypre-space/hypre/archive/refs/tags/v2.32.0.tar.gz",
    prefix=hypre_prefix,
    directory="hypre-2.32.0",
    build=[
        "cd src",
        './configure --with-openmp --with-blas --with-lapack --prefix="{}" CC="mpicc -fPIC -O3 -march=native"'.format(
            hypre_prefix
        ),
        "make -j$(nproc)",
        "make install",
    ],
    devel_environment=hypre_env,
    runtime_environment=hypre_env,
)
Stage0 += hypre

# Install NetCDF, BLAS, LAPACK, SuiteSparse
Stage0 += bb.packages(
    ospackages=[
        "libblas-dev",
        "liblapack-dev",
        "libcholmod5",
        "libumfpack6",
        "libgomp1",
        "libsuitesparse-dev",
        "libnetcdf-dev",
        "libnetcdff-dev",
    ],
)

### Install NN
nn_prefix = "/opt/nn"
nn_env = {
    "PATH": "{}/bin:$PATH".format(nn_prefix),
    "CPATH": "{}/include:$CPATH".format(nn_prefix),
    "LIBRARY_PATH": "{}/lib:$LIBRARY_PATH".format(nn_prefix),
    "LD_LIBRARY_PATH": "{}/lib:$LD_LIBRARY_PATH".format(nn_prefix),
}
nn = bb.generic_build(
    url="https://github.com/sakov/nn-c/archive/refs/tags/v1.85.0.tar.gz",
    prefix=nn_prefix,
    directory="nn-c-1.85.0",
    build=[
        "cd nn",
        'CFLAGS="-fPIC -O3 -march=native -ffast-math -funroll-loops"  ./configure --prefix="{}"'.format(
            nn_prefix
        ),
        "make clean",
        "gcc -c -DTRILIBRARY -fPIC -O2 -w -ffloat-store -I. triangle.c",
        "make install",
    ],
    devel_environment=nn_env,
    runtime_environment=nn_env,
)
Stage0 += nn

# Install CSA
csa_prefix = "/opt/csa"
csa_env = {
    "PATH": "{}/bin:$PATH".format(csa_prefix),
    "CPATH": "{}/include:$CPATH".format(csa_prefix),
    "LIBRARY_PATH": "{}/lib:$LIBRARY_PATH".format(csa_prefix),
    "LD_LIBRARY_PATH": "{}/lib:$LD_LIBRARY_PATH".format(csa_prefix),
    "CMAKE_PREFIX_PATH": "{}:$CMAKE_PREFIX_PATH".format(csa_prefix),
}
csa = bb.generic_build(
    url="https://github.com/sakov/csa-c/archive/refs/tags/v1.22.0.tar.gz",
    prefix=csa_prefix,
    directory="csa-c-1.22.0",
    build=[
        "cd csa",
        './configure --prefix="{}" CC="gcc -fPIC -O3 -march=native"'.format(csa_prefix),
        "make -j$(nproc)",
        "make install",
    ],
    devel_environment=csa_env,
    runtime_environment=csa_env,
)
Stage0 += csa

# Install MMG
mmg = bb.generic_cmake(
    url="https://github.com/MmgTools/mmg/archive/refs/tags/v5.8.0.tar.gz",
    directory="mmg-5.8.0",
    prefix="/opt/mmg",
    install=True,
    recursive=True,
    cmake_opts=[
        '-DCMAKE_INSTALL_PREFIX="/opt/mmg"',
        "-DCMAKE_BUILD_TYPE=RelWithDebInfo",
        "-DBUILD_SHARED_LIBS:BOOL=TRUE",
        "-DMMG_INSTALL_PRIVATE_HEADERS=ON",
        '-DCMAKE_C_FLAGS="-fPIC  -g"',
        '-DCMAKE_CXX_FLAGS="-fPIC -std=c++11 -g"',
        "-DCMAKE_C_COMPILER=gcc",
        "-DCMAKE_Fortran_COMPILER=gfortran",
        "-DCMAKE_CXX_COMPILER=g++",
    ],
    runtime_environment={
        "PATH": "/opt/mmg/bin:$PATH",
        "LIBRARY_PATH": "/opt/mmg/lib:$LIBRARY_PATH",
        "LD_LIBRARY_PATH": "/opt/mmg/lib:$LD_LIBRARY_PATH",
        "CPATH": "/opt/mmg/include:$CPATH",
        "MMG_DIR": "/opt/mmg",
    },
    devel_environment={
        "PATH": "/opt/mmg/bin:$PATH",
        "LIBRARY_PATH": "/opt/mmg/lib:$LIBRARY_PATH",
        "LD_LIBRARY_PATH": "/opt/mmg/lib:$LD_LIBRARY_PATH",
        "CPATH": "/opt/mmg/include:$CPATH",
        "MMG_DIR": "/opt/mmg",
    },
)
Stage0 += mmg

# Install parMMG
parmmg = bb.generic_cmake(
    url="https://github.com/MmgTools/ParMmg/archive/refs/tags/v1.5.0.tar.gz",
    directory="ParMmg-1.5.0",
    prefix="/opt/parmmg",
    install=True,
    recursive=True,
    cmake_opts=[
        '-DCMAKE_INSTALL_PREFIX="/opt/parmmg"',
        "-DCMAKE_BUILD_TYPE=RelWithDebInfo",
        "-DBUILD_SHARED_LIBS:BOOL=TRUE",
        "-DDOWNLOAD_MMG=OFF",
        '-DMMG_DIR="/opt/mmg"',
        '-DCMAKE_C_FLAGS="-fPIC  -g"',
        '-DCMAKE_CXX_FLAGS="-fPIC -std=c++11 -g"',
        "-DCMAKE_C_COMPILER=gcc",
        "-DCMAKE_Fortran_COMPILER=gfortran",
        "-DCMAKE_CXX_COMPILER=g++",
    ],
    runtime_environment={
        "PATH": "/opt/parmmg/bin:$PATH",
        "LIBRARY_PATH": "/opt/parmmg/lib:$LIBRARY_PATH",
        "LD_LIBRARY_PATH": "/opt/parmmg/lib:$LD_LIBRARY_PATH",
        "CPATH": "/opt/parmmg/include:$CPATH",
        "PARMMG_DIR": "/opt/parmmg",
    },
    devel_environment={
        "PATH": "/opt/parmmg/bin:$PATH",
        "LIBRARY_PATH": "/opt/parmmg/lib:$LIBRARY_PATH",
        "LD_LIBRARY_PATH": "/opt/parmmg/lib:$LD_LIBRARY_PATH",
        "CPATH": "/opt/parmmg/include:$CPATH",
        "PARMMG_DIR": "/opt/parmmg",
    },
)
Stage0 += parmmg

# Install AMGX
amgx = bb.amgx(
    prefix="/opt/amgx",
    recursive=True,
    branch="master",
    commit="3188dce5bdc22e96407d609e398925bed6aa010d",
    cmake_opts=[
        "-DCUDA_ARCH={}".format(config["cuda_arch"]),
        "-DCMAKE_C_COMPILER=gcc",
        "-DCMAKE_Fortran_COMPILER=gfortran",
        "-DCMAKE_CXX_COMPILER=g++",
        "-DMPI_C_COMPILER=mpicc",
        "-DMPI_CXX_COMPILER=mpicxx",
        "-DMPI_Fortran_COMPILER=mpif90",
        '-DCMAKE_C_FLAGS="-O3 -march=native -ffast-math -funroll-loops"',
        '-DCMAKE_CXX_FLAGS="-O3 -march=native -ffast-math -funroll-loops"',
        '-DCMAKE_Fortran_FLAGS="-O3 -march=native -ffast-math -funroll-loops"',
    ],
)
Stage0 += amgx

################################################################################

Stage0 += comment("step4: start")
Stage0 += comment("Install geospatial data acquisition tools")

# Install LUA
lua_prefix = "/opt/lua"
lua_env = {
    "PATH": "{}/bin:$PATH".format(lua_prefix),
    "CPATH": "{}/include:$CPATH".format(lua_prefix),
    "LIBRARY_PATH": "{}/lib:$LIBRARY_PATH".format(lua_prefix),
    "LD_LIBRARY_PATH": "{}/lib:$LD_LIBRARY_PATH".format(lua_prefix),
    "CMAKE_PREFIX_PATH": "{}:$CMAKE_PREFIX_PATH".format(lua_prefix),
}
lua = bb.generic_build(
    url="https://www.lua.org/ftp/lua-5.4.7.tar.gz",
    prefix=lua_prefix,
    build=["make all install INSTALL_TOP={}".format(lua_prefix)],
    devel_environment=lua_env,
    runtime_environment=lua_env,
)
Stage0 += lua

################################################################################

Stage0 += comment("step5: start")
Stage0 += comment("Install Elmer")

elmer_prefix = "/opt/elmer"

elmer_env = {
    "PATH": "{}/bin:$PATH".format(elmer_prefix),
    "LIBRARY_PATH": "{}/lib:$LIBRARY_PATH".format(elmer_prefix),
    "LD_LIBRARY_PATH": "{}/lib::$LIBRARY_PATH".format(elmer_prefix),
}

elmer_toolchain = hpccm.toolchain(LDFLAGS="-lcurl")
elmer = hpccm.building_blocks.generic_cmake(
    repository="https://github.com/ElmerCSC/elmerfem.git",
    branch="devel",
    commit="9dce9c2ac192b50fd29f00bef746debac1a8018e",
    recursive=True,
    toolchain=elmer_toolchain,
    prefix=elmer_prefix,
    cmake_opts=[
        '-DParMetis_LIBRARIES="/opt/parmetis/lib/libmetis.so;/opt/parmetis/lib/libparmetis.so"',
        '-DParMetis_INCLUDE_DIR="/opt/parmetis/include"',
        '-DMetis_LIBRARIES="/usr/lib/{}-linux-gnu/libmetis.so.5.1.0"'.format(
            config["arch"]
        ),
        '-DMetis_INCLUDE_DIR="/usr/include/metis.h"',
        "-DWITH_MPI:BOOL=TRUE",
        "-DWITH_LUA:BOOL=TRUE",
        "-DWITH_OpenMP:BOOL=TRUE",
        "-DWITH_Mumps:BOOL=FALSE",
        "-DWITH_Hypre:BOOL=TRUE",
        "-DWITH_NETCDF:BOOL=TRUE",
        '-DNETCDF_LIBRARY="/usr/lib/{}-linux-gnu/libnetcdf.so"'.format(config["arch"]),
        '-DNETCDFF_LIBRARY="/usr/lib/{}-linux-gnu/libnetcdff.so"'.format(
            config["arch"]
        ),
        '-DNETCDF_INCLUDE_DIR="/usr/include"',
        '-DHYPRE_INCLUDE_DIR="/opt/include/hypre"',
        "-DWITH_Zoltan:BOOL=TRUE",
        "-DWITH_Trilinos:BOOL=FALSE",
        "-DWITH_ELMERGUI:BOOL=FALSE",
        "-DWITH_GridDataReader:BOOL=TRUE",
        "-DWITH_ScatteredDataInterpolator:BOOL=TRUE",
        "-DEXTERNAL_UMFPACK:BOOL=FALSE",
        "-DWITH_CHOLMOD:BOOL=TRUE",
        "-DWITH_AMGX:BOOL=TRUE",
        '-DAMGX_ROOT="/opt/amgx"',
        '-DAMGX_INCLUDE_DIR="/opt/amgx/include/;/usr/local/cuda-12.5/include"',
        '-DAMGX_LIBRARY="/opt/amgx/lib/libamgx.a"',
        '-DCUDA_LIBRARIES="-L/usr/local/cuda-12.5/lib64/libcudart.so.12 -L/usr/local/cuda-12.5/lib64/ -lcudadevrt -lrt -lpthread -lcudart_static -lnvToolsExt -ldl -lcusparse -lcublas -lcusolver"',
        '-DCUDA_LIBDIR="/usr/local/cuda-12.5/lib64"',
        '-DCUDA_INCLUDE_DIR="/usr/local/cuda-12.5/include"',
        "-DCUDA_ARCH={}".format(config["cuda_arch"]),
        '-DCSA_LIBRARY="/opt/csa/lib/libcsa.a"',
        '-DCSA_INCLUDE_DIR="/opt/csa/include"',
        '-DNN_INCLUDE_DIR="/opt/nn/include"',
        '-DNN_LIBRARY="/opt/nn/lib/libnn.a"',
        "-DWITH_MMG:BOOL=TRUE",
        '-DMMG_INCLUDE_DIR="/opt/mmg/include/"',
        '-DMMG_LIBRARY="/opt/mmg/lib/libmmg.so"',
        '-DMMG_LIBDIR="/opt/mmg/lib"',
        "-DWITH_PARMMG:BOOL=TRUE",
        '-DPARMMG_INCLUDE_DIR="/opt/parmmg/include"',
        '-DPARMMG_LIBRARY="/opt/parmmg/lib/libparmmg.so"',
        "-DWITH_ElmerIce:BOOL=TRUE",
        "-DCMAKE_C_COMPILER=gcc",
        "-DCMAKE_Fortran_COMPILER=gfortran",
        "-DCMAKE_CXX_COMPILER=g++",
        "-DMPI_C_COMPILER=mpicc",
        "-DMPI_CXX_COMPILER=mpicxx",
        "-DMPI_Fortran_COMPILER=mpif90",
        '-DCMAKE_C_FLAGS="-g -O3"',
        '-DCMAKE_CXX_FLAGS="-g -O3"',
        '-DCMAKE_Fortran_FLAGS="-g -O2 -fPIC -fopenmp -foffload=nvptx-none="-march=sm_{}""'.format(
            config["cuda_arch"]
        ),
        '-DCMAKE_Fortran_FLAGS_RELWITHDEB="-g -O2 -fPIC -DNDEBUG -fopenmp -foffload=nvptx-none="-march=sm_{}""'.format(
            config["cuda_arch"]
        ),
    ],
    runtime_environment=elmer_env,
)
Stage0 += elmer

Stage0 += comment("step6: start")
Stage0 += comment("Install profiler")

nsys_file='nsight-systems-2025.3.1_2025.3.1.90-1_arm64.deb' if config["instruction"]=="arm64" else 'NsightSystems-linux-cli-public-2025.3.1.90-3582212.deb'

Stage0 += shell(commands=['apt-get update && apt install -y wget libglib2.0-0',
'wget https://developer.download.nvidia.com/devtools/repos/ubuntu2404/{}/{} && dpkg -i {} && rm {}'.format(config["instruction"], nsys_file, nsys_file, nsys_file)
])



################################################################################
Stage0 += comment("step7: start")
Stage0 += comment("Generate runtime image")

Stage1 += baseimage(
    image="docker.io/{}@{}".format(config["base_image"], config["digest_runtime"]),
    _distro=config["base_os"],
    _arch=config["arch"],
)

# Copy all default runtimes

Stage1 += Stage0.runtime()

# Manually add missing basic libraries
Stage1 += comment("Libraries missing from CUDA runtime image")
Stage1 += bb.packages(
    ospackages=[
        "gcc-13-offload-nvptx",
        "gfortran",
        "libgomp1",
        "libnuma1",
        "libcurl4",
        "zlib1g",
        "zlib1g-dev",
    ]
)

# Manually add missing scientific libraries

Stage1 += bb.packages(
    ospackages=[
        "libmetis-dev",
        "libblas-dev",
        "liblapack-dev",
        "libcholmod5",
        "libumfpack6",
        "libgomp1",
        "libsuitesparse-dev",
        "libnetcdf-dev",
        "libnetcdff-dev",
    ],
)

nsys_file='nsight-systems-2025.3.1_2025.3.1.90-1_arm64.deb' if config["instruction"]=="arm64" else 'NsightSystems-linux-cli-public-2025.3.1.90-3582212.deb'

Stage1 += shell(commands=['apt-get update && apt install -y wget libglib2.0-0',
'wget https://developer.download.nvidia.com/devtools/repos/ubuntu2404/{}/{} && dpkg -i {} && rm {}'.format(config["instruction"], nsys_file, nsys_file, nsys_file)
])
