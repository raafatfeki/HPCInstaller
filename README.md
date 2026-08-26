# hpc-install

A lightweight, dependency-free bash installer for HPC software (MPI, math
libraries, I/O libraries, and GPU-collective/benchmark stacks) built from
source. It is a deliberately simpler alternative to tools like Spack: no
solver, no package DB, no Python dependency -- just a flat registry of
`install_package_<name>()` recipes driven by a handful of CLI flags. The
tradeoff is speed and transparency over automatic dependency resolution:
you tell it what to install and in what order, and it builds exactly that.

## Requirements

- bash, `getopt`, `wget`, `tar`/`unzip`, `git`
- A working C/Fortran toolchain (`gcc`/`gfortran`) and `cmake`
- `lspci`/`lscpu` (used for GPU detection and thread count)

## Quick start

```bash
# List every supported package
./hpc-install.sh -l

# Install OpenMPI, then OSU benchmarks against it
./hpc-install.sh -i openmpi,osu --mpi openmpi

# Install NetCDF + HDF5 against OpenMPI/UCX, targeting an A100 GPU
./hpc-install.sh -i hdf5,netcdf_c --mpi openmpi_ucx --gpu a100

# Load a build's environment afterwards
. env/load_env_default.sh
```

## CLI options

| Flag | Description |
|---|---|
| `-i`, `--install-list <pkg[:suffix][,pkg[:suffix]...]>` | Comma-separated list of packages to install. An optional `:suffix` disambiguates multiple builds of the same package under one root. |
| `-c`, `--conf-external <pkg:path[,pkg:path...]>` | Register an already-built package at `path` instead of building it. |
| `-l`, `--list-packages` | List all supported packages and exit. |
| `-p`, `--path <dir>` | Absolute root path. Default: `<script dir>/softwares`. See [Directory layout](#directory-layout). |
| `-b`, `--build-path <dir>` | Absolute build/source path override. Default: `<path>/<node short name>`. |
| `-t`, `--tag <str>` | Identifier for this build's **env file only**. Default: `default`. Does not affect build/install paths. |
| `--force-update` | Overwrite the env file if `-t`/`--tag` already identifies one, instead of erroring out. |
| `--mpi <flavor[:path]>` | MPI flavor to build/use: `openmpi`, `openmpi_ucx`, or `impi`. Give `:path` to point at an existing local MPI install instead of building one. |
| `--gpu <arch[:path]>` | GPU arch to build against (`p100`, `gp100`, `a40`, `a100`, `h100`, `rocm`). Give `:path` to point at an existing CUDA/ROCm SDK. |
| `-h`, `--help` | Show usage and exit. |

## Directory layout

```
<script dir>/
├── hpc-install.sh
├── log/                                   # one log file per invocation
├── env/                                   # generated "load_env_*.sh" files
└── src/
    ├── common.sh      # colors, print helpers, export_package, version_compare
    ├── config.sh      # global defaults/state + the pkg_info_* package registry
    ├── cli.sh         # option parsing, --mpi/--gpu resolution, usage/list text
    ├── paths.sh       # path resolution + env-file generation
    ├── build.sh       # generic make/cmake/libtool/git drivers, dependency checks
    └── packages.sh    # one install_package_<name>() recipe per package

<root_path>/                               # default: <script dir>/softwares
├── tars/                                  # downloaded source archives (shared
│                                           # across nodes/build variants)
└── <node short name>/                     # $(hostname -s)
    ├── build/<os>-<ver>-<arch>[-mpi][-gpu]/
    └── install/<os>-<ver>-<arch>[-mpi][-gpu]/
```

Key points:

- **`-p` is absolute** and defaults to a `softwares/` directory next to
  `hpc-install.sh` itself (not the caller's working directory).
- **Build/install are namespaced by node**, so several machines can safely
  point at the same `-p` root (e.g. a shared filesystem) without clobbering
  each other's builds.
- **`tars/` is shared**, not per-node: source archives aren't
  environment-specific, so they're downloaded once and reused.
- **`--mpi`/`--gpu` namespace build/install paths too**, but only when
  explicitly passed -- a plain run with no flags keeps the same path it
  always would, so nothing existing gets orphaned.
- **`-t`/`--tag` only names the env file**, e.g. `env/load_env_default.sh`
  or `env/load_env_default-openmpi_ucx-a100.sh`. It's how you keep several
  parallel "named" builds (e.g. `debug` vs `release`) distinguishable
  without duplicating build/install trees. If a tag's env file already
  exists, the run stops with an error -- pass `--force-update` to overwrite
  it intentionally.

## Supported packages

Run `./hpc-install.sh -l` for the authoritative, live list. As of writing:

- **Core / MPI**: `openmpi`, `openmpi_ucx`, `impi` (external-path only), `cmake`, `autoconf`
- **I/O & math libraries**: `hdf5`, `netcdf_c`, `netcdf_fortran`, `netcdf`, `lapack`, `json_fortran`, `gslib`, `parmetis`
- **Benchmarks**: `osu`, `imb`, `neko`, `arrhenius_benchmarks`, `ior`
- **NCCL-based (NVIDIA)**: `nccl`, `nccl_tests`, `psm2_nccl`, `aws_ofi_nccl`
- **RCCL-based (AMD)**: `rccl`, `rccl_tests`, `aws_ofi_rccl`
- **Infiniband**: `ucx`, `ucc`
- **Other**: `madmpi`

`gcc` is auto-detected from the environment and appears in `-l` for
version-checking purposes only -- it has no `install_package_gcc` recipe.
`mpi`/`compiler` are pseudo-entries resolved via `--mpi`/auto-detection,
not installed directly.

## External / pre-built packages

If a package (or a dependency like an MPI or CUDA install) already exists
on the system, register it instead of rebuilding it:

```bash
./hpc-install.sh -i osu --mpi openmpi -c hdf5:/opt/hdf5-1.14
```

`-c` accepts a comma-separated `pkg:path` list; each path is exported into
`PATH`/`LD_LIBRARY_PATH`/`PKG_CONFIG_PATH` exactly like a package this
script built itself.

## Adding a new package

1. Add a `pkg_info_<name>` associative array to `src/config.sh` (at minimum
   `version` and `sub_version`).
2. Add an `install_package_<name>()` function to `src/packages.sh`, using
   the generic drivers in `src/build.sh` (`make_install`, `cmake_install`,
   `libtool_install`, `make_config_install`) where they fit, and
   `pkg_requires_pkgs`/`pkg_requires_bin` to assert prerequisites.
3. It's picked up automatically -- `available_softwares` is built at
   load time by scanning for `pkg_info_*` variables in `src/config.sh`.

## Logs

Every run appends to `log/log_<node short name>_hpc.log`. Check it first
when a build fails -- the CLI only prints short status lines, all
tool output (`configure`/`make`/`cmake`) is redirected there.
