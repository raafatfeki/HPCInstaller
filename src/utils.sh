#!/bin/bash
#
. /etc/os-release

########## What User Must set ##########
mpi_flavor="openmpi"
compiler="gcc"
fortran_compiler="gfortran"
gpu_arch=""
gpu_path="/usr/local/cuda"

log_file_name=hpcinstaller.log
deps_source_dir_name=build/$(uname)-$ID${VERSION_ID%.*}-$(arch)
deps_install_relative_path=install/$(uname)-$ID${VERSION_ID%.*}-$(arch)
THIS_PATH=`pwd`
root_path=$HOME/softwares
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


declare -A pkg_info_hdf5=(["version"]="1.12" ["sub_version"]="0")
declare -A pkg_info_openmpi=(["version"]="5.0" ["sub_version"]="3" ["CC"]="mpicc" ["CXX"]="mpicxx" ["F77"]="mpif77" ["FC"]="mpifort")
declare -A pkg_info_openmpi_ucx=(["version"]="5.0" ["sub_version"]="3" ["CC"]="mpicc" ["CXX"]="mpicxx" ["F77"]="mpif77" ["FC"]="mpifort")
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
declare -A pkg_info_osu=(["version"]="7" ["sub_version"]="4")
declare -A pkg_info_imb=(["version"]="2021" ["sub_version"]="8")
declare -A pkg_info_neko=(["version"]="0.9" ["sub_version"]="1")
declare -A pkg_info_arrhenius_benchmarks=(["version"]="X" ["sub_version"]="X")

# NCCL-Based
declare -A pkg_info_nccl=(["version"]="2.23" ["sub_version"]="4-1")
declare -A pkg_info_nccl_tests=(["version"]="2.13" ["sub_version"]="10")
declare -A pkg_info_psm2_nccl=(["version"]="0.3" ["sub_version"]="0")
declare -A pkg_info_aws_ofi_nccl=(["version"]="1.13" ["sub_version"]="2")

# RCCL_based
declare -A pkg_info_rccl=(["version"]="6.3" ["sub_version"]="3")
declare -A pkg_info_rccl_tests=(["version"]="9" ["sub_version"]="19")
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
declare -A gpu_map=(["p100"]="60" ["gp100"]="60" ["a40"]="86" ["h100"]="90" ["h100"]="90" ["mi300x"]="x")

set -o posix;

listOfPackages=`set | grep "pkg_info_" | cut -d "=" -f1`

for package_name in $listOfPackages; do
	available_softwares[${package_name#pkg_info_*}]=1
done

available_softwares['mpi']=0
available_softwares['compiler']=0

########## Functions ##########
NC='\033[0m' # No Color
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLDGREEN='\033[1;32m'
YELLOW='\033[0;33m'

is_list_option=false
is_mpi=false

indent() { sed 's/^/\t/'; }

printError() {
	in="$@"
	printf "${RED}Error: $in${NC}\n"
}

printWarn() {
	in="$@"
	printf "${YELLOW}Warning: $in${NC}\n"
}

printInfo() {
	in="$@"
	printf "${BOLDGREEN}$in${NC}\n"
}

get_options() {
	VALID_ARGS=$(getopt -o i:,l,p:,s:,b:,c: --long install-list:,list-packages,path:,mpi:,gpu:,suffix:,build-path:,conf-external: -- "$@")
	[ $? != 0 ] && printError "Wrong options -- Please try installer.sh (-h|--help)" && exit

	eval set -- "$VALID_ARGS"
	while [ : ]; do
		case "$1" in
			-i | --install-list)
				is_list_option=true
				create_software_list $2
				shift 2
				;;
			-c | --conf-external)
				is_list_option=true
				create_external_software_list $2
				shift 2
				;;
			-p | --path)
				root_path=$2
				shift 2
				;;
			-b | --build-path)
				build_path=$2
				shift 2
				;;
			-s | --suffix)
				outputsuffix=$2
				shift 2
				;;
			--mpi)
				local_mpi_info=$2
				is_mpi=true
				set_mpi $local_mpi_info
				shift 2
				;;
			--gpu)
				local_gpu_info=$2
				set_gpu $local_gpu_info
				shift 2
				;;
			-l | --list-packages)
				list_packages
				exit
				;;
			-h | --help)
				usage
				exit
				;;
			--) shift; 
				break 
				;;
		esac
	done

	if  ! ($is_list_option); then
		echo "Nothing to do: Please set at least one of the following options:"
		echo "-i | --install-list, -l | --list-packages"
		exit
	fi
}

