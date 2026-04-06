#!/bin/bash -l
#SBATCH --ntasks-per-node=8
#SBATCH --cpus-per-task=4
#SBATCH --nodes=2
#SBATCH --partition=boost_usr_prod
#SBATCH --time=0:30:00
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --job-name=run_Elmer_leonardo_N2_n8_c4_ML3
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --gres=gpu:4
#SBATCH --qos=boost_qos_dbg

module load openmpi/4.1.6--gcc--12.2.0

# CINEMON
export PRESERVE_TIMESERIES=1
export CINEMON="/leonardo_work/cin_emon/git/cinemon-public/build/cinemon"

#MESH LEVEL
export MESHLEVEL="ML3"

# DIR PATHS
export BASEDIR="/leonardo_work/cin_emon/uc/Marco/ElmerIceEnergy"
export RUNDIR="${BASEDIR}/runs/Leonardo/run_Elmer_leonardo_N${SLURM_NNODES}_n${SLURM_NTASKS_PER_NODE}_c${SLURM_CPUS_PER_TASK}_${MESHLEVEL}_${SLURM_JOB_ID}"
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

# ELMERGRID
srun -N1 -n1 singularity exec -B ${GREENLAND} --nv ${CONTAINER} ElmerGrid 2 2 MESH -partdual -metiskway ${SLURM_NTASKS}

# ELMERF90
srun -N1 -n1 singularity exec -B ${GREENLAND} --nv ${CONTAINER} elmerf90 Scalar_OUTPUT.F90 -o Scalar_OUTPUT

# ELMERSOLVER
start=$(date +%s)
srun -n ${SLURM_NTASKS} --cpu-bind=cores --cpus-per-task=${SLURM_CPUS_PER_TASK} ${CINEMON} singularity exec -B ${GREENLAND} --env UCX_POSIX_USE_PROC_LINK=n --nv ${CONTAINER} ElmerSolver_mpi SSA_amgx_${MESHLEVEL}.sif
end=$(date +%s)

echo "Elapsed time: $(($end-$start)) s"
echo "-----------------------------------"
rm -r ${GREENLAND}/MESH

