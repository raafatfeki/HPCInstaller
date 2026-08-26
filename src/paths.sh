#!/bin/bash
#
# paths.sh - resolves build/install/log/env paths for a run and writes
# the final environment-loading script.

set_paths() {
	root_path=$root_path-$outputsuffix
	log_file=$THIS_PATH/log/$log_file_name
	deps_tar_path=$root_path/tars/

	# Namespace build/install paths by MPI flavor and GPU arch, but only when
	# --mpi/--gpu were explicitly passed -- otherwise the default path layout
	# stays exactly as before, so existing installs aren't orphaned.
	variant_tag=""
	if $is_mpi; then
		variant_tag+="-$mpi_flavor"
	fi
	if $is_gpu_support; then
		variant_tag+="-$gpu_arch"
	fi
	deps_source_dir_name+="$variant_tag"
	deps_install_relative_path+="$variant_tag"

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
	if [[ ! -z $variant_tag ]]; then
		ENV_FILE_NAME+="$variant_tag"
	fi
	MY_LOAD_ENV_FILE=$THIS_PATH/env/$ENV_FILE_NAME.sh
	mkdir -p $deps_tar_path $deps_source_path $install_path $THIS_PATH/log $THIS_PATH/env
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
