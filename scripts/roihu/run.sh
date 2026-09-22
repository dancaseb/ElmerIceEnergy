#!/bin/bash -l

# MESH LEVEL
export MESH_LEVEL=$1

# RANK LAYOUT (job is submitted as a single Slurm task owning the whole node;
# mpirun inside the container does the actual rank fan-out — see queue_jobs.sh)
export RANKS=$2
export CPUS_PER_RANK=$((SLURM_CPUS_PER_TASK / RANKS))
export TOTAL_CPUS=$3

# DIR PATHS
export BASEDIR="/scratch/project_2001659/danieree/rsync/my_ElmerIceEnergy"
export RUNDIR="${BASEDIR}/runs/roihu/TALP/N${SLURM_NNODES}_n${RANKS}_c${CPUS_PER_RANK}_ML${MESH_LEVEL}/run_Elmer_roihu_N${SLURM_NNODES}_n${RANKS}_c${CPUS_PER_RANK}_ML${MESH_LEVEL}_${SLURM_JOB_ID}"
export SCRIPTSDIR="${BASEDIR}/scripts"
export CONTAINERSDIR="${BASEDIR}/containers"
export INPUTSDIR="${BASEDIR}/inputs"

# OMPI SETTINGS
export OMP_NUM_THREADS=${CPUS_PER_RANK}
export PMIX_MCA_gds=hash
export PMIX_MCA_psec=native
export OMPI_MCA_btl=^openib

# CONTAINER PATH
export CONTAINER="/scratch/project_2001659/danieree/rsync/my_ElmerIceEnergy/containers/container.sif"

export GREENLAND=${RUNDIR}/Greenland_SSA

# PREPROCESS
mkdir -p ${RUNDIR}
tar -xvzf "${INPUTSDIR}/Greenland_SSA.tar.gz" -C ${RUNDIR}
cd ${GREENLAND}

# ELMERGRID
srun -N1 -n1 apptainer run --bind="$(csc-common-bind),${GREENLAND}" ${CONTAINER} ElmerGrid 2 2 MESH -partdual -metiskway ${RANKS}

# ELMERF90
srun -N1 -n1 apptainer run --bind="$(csc-common-bind),${GREENLAND}" ${CONTAINER} elmerf90 Scalar_OUTPUT.F90 -o Scalar_OUTPUT

# ELMERSOLVER
# Core binding: pinning ranks to specific cores (--bind-to core) crashes if this job
# doesn't own every core on the node — mpirun can pick a core outside what Slurm
# granted it. Skip pinning whenever cpus-per-task is less than the full node.

# TODO: check if pinning has any performance impact
if [ "${SLURM_CPUS_PER_TASK}" -eq "${TOTAL_CPUS}" ]; then
    BIND_ARGS=(--bind-to core --map-by "node:PE=${CPUS_PER_RANK}")
else
    BIND_ARGS=(--bind-to none)
fi

# TALP (DLB): set TALP=1 in the environment to LD_PRELOAD libdlb_mpi.so and
# have it dump a per-run efficiency report; see analysis/talp_compare.py.
export DLB_PREFIX="/opt/dlb"
APPTAINER_ENV_ARGS=(--env UCX_POSIX_USE_PROC_LINK=n)
if [ "${TALP:-0}" = "1" ]; then
    APPTAINER_ENV_ARGS+=(
        --env LD_PRELOAD="${DLB_PREFIX}/lib/libdlb_mpi.so"
        --env DLB_ARGS="--talp --talp-output-file=ElmerIce_Talp_N${SLURM_NNODES}_n${RANKS}_c${CPUS_PER_RANK}_ML${MESH_LEVEL}_${SLURM_JOB_ID}.json"
    )
fi

start=$(date +%s)
srun -N1 -n1 apptainer run --nv --bind="$(csc-common-bind),${GREENLAND}" "${APPTAINER_ENV_ARGS[@]}" ${CONTAINER} \
    env -u SLURM_JOBID -u SLURM_JOB_ID -u SLURM_NTASKS -u SLURM_NPROCS -u SLURM_NODELIST -u SLURM_STEP_NODELIST \
        -u SLURM_STEP_ID -u SLURM_PROCID -u SLURM_LOCALID -u SLURM_NODEID \
    mpirun -np ${RANKS} --host localhost:${RANKS} "${BIND_ARGS[@]}" ElmerSolver_mpi SSA_amgx_ML${MESH_LEVEL}.sif
end=$(date +%s)

echo "Elapsed time: $(($end-$start)) s"
echo "-----------------------------------"


# Check the results
rm -r ${GREENLAND}/MESH