set_mpi() {
	input_array=(${1//:/ })

	input_mpi_flavor=${input_array[0]}
	if [[ ! -z $input_mpi_flavor ]]; then
		mpi_flavor=$input_mpi_flavor
	else
		printWarn "Using default MPI Flavor $mpi_flavor."
	fi
	mpi_path=${input_array[1]}

	if [[ -z $mpi_path ]]; then
		if [[ ! ${supported_mpi_flavor[@]} =~ $mpi_flavor ]]; then
			printError "The requested MPI flavor $mpi_flavor is not supported. Please provide your local MPI path or choose one of the following list."
			list_mpi
			exit
		else
			if [[ $mpi_flavor == "impi" ]]; then
				printError "The requested MPI flavor $mpi_flavor is only supported if you provide your local MPI path."
				exit
			fi
			declare -ng pkg_info_mpi="pkg_info_${mpi_flavor}"
			software_to_install=($mpi_flavor "${software_to_install[@]}")
			if [[ $mpi_flavor == "openmpi_ucx" ]]; then
				software_to_install=("ucx" "ucc" "${software_to_install[@]}")
			fi
		fi
	elif [[ ! -d $mpi_path ]]; then
		printError "This MPI path $mpi_path does not exist."
		exit
	else
		declare -ng pkg_info_mpi="pkg_info_${mpi_flavor}"
		pkg_info_mpi["prefix"]=$mpi_path
		export_package $mpi_path
	fi
}

set_gpu() {
	input_array=(${1//:/ })
	gpu_arch=${input_array[0]}
	if [[ ! ${!gpu_map[@]} =~ $gpu_arch ]]; then
		printError "The requested GPU arch '$gpu_arch' is not supported. We only support:" "${!gpu_map[@]}"
		exit
	fi

	gpu_path=${input_array[1]}
	if [[ ! -z $gpu_path && ! -d $gpu_path ]]; then
		printError "This GPU Library path '$gpu_path' does not exist."
		exit
	fi
	export_package $gpu_path
}

set_paths() {
	root_path=$root_path-$outputsuffix
	log_file=$THIS_PATH/$log_file_name
	deps_tar_path=$root_path/tars/
	if [[ $build_path == "" ]]; then
		build_path=$root_path
	else
		build_path=${build_path}-${outputsuffix}
	fi
	deps_source_path=$build_path/$deps_source_dir_name
	install_path=$root_path/$deps_install_relative_path
	if [[ ! -z $outputsuffix ]]; then
		ENV_FILE_NAME+="_$outputsuffix"
	fi
	MY_LOAD_ENV_FILE=$THIS_PATH/env/$ENV_FILE_NAME.sh
	mkdir -p $deps_tar_path $deps_source_path $install_path
}

get_libtool_gpu_conf() {
	package_build_extra_options=""
	if [[ ! -z $gpu_arch ]]; then
		if [[ $gpu_arch == "mi300x" ]]; then
			package_build_extra_options+=" --with-rocm"
		else
			package_build_extra_options+=" --with-cuda"
		fi
		if [[ ! -z $gpu_path ]]; then
			package_build_extra_options+="=$gpu_path "
		fi
	fi
	echo $package_build_extra_options
}

create_software_list() {
	input_list=${1//,/ }
	for input in $input_list; do
		input_array=(${input//:/ })
		package_name=${input_array[0]}
		package_suffix=${input_array[1]}
		if [[ ${available_softwares[$package_name]} -eq 1 ]]; then
			software_to_install+=($package_name)
		else
			printWarn "Package '$package_name' is not supported."
			continue
		fi

		if [[ ! -z $package_suffix ]]; then
			software_suffixes[$package_name]=$package_suffix
		fi
	done
}

create_external_software_list() {
	input_list=${1//,/ }
	if [[ ! -z $input_list ]]; then
		printInfo "- Export External Packages:"
	fi

	for input in $input_list; do
		input_array=(${input//:/ })
		package_name=${input_array[0]}
		package_prefix=${input_array[1]}

		if [[ -z $package_name ]]; then
			printError "No Package name specified: input=$input"
			exit
		fi

		if [[ -z $package_prefix ]]; then
			printError "You have to specify the path to the external software: $package_name."
			exit
		fi

		echo -e "\t* $package_name:$package_prefix "
		eval "declare -gA pkg_info_$package_name=(["prefix"]=$package_prefix ["version"]="X" ["sub_version"]="X")"

		export_package $package_prefix
	done
}

list_packages() {
	echo "List of available packages:"
	for soft in ${!available_softwares[@]}; do
		if [[ ${available_softwares[$soft]} -eq 1 ]]; then
			echo -e "\t$soft"
		fi
	done
}

list_mpi() {
	echo "List of available MPI flavors:"
	for soft in ${supported_mpi_flavor[@]}; do
		echo -e "\t$soft"
	done
}

# # This is wrong, it should be recursive but let keep it like this for now
# resolve_dependency() {
# 	for package_name in ${software_to_install[@]}; do
# 		declare -n pkg="pkg_info_${package_name}" 
# 		for dep in ${pkg["deps"]}; do
# 			if [[ "$dep" == "mpi" ]]; then
# 				if  ! $is_mpi; then
# 					printError "Package '$package_name' depends on 'MPI': Please provide MPI info with --mpi option."
# 					exit
# 				else
# 					continue
# 				fi
# 			fi
# 			echo ${software_to_install[@]}
# 			if [[ ${software_to_install[@]} =~ $dep ]]; then
# 				software_to_install+=($dep)
# 				printWarn "Package '$package_name' depends on '$dep': Add it to the list of the softwares to install."
# 			fi
# 		done
# 	done
# }

export_package () {
	package_prefix=$1
	if [[ -d "$package_prefix/bin" ]]; then
		LOCAL_PATH=$package_prefix/bin:$LOCAL_PATH
		export PATH=$package_prefix/bin:$PATH
	fi
	if [[ -d "$package_prefix/lib" ]]; then
		LOCAL_LD_LIBRARY_PATH=$package_prefix/lib:$LOCAL_LD_LIBRARY_PATH
		export LD_LIBRARY_PATH=$package_prefix/lib:$LD_LIBRARY_PATH
		if [[ -d "$package_prefix/lib/pkgconfig" ]]; then
			LOCAL_PKG_CONFIG_PATH=$package_prefix/lib/pkgconfig:$LOCAL_PKG_CONFIG_PATH
			export PKG_CONFIG_PATH=$package_prefix/lib/pkgconfig:$PKG_CONFIG_PATH
		fi
	fi
	if [[ -d "$package_prefix/lib64" ]]; then
		LOCAL_LD_LIBRARY_PATH=$package_prefix/lib64:$LOCAL_LD_LIBRARY_PATH
		export LD_LIBRARY_PATH=$package_prefix/lib64:$LD_LIBRARY_PATH
		if [[ -d "$package_prefix/lib64/pkgconfig" ]]; then
			LOCAL_PKG_CONFIG_PATH=$package_prefix/lib64/pkgconfig:$LOCAL_PKG_CONFIG_PATH
			export PKG_CONFIG_PATH=$package_prefix/lib64/pkgconfig:$PKG_CONFIG_PATH
		fi
	fi
}

get_lib() {
	prefix=$1
	lib_name=$2
	if [[ -f "$prefix/lib/$lib_name" ]]; then
		echo $prefix/lib
	elif [[ -f "$prefix/lib64/$lib_name" ]]; then
		echo $prefix/lib64
	else
		printError "Library $lib_name not found under $prefix/[lib/lib64]"
	fi
}

create_load_env() {
cat << EOF  > $1
#!/bin/bash
#
export PATH=$LOCAL_PATH:\$PATH
export LD_LIBRARY_PATH=$LOCAL_LD_LIBRARY_PATH:\$LD_LIBRARY_PATH
export PKG_CONFIG_PATH=$LOCAL_PKG_CONFIG_PATH:\$PKG_CONFIG_PATH

EOF
}

vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if ((10#${ver1[i]:=0} > 10#${ver2[i]:=0}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

testvercomp () {
    vercomp $1 $2
    case $? in
        0) op='=';;
        1) op='>';;
        2) op='<';;
    esac
    if [[ $op != $3 ]]
    then
        echo -e "\t- Version of '$4' Not Supported: Expected $1 $3 $2, Actual $1 $op $2"
        return -1
    else
        echo -e "\t- Version of '$4' Supported: '$1 $op $2'"
        return 0
    fi
}

download_untar_cd_package() {
	package_url=$1
	tar_extension="tar.gz"
	if [[ ! -z $3 ]]; then
		tar_extension=$3
	fi

	if [[ ! -z $2 && $2 != "none" ]]; then
		package_tar=$2.$tar_extension
	else
		package_tar=${package_url##*/}
	fi

	package_abs_path=${package_tar%.$tar_extension}
	package_dir=$deps_source_path/$package_abs_path

	cd $deps_tar_path

	if [[ ! -f $package_tar ]]; then
		echo -e "\t\t* Download $package_tar"
		wget $package_url >> $log_file 2>&1
		if [[ ! -z $2 ]]; then
			old_package_tar=${package_url##*/}
			echo -e "\t\t* Rename $old_package_tar to $package_tar"
			mv $old_package_tar $package_tar
		fi
		[ $? != 0 ] && printError "Download $package_url" && exit
	else
		echo -e "\t\t* $package_tar already downloaded."
	fi

	if [[ ! -d $package_dir ]]; then
		echo -e -n "\t\t* Untar $package_tar to"
		# 	tar -xzvf $package_tar --one-top-level=$package_dir --strip-components 1 >> $log_file 2>&1
		if [[ $tar_extension == "zip" ]]; then
			unzip -a $package_tar -d $deps_source_path >> $log_file 2>&1
		else
			tar -xzf $package_tar -C $deps_source_path  >> $log_file 2>&1
		fi
		# fi
		[ $? != 0 ] && printError "Untar/unzip $package_tar" && exit
	else
		echo -e -n "\t\t* $package_tar already untared to"
	fi
	echo -e " $package_dir"
	cd $package_dir
}

git_clone_cd_package() {
	cmd_options="--recursive"
	package_abs_path=$1
	package_url=$2
	package_branch=$3

	if [ -n "$3" ]; then
		cmd_options+=" -b ${package_branch}"
	fi

	# if [ -n "$4" ]; then
	# 	cmd_options+="--recursive"
	# fi

	package_dir=$deps_source_path/$package_abs_path

	cd $deps_source_path
	git clone $cmd_options $package_url $package_dir  >> $log_file 2>&1 
	[ $? != 0 ] && printError "git clone $cmd_options $package_url $package_dir" && exit
	cd $package_dir
}

make_config_install() {
	package_name=$1
	package_prefix=$2
	package_url=$3
	if [[ $4 == "None" ]]; then
		make_extra_options=""
	else
		make_extra_options=$4
	fi
	package_tar_rename=$5

	download_untar_cd_package $package_url $package_tar_rename

	echo -e "\t\t* make config prefix=$package_prefix $make_extra_options"
	make config prefix=$package_prefix $make_extra_options >> $log_file 2>&1
	[ $? != 0 ] && printError "make config" && exit

	echo -e "\t\t* make -j"
	make -j  >> $log_file 2>&1
	[ $? != 0 ] && printError "make" && exit

	echo -e "\t\t* make install"
	make install  >> $log_file 2>&1
	[ $? != 0 ] && printError "make install" && exit
}

make_install() {
	package_name=$1
	package_prefix=$2
	package_url=$3
	if [[ $4 == "None" ]]; then
		make_extra_options=""
	else
		make_extra_options=$4
	fi
	package_tar_rename=$5

	download_untar_cd_package $package_url $package_tar_rename

	echo -e "\t\t* make -j $make_extra_options"

	make -j $make_extra_options  >> $log_file 2>&1 
	[ $? != 0 ] && printError "make" && exit
}

cmake_install() {
	package_name=$1
	package_prefix=$2
	package_url=$3
	if [[ $4 == "None" ]]; then
		cmake_extra_options=""
	else
		cmake_extra_options=$4
	fi
	package_tar_rename=$5

	download_untar_cd_package $package_url $package_tar_rename

	source_path=`pwd`
	cd ..
	build_dir=`pwd`/build_$package_name

	if [[ -d "$build_dir" ]]; then
		echo -e "\t\t* Build directory '$build_dir' already exists. Remove all its content."
		rm -rf $build_dir/*
	else
		echo -e "\t\t* mkdir $build_dir"
		mkdir $build_dir
	fi

	cd $build_dir
	echo -e "\t\t* cd `pwd`"
	echo -e "\t\t* cmake"

	cmake -DCMAKE_INSTALL_PREFIX=$package_prefix $cmake_extra_options $source_path >> $log_file 2>&1 
	[ $? != 0 ] && printError "cmake" && exit

	echo -e "\t\t* make -j"
	make -j >> $log_file 2>&1 
	[ $? != 0 ] && printError "make" && exit

	echo -e "\t\t* make -j install"
	make install >> $log_file 2>&1 
	[ $? != 0 ] && printError "make install" && exit
}

libtool_install() {
	package_name=$1
	package_prefix=$2
	package_url=$3
	if [[ $4 == "None" ]]; then
		configure_extra_options=""
	else
		configure_extra_options=$4
	fi
	package_tar_rename=$5
	package_tar_extension=$6
	download_untar_cd_package $package_url $package_tar_rename $package_tar_extension

	if [[ -f autogen.sh ]]; then
		echo -e "\t\t* ./autogen.sh"
		./autogen.sh >> $log_file 2>&1 
		[ $? != 0 ] && printError "./autogen.sh" && exit
	elif [[ -f autogen.pl ]]; then
		#statements
		echo -e "\t\t* ./autogen.pl --force"
		./autogen.pl --force >> $log_file 2>&1 
		[ $? != 0 ] && printError "./autogen.pl" && exit
	elif [[ -f bootstrap ]]; then
		echo -e "\t\t* ./bootstrap"
		./bootstrap >> $log_file 2>&1
		[ $? != 0 ] && printError "./bootstrap" && exit
	fi

	echo -e "\t\t* ./configure --prefix=$package_prefix $configure_extra_options"
	cmd=$(echo "./configure --prefix=$package_prefix $configure_extra_options >> $log_file 2>&1")
	eval $cmd
	[ $? != 0 ] && printError "./configure --prefix=$package_prefix $configure_extra_options" && exit
 
	echo -e "\t\t* make -j"
	make -j >> $log_file 2>&1 
	[ $? != 0 ] && printError "make" && exit

	echo -e "\t\t* make install"
	make install >> $log_file 2>&1 
	[ $? != 0 ] && printError "make install" && exit
}

pkg_requires_bin() {
	for arg in "$@"; do
		which $arg 2> /dev/null
		[ $? != 0 ] && printError "This Package requires $arg." && exit
	done
}

pkg_requires_pkgs() {
	val=0
	declare -a not_found_packages=()
	for arg in "$@"; do
		# Check GPU
		if [[ $arg == "gpu" ]]; then
			if [[ -z $gpu_arch ]]; then
				printError "Please use --gpu option to define you GPU Arch and API path."
				val=1
			else
				val=0
			fi
			continue
		fi

		# Regular Packages
		declare -n pkg="pkg_info_${arg}"
		if [[ ! -n ${pkg["version"]} || ! -n ${pkg["prefix"]} ]]; then
			if [[ $arg == "mpi" ]]; then
				printError "Please use --mpi option to define you MPI package or install it."
				val=1
				continue
			fi
			not_found_packages+=(${arg})
		fi
	done

	if [[ ! ${#not_found_packages[@]} -eq 0 ]]; then
		val=1
		printError "These packages are required: \"${not_found_packages[@]}\".\n\tPlease add it/them to the list of packages to install (-i) or as external package(s) (-c)."
	fi

	[[ $val != 0 ]] && exit
}

source `dirname $0`/src/pkgs-def.sh
