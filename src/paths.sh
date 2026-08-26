#!/bin/bash
#
# paths.sh - resolves build/install/log/env paths for a run and writes
# the final environment-loading script.

set_paths() {
	log_file=$THIS_PATH/log/$log_file_name

	# tars/ sits directly under root_path (not under the node dir): the
	# downloaded source archives aren't node/environment-specific, so they're
	# shared and reused across nodes/build variants.
	deps_tar_path=$root_path/tars/

	# Everything node-specific (build/install) lives under root_path/<node
	# short name>, so multiple nodes can safely share the same -p root
	# without clobbering each other's builds.
	node_path=$root_path/$NODE_NAME

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
		build_path=$node_path
	fi
	deps_source_path=$build_path/$deps_source_dir_name
	install_path=$node_path/$deps_install_relative_path

	# --tag/-t only identifies the env file for this build; it never affects
	# build/install paths.
	ENV_FILE_NAME+="_$ftag"
	if [[ ! -z $variant_tag ]]; then
		ENV_FILE_NAME+="$variant_tag"
	fi
	MY_LOAD_ENV_FILE=$THIS_PATH/env/$ENV_FILE_NAME.sh

	if [[ -f $MY_LOAD_ENV_FILE ]] && ! $force_update; then
		printError "Env file '$MY_LOAD_ENV_FILE' already exists for tag '$ftag'. Use --force-update to overwrite it, or pick a different -t|--tag."
		exit
	fi

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
