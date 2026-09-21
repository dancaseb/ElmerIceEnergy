#!/bin/bash -l
# MESH LEVEL
export MESH_LEVEL=$1

# RANK LAYOUT (job is submitted as a single Slurm task owning the whole node;
# mpirun inside the container does the actual rank fan-out — see queue_jobs_mps.sh)
export RANKS=$2
export CPUS_PER_RANK=$((SLURM_CPUS_PER_TASK / RANKS))
export TOTAL_CPUS=$3

# DIR PATHS
export BASEDIR="/scratch/project_2001659/danieree/rsync/my_ElmerIceEnergy"
export RUNDIR="${BASEDIR}/runs/roihu/TALP/N${SLURM_NNODES}_n${RANKS}_c${CPUS_PER_RANK}_ML${MESH_LEVEL}_MPS/run_Elmer_roihu_N${SLURM_NNODES}_n${RANKS}_c${CPUS_PER_RANK}_ML${MESH_LEVEL}_MPS_${SLURM_JOB_ID}"
export SCRIPTSDIR="${BASEDIR}/scripts"
export CONTAINERSDIR="${BASEDIR}/containers"
export INPUTSDIR="${BASEDIR}/inputs"

# OMPI SETTINGS
export OMP_NUM_THREADS=${CPUS_PER_RANK}
export PMIX_MCA_gds=hash
export PMIX_MCA_psec=native
export OMPI_MCA_btl=^openib

# CONTAINER PATH
# working, old commit
# export CONTAINER=${CONTAINERSDIR}/container.sif
# current devel, testing...
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

# ELMERSOLVER (ranks share the single GH200 GPU via MPS)
# one container start for the whole node; mpirun inside fans out to RANKS ranks x CPUS_PER_RANK cores each,
# all sharing the MPS pipe set up by wrapper-start.sh below (sourced so its exports reach this shell)
#
# Core binding: mpirun's own --bind-to/--map-by (via hwloc) only works when the cgroup owns the
# whole node (every core ID it might pick is valid). When cpus-per-task is a subset of the node
# (TOTAL_CPUS), hwloc can try to bind to a physical core the cgroup never granted this job and
# fails with "hwloc_set_cpubind returned Error" — so skip explicit binding in that case.
if [ "${SLURM_CPUS_PER_TASK}" -eq "${TOTAL_CPUS}" ]; then
    BIND_ARGS=(--bind-to core --map-by "node:PE=${CPUS_PER_RANK}")
else
    BIND_ARGS=(--bind-to none)
fi

start=$(date +%s)
source ${SCRIPTSDIR}/roihu/wrapper-start.sh
srun -N1 -n1 apptainer run --nv --bind="$(csc-common-bind),${GREENLAND}" --env UCX_POSIX_USE_PROC_LINK=n ${CONTAINER} \
    env -u SLURM_JOBID -u SLURM_JOB_ID -u SLURM_NTASKS -u SLURM_NPROCS -u SLURM_NODELIST -u SLURM_STEP_NODELIST \
        -u SLURM_STEP_ID -u SLURM_PROCID -u SLURM_LOCALID -u SLURM_NODEID \
    mpirun -np ${RANKS} --host localhost:${RANKS} "${BIND_ARGS[@]}" ElmerSolver_mpi SSA_amgx_ML${MESH_LEVEL}.sif
${SCRIPTSDIR}/roihu/wrapper-stop.sh
end=$(date +%s)

echo "Elapsed time: $(($end-$start)) s"
echo "-----------------------------------"

# mv ${GREENLAND}/MESH/*.*vtu ${GREENLAND}/ 2>/dev/null
rm -r ${GREENLAND}/MESH
