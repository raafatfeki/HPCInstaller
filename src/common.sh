#!/bin/bash
#
# common.sh - generic, reusable helpers with no dependency on install-flow
# state: colors, logging/print helpers, version comparison, environment
# export helpers.

NC='\033[0m' # No Color
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLDGREEN='\033[1;32m'
YELLOW='\033[0;33m'

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

version_compare() {
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

check_version_requirement() {
	local op
	version_compare $1 $2
	case $? in
		0) op='=';;
		1) op='>';;
		2) op='<';;
	esac
	if [[ $op != $3 ]]
	then
		echo -e "\t- Version of '$4' Not Supported: Expected $1 $3 $2, Actual $1 $op $2"
		return 1
	else
		echo -e "\t- Version of '$4' Supported: '$1 $op $2'"
		return 0
	fi
}
