#!/bin/bash
#
# config.sh - global defaults, state, and the package registry
# (pkg_info_* associative arrays). Sourced first: every other module
# reads from the globals declared here.

. /etc/os-release
# For SLES
export PATH=$PATH:/usr/sbin:/sbin
########## What User Must set ##########
mpi_flavor="openmpi"
compiler="gcc"
fortran_compiler="gfortran"
gpu_arch=""
gpu_path=""
is_nv_gpu=false
is_rocm_gpu=false
is_gpu_support=false

log_file_name=log_$(hostname -s)_hpc.log
deps_source_dir_name=build/$(uname)-$ID${VERSION_ID%.*}-$(arch)
deps_install_relative_path=install/$(uname)-$ID${VERSION_ID%.*}-$(arch)

# THIS_PATH is the script's own directory (not the caller's cwd), so all
# default paths (softwares/, log/, env/) live next to hpc-install.sh
# regardless of where it's invoked from.
THIS_PATH=$(cd "$(dirname "$0")" && pwd)
NODE_NAME=$(hostname -s)

root_path=$THIS_PATH/softwares
build_path=""

deps_tar_path=""
deps_source_path=""
install_path=""
MY_LOAD_ENV_FILE=""
ENV_FILE_NAME="load_env"
max_threads=`lscpu | grep "^CPU(s)" | awk  '{print $2}'`

declare -A available_softwares
declare -a software_to_install=()
declare -a supported_mpi_flavor=("openmpi" "openmpi_ucx" "impi")
declare -A software_suffixes=()

# CLI-driven state flags
is_list_option=false
is_mpi=false
force_update=false

# Identifier for this build's env file only -- does NOT affect build/install
# paths. Two different --tag runs against the same node/MPI/GPU combination
# will reuse the same build/install directories but get distinct env files.
ftag="default"

GCC_VERSION=`gcc --version | head -n 1 | awk '{print $3}'`

declare -A pkg_info_gcc=(["version"]=${GCC_VERSION%%.*} ["sub_version"]=${GCC_VERSION#*.} ["base_prefix"]="gcc-$GCC_VERSION")

cmake_path=`command -v cmake 2> /dev/null`
if [[ -z $cmake_path ]]; then
	declare -A pkg_info_cmake=(["version"]="3.28" ["sub_version"]="4")
else
	CMAKE_VERSION=`cmake --version | head -n 1 | awk '{print $3}'`
	declare -A pkg_info_cmake=(["version"]="${CMAKE_VERSION%%.*}" ["sub_version"]="${CMAKE_VERSION#*.}" ["prefix"]=${cmake_path%%bin*} )
fi


declare -A pkg_info_dummy=(["version"]="X.X" ["sub_version"]="X")


declare -A pkg_info_hdf5=(["version"]="2" ["sub_version"]="2.0")
declare -A pkg_info_openmpi=(["version"]="5.0" ["sub_version"]="10" ["CC"]="mpicc" ["CXX"]="mpicxx" ["F77"]="mpif77" ["FC"]="mpifort")
declare -A pkg_info_openmpi_ucx=(["version"]="5.0" ["sub_version"]="10" ["CC"]="mpicc" ["CXX"]="mpicxx" ["F77"]="mpif77" ["FC"]="mpifort")
declare -A pkg_info_impi=(["version"]="X" ["sub_version"]="X" ["CC"]="mpigcc" ["CXX"]="mpigxx" ["F77"]="mpif77" ["FC"]="mpif90")
declare -A pkg_info_netcdf_c=(["version"]="4.9" ["sub_version"]="2")
declare -A pkg_info_netcdf_fortran=(["version"]="4.6" ["sub_version"]="1")
declare -A pkg_info_netcdf=(["version"]="4.9" ["sub_version"]="4.6")
declare -A pkg_info_madmpi=(["version"]="0" ["sub_version"]="4")
declare -A pkg_info_autoconf=(["version"]="2" ["sub_version"]="72e")
declare -A pkg_info_json_fortran=(["version"]="9.0" ["sub_version"]="1")
declare -A pkg_info_lapack=(["version"]="3.12" ["sub_version"]="0")
declare -A pkg_info_gslib=(["version"]="1" ["sub_version"]="0.9")
declare -A pkg_info_parmetis=(["version"]="4" ["sub_version"]="0.3")

# Benchmarks
declare -A pkg_info_osu=(["version"]="7" ["sub_version"]="5.2")
declare -A pkg_info_imb=(["version"]="2021" ["sub_version"]="8")
declare -A pkg_info_neko=(["version"]="0.9" ["sub_version"]="1")
declare -A pkg_info_arrhenius_benchmarks=(["version"]="X" ["sub_version"]="X")

# NCCL-Based
declare -A pkg_info_nccl=(["version"]="2.31" ["sub_version"]="2")
declare -A pkg_info_nccl_tests=(["version"]="2" ["sub_version"]="19.7")
declare -A pkg_info_psm2_nccl=(["version"]="0.3" ["sub_version"]="0")
declare -A pkg_info_aws_ofi_nccl=(["version"]="1.13" ["sub_version"]="2")

# RCCL_based
declare -A pkg_info_rccl=(["version"]="6.3" ["sub_version"]="3")
declare -A pkg_info_rccl_tests=(["version"]="X" ["sub_version"]="X")
# declare -A pkg_info_psm2_rccl=(["version"]="0.3" ["sub_version"]="0")
declare -A pkg_info_aws_ofi_rccl=(["version"]="1.9" ["sub_version"]="2")

# Infiniband
declare -A pkg_info_ucx=(["version"]="1.17" ["sub_version"]="0")
declare -A pkg_info_ucc=(["version"]="1.3" ["sub_version"]="0")

# I/O Benchmarks
declare -A pkg_info_ior=(["version"]="4.0" ["sub_version"]="0")

# Generic
declare -n pkg_info_mpi="pkg_info_${mpi_flavor}"
declare -n pkg_info_compiler="pkg_info_${compiler}"

# GPU Arch Map
declare -A gpu_map=(["p100"]="60" ["gp100"]="60" ["a40"]="86" ["a100"]="80" ["h100"]="90" ["rocm"]="x")

set -o posix;
listOfPackages=`set | grep "pkg_info_" | cut -d "=" -f1`
set +o posix;

for package_name in $listOfPackages; do
	available_softwares[${package_name#pkg_info_*}]=1
done

available_softwares['mpi']=0
available_softwares['compiler']=0
