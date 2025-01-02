source `dirname $0`/installer_utils.sh

get_options $*

if [[ ${#software_to_install[@]} -eq 0 ]]; then
	printError "All requested packages are not supported, Please choose a software from this list."
	list_packages
	exit
fi

echo "Install Softwares:"
set_paths

for package_name in ${software_to_install[@]}; do
	declare -n pkg="pkg_info_${package_name}" 

	package_version=${pkg["version"]}
	package_sub_version=${pkg["sub_version"]}
	package_base_prefix=$package_name-$package_version.$package_sub_version

	if [[ -n ${software_suffixes[$package_name]} ]]; then
		package_base_prefix+="-${software_suffixes[$package_name]}"
	fi
	pkg["base_prefix"]=$package_base_prefix
	package_prefix=$install_path/$package_base_prefix
	pkg["prefix"]=$package_prefix

	if [[ ! -d $package_prefix ]]; then
		echo -e "\t- Installing $package_name Version $package_version.$package_sub_version under $package_prefix"
		if $to_install; then
			install_package_$package_name $package_name $package_version $package_sub_version $package_prefix
		fi
	else
		echo -e "\t- $package_name Version $package_version already installed under $package_prefix"
	fi
	export_package $package_prefix
done

echo "Create load_env script."
echo -e "\t-Command to load: \". $MY_LOAD_ENV_FILE\""
create_load_env $MY_LOAD_ENV_FILE
