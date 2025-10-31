# HPCInstaller
A tool to install HPC Softwares/Benchmarks.


./hpc-install.sh -c libfabric:/bfs3/sw/libfabric/libfabric-mainMay-21-2025-20-33-gcc11.5.0-cuda/  -i nccl,nccl_tests,aws_ofi_nccl --mpi openmpi:/bfs3/sw/mpi/gcc/openmpi-5.0.3-gcc8.5.0-cuda12.6-hfi  --gpu h100:/usr/local/cuda -p /bfs3/rfeki/HPCSoftInstall/nccl -b /home/rfeki/HPCSoftBuild/nccl -s cn5000-mainMay-21-h1


./hpc-install.sh -c libfabric:/usr/  -i nccl,nccl_tests,aws_ofi_nccl --mpi openmpi:/usr/mpi/gcc/openmpi-4.1.6-cuda-hfi/  --gpu a40:/usr/local/cuda -p /bfs3/rfeki/HPCSoftInstall/nccl -b /home/rfeki/HPCSoftBuild/nccl -s opa-a40



./hpc-install.sh -c libfabric:/usr/  -i rccl,rccl_tests,aws_ofi_rccl --mpi openmpi:/bfs3/sw/mpi/gcc/openmpi-5.0.6-gcc11.5.0-rocm6.3.3-ofi/  --gpu mi300x:/opt/rocm-6.3.3/ -p /bfs3/rfeki/HPCSoftInstall/rccl -b /home/rfeki/HPCSoftBuild/rccl -s cn5k-mi300x


./hpc-install.sh -c libfabric:/usr/  -i rccl,rccl_tests,aws_ofi_rccl --mpi openmpi:  --gpu mi300x:/opt/rocm-6.4.3/ -p /home/rfeki/HPCSoftInstall/rccl -s opaOverCN5k-mi200



./hpc-install.sh -c libfabric:/usr/  -i nccl --mpi openmpi  --gpu h100:/usr/local/cuda -p /home/rfeki/HPCSoftBuild/nccl -s 12.0.2.0.13

