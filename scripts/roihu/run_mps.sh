#!/bin/bash -l
#SBATCH --job-name=run_Elmer_roihu_N1_n16_c1_ML1_MPS
#SBATCH --account=project_2001659
#SBATCH --partition=gputest
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=16
#SBATCH --cpus-per-task=1
#SBATCH --gres=gpu:gh200:4
#SBATCH --time=00:15:00
#SBATCH --mem=0
#SBATCH --exclusive
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err

# MESH LEVEL
export MESH_LEVEL="1"

# DIR PATHS
export BASEDIR="/scratch/project_2001659/danieree/rsync/my_ElmerIceEnergy"
export RUNDIR="${BASEDIR}/runs/roihu/N${SLURM_NNODES}_n${SLURM_NTASKS_PER_NODE}_c${SLURM_CPUS_PER_TASK}_ML${MESH_LEVEL}_MPS/run_Elmer_roihu_N${SLURM_NNODES}_n${SLURM_NTASKS_PER_NODE}_c${SLURM_CPUS_PER_TASK}_ML${MESH_LEVEL}_MPS_${SLURM_JOB_ID}"
export SCRIPTSDIR="${BASEDIR}/scripts"
export CONTAINERSDIR="${BASEDIR}/containers"
export INPUTSDIR="${BASEDIR}/inputs"

# OMPI SETTINGS
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}
export PMIX_MCA_gds=hash
export PMIX_MCA_psec=native
export OMPI_MCA_btl=^openib

# CONTAINER PATH
# working, old commit
# export CONTAINER=${CONTAINERSDIR}/container.sif
# current devel, testing...
export CONTAINER=${CONTAINERSDIR}/container_fix.sif

export GREENLAND=${RUNDIR}/Greenland_SSA

# PREPROCESS
mkdir -p ${RUNDIR}
tar -xvzf "${INPUTSDIR}/Greenland_SSA.tar.gz" -C ${RUNDIR}
cd ${GREENLAND}

# ELMERGRID
srun -N1 -n1 apptainer run --bind="$(csc-common-bind),${GREENLAND}" ${CONTAINER} ElmerGrid 2 2 MESH -partdual -metiskway ${SLURM_NTASKS}

# ELMERF90
srun -N1 -n1 apptainer run --bind="$(csc-common-bind),${GREENLAND}" ${CONTAINER} elmerf90 Scalar_OUTPUT.F90 -o Scalar_OUTPUT

# ELMERSOLVER (ranks on this node share the single GH200 GPU via MPS)
start=$(date +%s)
srun -n ${SLURM_NTASKS} --cpu-bind=cores --cpus-per-task=${SLURM_CPUS_PER_TASK} ${SCRIPTSDIR}/roihu/wrapper-start.sh SSA_amgx_ML${MESH_LEVEL}.sif
srun -n ${SLURM_NTASKS} ${SCRIPTSDIR}/roihu/wrapper-stop.sh
end=$(date +%s)

echo "Elapsed time: $(($end-$start)) s"
echo "-----------------------------------"

mv ${GREENLAND}/MESH/*.*vtu ${GREENLAND}/ 2>/dev/null
rm -r ${GREENLAND}/MESH
