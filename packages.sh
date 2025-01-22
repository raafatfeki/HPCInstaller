#!/bin/bash
#

install_package_cmake() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	package_url="https://cmake.org/files/v$package_version/cmake-$package_version.$package_sub_version.tar.gz"

	download_untar_cd_package $package_url

	echo -e "\t\t* ./bootstrap --prefix=$package_prefix"
	./bootstrap --prefix=$package_prefix >> $log_file 2>&1 
	[ $? != 0 ] && printError "./bootstrap" && exit
	echo -e "\t\t* make -j install"
	make -j install >> $log_file 2>&1
	[ $? != 0 ] && printError "make" && exit
}

install_package_openmpi() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	package_url="https://download.open-mpi.org/release/open-mpi/v$package_version/openmpi-$package_version.$package_sub_version.tar.gz"
	package_build_extra_options="$(get_libtool_gpu_conf) --with-ofi --with-psm2 --enable-mpi1-compatibility --enable-shared --enable-dlopen"
	package_tar_rename=""

	libtool_install $package_name $package_prefix $package_url "$package_build_extra_options" $package_tar_rename
}

install_package_hdf5() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	package_url="https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-$package_version/hdf5-$package_version.$package_sub_version/src/hdf5-$package_version.$package_sub_version.tar.gz"
	package_build_extra_options="--enable-fortran --enable-parallel --enable-build-mode=production"
	package_tar_rename=""

	libtool_install $package_name $package_prefix $package_url "$package_build_extra_options" $package_tar_rename
}

install_package_netcdf_c() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	package_url="https://downloads.unidata.ucar.edu/netcdf-c/$package_version.$package_sub_version/netcdf-c-$package_version.$package_sub_version.tar.gz"
	# package_build_extra_options="--enable-hdf5 --disable-libxml2 --disable-byterange --with-mpiexec=`command -v mpirun` 'CPPFLAGS=-I${pkg_info_hdf5['prefix']}/include -I${pkg_info_mpi['prefix']}/include' 'LDFLAGS=-L${pkg_info_hdf5['prefix']}/lib' 'LIBS=-lhdf5_hl -lhdf5'"
	package_build_extra_options="--enable-hdf5 --with-mpiexec=`command -v mpirun` 'CPPFLAGS=-I${pkg_info_hdf5['prefix']}/include -I${pkg_info_mpi['prefix']}/include' 'LDFLAGS=-L${pkg_info_hdf5['prefix']}/lib' 'LIBS=-lhdf5_hl -lhdf5'"
	package_tar_rename=""

	printf "${YELLOW}\t\t Warning:${NC}\n"
	printf "${YELLOW}\t\t\t Manually install libxml2-devel and remove --disable-libxml2 from script for xml2 support.${NC}\n"
	printf "${YELLOW}\t\t\t Manually install libcurl-devel and remove --disable-byterange from script for byterange support.${NC}\n"
	libtool_install $package_name $package_prefix $package_url "$package_build_extra_options" $package_tar_rename
}

install_package_netcdf_fortran() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	package_url="https://downloads.unidata.ucar.edu/netcdf-fortran/$package_version.$package_sub_version/netcdf-fortran-$package_version.$package_sub_version.tar.gz"
	export NCDIR=${pkg_info_netcdf_c["prefix"]}
	export NFDIR=$package_prefix
	package_build_extra_options="--with-mpiexec=`command -v mpirun` CPPFLAGS='-I${NCDIR}/include' LDFLAGS='-L${NCDIR}/lib'"
	package_tar_rename=""

	libtool_install $package_name $package_prefix $package_url "$package_build_extra_options" $package_tar_rename
}

install_package_netcdf() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4

	echo -e "\t\t Combine netcdf-c and netcdf-fortran under $package_prefix"
	mkdir -p $package_prefix
	rsync -a -u "${pkg_info_netcdf_c['prefix']}/" $package_prefix
	rsync -a -u "${pkg_info_netcdf_fortran['prefix']}/" $package_prefix
}

