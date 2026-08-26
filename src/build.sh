#!/bin/bash
#
# build.sh - generic build-system drivers (make/cmake/libtool/git) shared
# by the package recipes in packages.sh, plus package/binary dependency
# assertions used by those recipes.

get_libtool_gpu_conf() {
	package_build_extra_options=""
	if $is_gpu_support; then
		if $is_rocm_gpu; then
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
		[ $? != 0 ] && printWarn "./autogen.sh failed or not needed. If configure fails, then re-check this."
	elif [[ -f autogen.pl ]]; then
		echo -e "\t\t* ./autogen.pl"
		./autogen.pl >> $log_file 2>&1
		[ $? != 0 ] && printWarn "./autogen.pl failed or not needed. If configure fails, then re-check this."
	elif [[ -f bootstrap ]]; then
		echo -e "\t\t* ./bootstrap"
		./bootstrap >> $log_file 2>&1
		[ $? != 0 ] && printWarn "./bootstrap failed or not needed. If configure fails, then re-check this."
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
			if ! $is_gpu_support; then
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
