#!/bin/bash -l
#SBATCH --ntasks-per-node=16
#SBATCH --cpus-per-task=2
#SBATCH --nodes=1
#SBATCH --partition=boost_usr_prod
#SBATCH --time=0:30:00
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --job-name=run_Elmer_leonardo_N1_n16_c2_ML3
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --gres=gpu:4
#SBATCH --qos=boost_qos_dbg

module load cuda/12.2
module load openmpi/4.1.6--gcc--12.2.0

#MESH LEVEL
export MESH_LEVEL="3"

# DIR PATHS
export BASEDIR="/leonardo_work/cin_emon/uc/Marco/ElmerIceEnergy"
export RUNDIR="${BASEDIR}/runs/Leonardo_profile/N${SLURM_NNODES}_n${SLURM_NTASKS_PER_NODE}_c${SLURM_CPUS_PER_TASK}_ML${MESH_LEVEL}/run_Elmer_leonardo_N${SLURM_NNODES}_n${SLURM_NTASKS_PER_NODE}_c${SLURM_CPUS_PER_TASK}_ML${MESH_LEVEL}_${SLURM_JOB_ID}"
export SCRIPTSDIR="${BASEDIR}/scripts"
export CONTAINERSDIR="${BASEDIR}/containers"
export INPUTSDIR="${BASEDIR}/inputs"

# OMPI SETTINGS
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}
export PMIX_MCA_gds=hash
export PMIX_MCA_psec=native
export OMPI_MCA_btl=^openib 

# CONTAINERPATH
export CONTAINER=${CONTAINERSDIR}/Elmer_ubuntu24_leonardo.sif
export GREENLAND=${RUNDIR}/Greenland_SSA

# PREPROCESS
mkdir -p ${RUNDIR}
tar -xvzf "${INPUTSDIR}/Greenland_SSA.tar.gz" -C ${RUNDIR}
cd ${GREENLAND}

export NSYS_TMP=${GREENLAND}/tmp
export NSYS_OUTPUT=${GREENLAND}/profiles
mkdir -p $NSYS_TMP
mkdir -p $NSYS_OUTPUT

export PROFILE="nsys profile --trace=cuda,nvtx,mpi,osrt,ucx --sample=none --cpuctxsw=process-tree -o ${NSYS_OUTPUT}/nsys_prof_noMPS.%p"
# export PROFILE="nsys profile --trace=cuda,nvtx,mpi,osrt --sample=none --cpuctxsw=none -o ${NSYS_OUTPUT}/nsys_prof_noMPS.%p"
# ELMERGRID
srun -N1 -n1 singularity exec -B ${GREENLAND} --nv ${CONTAINER} ElmerGrid 2 2 MESH -partdual -metiskway ${SLURM_NTASKS}

# ELMERF90
srun -N1 -n1 singularity exec -B ${GREENLAND} --nv ${CONTAINER} elmerf90 Scalar_OUTPUT.F90 -o Scalar_OUTPUT

# ELMERSOLVER
start=$(date +%s)
srun -n ${SLURM_NTASKS} --cpu-bind=cores --cpus-per-task=${SLURM_CPUS_PER_TASK} singularity exec -B ${GREENLAND} -B ${NSYS_TMP}:/tmp --env UCX_POSIX_USE_PROC_LINK=n --nv ${CONTAINER} ${PROFILE} ElmerSolver_mpi SSA_amgx_ML${MESH_LEVEL}.sif
end=$(date +%s)

echo "Elapsed time: $(($end-$start)) s"
echo "-----------------------------------"
rm -r ${GREENLAND}/MESH