install_package_madmpi() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	package_url="https://pm2.gitlabpages.inria.fr/releases/mpibenchmark-$package_version.$package_sub_version.tar.gz"
	package_build_extra_options="MPICC=`command -v mpicc`"
	package_tar_rename=""

	libtool_install $package_name $package_prefix $package_url "$package_build_extra_options" $package_tar_rename
	mkdir -p "$package_prefix/share"
	echo 
	cp -r "./plot" "$package_prefix/share/"
	sed -i  "s%\./plot%${package_prefix}/share/plot%g" ${package_prefix}/bin/mpi_bench_extract
}

install_package_autoconf() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	package_url="https://alpha.gnu.org/pub/gnu/autoconf/autoconf-$package_version.$package_sub_version.tar.gz"
	package_build_extra_options="None"
	package_tar_rename=""

	libtool_install $package_name $package_prefix $package_url "$package_build_extra_options" $package_tar_rename
}

install_package_nccl() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	package_url="https://github.com/NVIDIA/nccl/archive/refs/tags/v$package_version.$package_sub_version.tar.gz"
	package_build_extra_options="src.build BUILDDIR=$package_prefix"
	package_tar_rename="nccl-$package_version.$package_sub_version"

	if [[ ! -z $gpu_arch && ! -z ${gpu_map[$gpu_arch]} ]]; then
		package_build_extra_options+=" NVCC_GENCODE=\"-gencode=arch=compute_${gpu_map[$gpu_arch]},code=sm_${gpu_map[$gpu_arch]}\""
	fi

	if [[ ! -z $gpu_path ]]; then
		package_build_extra_options+=" CUDA_HOME=$gpu_path"
	fi
	make_install $package_name $package_prefix $package_url "$package_build_extra_options" $package_tar_rename
}

install_package_nccl_tests() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	package_url="https://github.com/NVIDIA/nccl-tests/archive/refs/tags/v$package_version.$package_sub_version.tar.gz"
	package_build_extra_options="BUILDDIR=$package_prefix/bin MPI=1 MPI_HOME=${pkg_info_mpi['prefix']} NCCL_HOME=${pkg_info_nccl['prefix']}"
	package_tar_rename="nccl-tests-$package_version.$package_sub_version"

	make_install $package_name $package_prefix $package_url "$package_build_extra_options" $package_tar_rename
}

install_package_psm2_nccl() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	package_url="https://github.com/cornelisnetworks/psm2-nccl/archive/refs/tags/v$package_version.$package_sub_version.tar.gz"
	package_build_extra_options="BUILDDIR=$package_prefix/lib CC=gcc LD=gcc PSM2_INCLUDE=/usr/include/ PSM2_LIB=/usr/lib64/"
	package_tar_rename="psm2-nccl-$package_version.$package_sub_version"

	mkdir -p $package_prefix/lib
	make_install $package_name $package_prefix $package_url "$package_build_extra_options" $package_tar_rename
}

install_package_aws_ofi_nccl() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	package_url="https://github.com/aws/aws-ofi-nccl/releases/download/v$package_version.$package_sub_version-aws/aws-ofi-nccl-$package_version.$package_sub_version-aws.tar.gz"
	package_build_extra_options="--with-mpi=${pkg_info_mpi['prefix']} --with-hwloc"
	package_tar_rename=""

	if [[ ! -z $gpu_path ]]; then
		package_build_extra_options+=" --with-cuda=$gpu_path"
	fi

	package_build_extra_options+=" --with-libfabric="
	if [[ -n ${pkg_info_libfabric["prefix"]} ]]; then
		package_build_extra_options+="${pkg_info_libfabric["prefix"]}"
	else
		package_build_extra_options+="/usr"
	fi
	libtool_install $package_name $package_prefix $package_url "$package_build_extra_options" $package_tar_rename
}

install_package_rccl() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	package_url="https://github.com/ROCm/rccl/archive/refs/tags/rocm-$package_version.$package_sub_version.tar.gz"
	package_tar_rename="rccl-rocm-$package_version.$package_sub_version"

	download_untar_cd_package $package_url $package_tar_rename
	echo -e "\t\t* ./install.sh -i --prefix=$package_prefix -l -j $max_threads"

	./install.sh -i --prefix=$package_prefix -l -j $max_threads  >> $log_file 2>&1 
	[ $? != 0 ] && printError "./install.sh" && exit
}

