#!/bin/bash
#
# cli.sh - command-line option parsing and user-facing listing/help output.

get_options() {
	VALID_ARGS=$(getopt -o i:lp:t:b:c:h --long install-list:,list-packages,path:,mpi:,gpu:,tag:,build-path:,conf-external:,force-update,help -- "$@")
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
			-t | --tag)
				ftag=$2
				shift 2
				;;
			--force-update)
				force_update=true
				shift
				;;
			--mpi)
				local_mpi_info=$2
				is_mpi=true
				set_mpi $local_mpi_info
				shift 2
				;;
			--gpu)
				local_gpu_info=$2
				# Check for GPUs only if requested: is_gpu_support is true only if the system have a GPU and --gpu is explicetly requested.
				get_gpu_info
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

get_gpu_info() {
	printInfo "- Check GPUs:"
	gpu_nb=$(lspci | grep "controller: NVIDIA Corporation" | wc -l)
	if [[ $gpu_nb -ge 1 ]]; then
		echo -e "\t* Found $gpu_nb NVIDIA GPUs."
		is_nv_gpu=true
		is_gpu_support=true
	fi

	gpu_nb=$(lspci | grep -e "Display controller: Advanced Micro Devices" -e "Processing accelerator" | wc -l)
	if [[ $gpu_nb -ge 1 ]]; then
		echo -e "\t* Found $gpu_nb AMD GPUs."
		is_rocm_gpu=true
		is_gpu_support=true
	fi

	if $is_nv_gpu && $is_rocm_gpu; then
		printWarn "This is a mixt system of AMD and NVIDIA GPUs."
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
		if [[ ! " ${supported_mpi_flavor[*]} " == *" $mpi_flavor "* ]]; then
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
	if ! $is_gpu_support; then
		printError "You Requested GPU support but No GPU has been detected."
		exit
	fi

	input_array=(${1//:/ })
	gpu_arch=${input_array[0]}
	if [[ ! -v gpu_map[$gpu_arch] ]]; then
		printError "The requested GPU arch '$gpu_arch' is not supported. We only support:" "${!gpu_map[@]}"
		exit
	else
		if [[ $gpu_arch == "rocm" ]]; then
			if ! $is_rocm_gpu; then
				printError "No AMD GPU detected"
				exit
			fi
			is_nv_gpu=false
		else
			if ! $is_nv_gpu; then
				printError "No NVIDIA GPU detected"
				exit
			fi
			is_rocm_gpu=false
		fi
	fi

	gpu_path=${input_array[1]}
	if [[ ! -z $gpu_path && ! -d $gpu_path ]]; then
		printError "This GPU Library path '$gpu_path' does not exist."
		exit
	fi
	export_package $gpu_path
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

usage() {
	cat << EOF
Usage: $(basename $0) [OPTIONS]

Options:
	-i, --install-list <pkg[:suffix][,pkg[:suffix]...]>
	                          Comma-separated list of packages to install.
	-c, --conf-external <pkg:path[,pkg:path...]>
	                          Register external/pre-built package(s) by path.
	-l, --list-packages       List all supported packages and exit.
	-p, --path <dir>          Absolute root path (default: <script dir>/softwares).
	                          Build/install directories are created under
	                          <path>/<node short name>/{build,install}; tar
	                          downloads are shared directly under <path>/tars.
	-b, --build-path <dir>    Absolute build/source path override
	                          (default: <path>/<node short name>).
	-t, --tag <str>           Identifier for this build's env file (default:
	                          "default"). Does not affect build/install paths.
	    --force-update        Overwrite the env file if -t/--tag already
	                          identifies one, instead of erroring out.
	    --mpi <flavor[:path]> MPI flavor to use/install (openmpi|openmpi_ucx|impi),
	                          or a path to an existing local MPI installation.
	    --gpu <arch[:path]>   GPU arch to build against (${!gpu_map[@]}),
	                          optionally followed by a path to the GPU SDK.
	-h, --help                Show this help message and exit.

Examples:
	$(basename $0) -i openmpi,osu --mpi openmpi
	$(basename $0) -i hdf5,netcdf_c --mpi openmpi_ucx --gpu a100
	$(basename $0) -l
EOF
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