install_package_rccl_tests() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	# package_url="https://github.com/cornelisnetworks/libfabric-tests/blob/master/Validation/Performance/tars/rccl-tests/develop-20240919.zip"
	package_url="https://github.com/ROCm/rccl-tests/archive/refs/heads/develop.zip"
	package_tar_rename="rccl-tests-develop"

	download_untar_cd_package $package_url $package_tar_rename "zip"
	echo -e "\t\t* ./install.sh -m --mpi_home=${pkg_info_mpi['prefix']} --rccl_home=${pkg_info_rccl['prefix']}"

	./install.sh -m --mpi_home=${pkg_info_mpi['prefix']} --rccl_home=${pkg_info_rccl['prefix']} >> $log_file 2>&1 
	mkdir -p "$package_prefix/bin"
	find build -type f -executable -exec cp {} "$package_prefix/bin" \;
	[ $? != 0 ] && printError "./install.sh" && exit
}

install_package_aws_ofi_rccl() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	package_url="https://github.com/ROCm/aws-ofi-rccl/archive/refs/heads/cxi.zip"
	package_build_extra_options="--with-libfabric=/usr/ --with-hip=$gpu_path --with-mpi=${pkg_info_mpi['prefix']} --with-rccl=${pkg_info_rccl['prefix']}"
	package_tar_rename="aws-ofi-rccl-cxi"


	libtool_install $package_name $package_prefix $package_url "$package_build_extra_options" $package_tar_rename "zip"
}

install_package_ucx() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	package_url="https://github.com/openucx/ucx/releases/download/v$package_version.$package_sub_version/ucx-$package_version.$package_sub_version.tar.gz"
	package_build_extra_options=$(get_libtool_gpu_conf)
	package_tar_rename=""

	libtool_install $package_name $package_prefix $package_url "$package_build_extra_options" $package_tar_rename
}

install_package_ucc() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	package_url="https://github.com/openucx/ucc/archive/refs/tags/v$package_version.$package_sub_version.tar.gz"
	package_build_extra_options="$(get_libtool_gpu_conf) --with-ucx=${pkg_info_ucx['prefix']}"
	package_tar_rename="ucc-$package_version.$package_sub_version"

	libtool_install $package_name $package_prefix $package_url "$package_build_extra_options" $package_tar_rename
}

install_package_openmpi_ucx() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	package_url="https://download.open-mpi.org/release/open-mpi/v$package_version/openmpi-$package_version.$package_sub_version.tar.gz"
	package_build_extra_options="$(get_libtool_gpu_conf) --with-ucx=${pkg_info_ucx['prefix']} --with-ucc=${pkg_info_ucc['prefix']} --with-ofi --with-psm2 --enable-mpi1-compatibility --enable-shared --enable-dlopen"
	package_tar_rename=""

	libtool_install $package_name $package_prefix $package_url "$package_build_extra_options" $package_tar_rename
}

install_package_osu() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	package_url="https://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-$package_version.$package_sub_version.tar.gz"
	package_build_extra_options="$(get_libtool_gpu_conf) CFLAGS=-I${pkg_info_mpi['prefix']}/include LDFLAGS=-L${pkg_info_mpi['prefix']}/lib CC=${pkg_info_mpi['CC']} CXX=${pkg_info_mpi['CXX']} F77=${pkg_info_mpi['F77']} FC=${pkg_info_mpi['FC']}"
	package_tar_rename=""

	if [[ ! -z $gpu_arch ]]; then
		package_build_extra_options+=" --enable-cuda "
	fi

	# ${pkg_info_mpi['prefix']}/bin/
	# We can add --with-rccl and --with-nccl
	libtool_install $package_name $package_prefix $package_url "$package_build_extra_options" $package_tar_rename

	mkdir -p $package_prefix/bin
	find $package_prefix/libexec/osu-micro-benchmarks/mpi/ -type f -executable -exec cp {} $package_prefix/bin \;
}

install_package_imb() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	package_url=https://github.com/intel/mpi-benchmarks/archive/refs/tags/IMB-v$package_version.$package_sub_version.tar.gz
	package_build_extra_options="LDFLAGS=-L${pkg_info_mpi['prefix']}/lib CC=${pkg_info_mpi['CC']} CXX=${pkg_info_mpi['CXX']} F77=${pkg_info_mpi['F77']} FC=${pkg_info_mpi['FC']}"
	package_tar_rename="mpi-benchmarks-IMB-v$package_version.$package_sub_version"

	mkdir -p $package_prefix/bin
	make_install $package_name $package_prefix $package_url "$package_build_extra_options" $package_tar_rename
	cp IMB-EXT IMB-MPI1 IMB-NBC IMB-RMA IMB-IO IMB-MT IMB-P2P $package_prefix/bin

	if [[ ! -z $gpu_arch ]]; then
		echo -e "\n\t- Install IMB-MPI1-GPU"
		if [[ ! -z $gpu_path ]]; then
			package_build_extra_options="IMB-MPI1-GPU CFLAGS=-Wno-error=unused-value CUDA_INCLUDE_DIR=$gpu_path/include "$package_build_extra_options
		else
			package_build_extra_options="IMB-MPI1-GPU CFLAGS=-Wno-error=unused-value CUDA_INCLUDE_DIR=/usr/local/cuda/include "$package_build_extra_options
		fi
		make_install $package_name $package_prefix $package_url "$package_build_extra_options" $package_tar_rename
		cp IMB-MPI1-GPU $package_prefix/bin
	fi
}

install_package_json_fortran() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	package_url=https://github.com/jacobwilliams/json-fortran/archive/refs/tags/$package_version.$package_sub_version.tar.gz
	package_build_extra_options="-DUSE_GNU_INSTALL_CONVENTION=ON"
	package_tar_rename="json-fortran-$package_version.$package_sub_version"

	pkg_requires "cmake"
	cmake_install $package_name $package_prefix $package_url "$package_build_extra_options" $package_tar_rename
}

install_package_lapack() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	package_url="https://github.com/Reference-LAPACK/lapack/archive/refs/tags/v$package_version.$package_sub_version.tar.gz"
	cmake_extra_options="None"
	package_tar_rename="$package_name-$package_version.$package_sub_version"

	cmake_install $package_name $package_prefix $package_url "$cmake_extra_options" $package_tar_rename
}

install_package_neko() {
	package_name=$1
	package_version=$2
	package_sub_version=$3
	package_prefix=$4
	package_url=https://github.com/ExtremeFLOW/neko/releases/download/v$package_version.$package_sub_version/neko-$package_version.$package_sub_version.tar.gz
	package_build_extra_options="$(get_libtool_gpu_conf) --with-lapack=$(get_lib ${pkg_info_lapack['prefix']} liblapack.a)/liblapack.a  --with-blas=$(get_lib ${pkg_info_lapack['prefix']} libblas.a)/libblas.a --enable-device-mpi CFLAGS=-I${pkg_info_mpi['prefix']}/include LDFLAGS=-L${pkg_info_mpi['prefix']}/lib CC=gcc MPICC=${pkg_info_mpi['CC']} MPIFC=${pkg_info_mpi['FC']} MPICXX=${pkg_info_mpi['CXX']} FC=gfortran FCFLAGS='-O2 -pedantic -std=f2008'"
	package_tar_rename=""

	# --enable-real=dp
	# --with-blas=
	# --with-lapack=
	# --with-cuda
	# --with-nccl
	# --with-rccl
	# --with-hdf5
	pkg_requires "mpicc"


	if [[ ! -z $gpu_arch && ! -z ${gpu_map[$gpu_arch]} ]]; then
		package_build_extra_options+=" CUDA_CFLAGS=-O3 CUDA_ARCH=-arch=sm_${gpu_map[$gpu_arch]} NVCC=$gpu_path/bin/nvcc "
	fi

	libtool_install $package_name $package_prefix $package_url "$package_build_extra_options" $package_tar_rename
}
