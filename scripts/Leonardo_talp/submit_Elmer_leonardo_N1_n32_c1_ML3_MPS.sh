#!/bin/bash -l
#SBATCH --ntasks-per-node=32
#SBATCH --cpus-per-task=1
#SBATCH --nodes=1
#SBATCH --partition=boost_usr_prod
#SBATCH --time=0:30:00
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --job-name=run_Elmer_leonardo_N1_n32_c1_ML3_Talp_MPS
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --gres=gpu:4
#SBATCH --qos=boost_qos_dbg

module load openmpi/4.1.6--gcc--12.2.0
module load cuda/12.2

#MESH LEVEL
export MESH_LEVEL="3"

# DIR PATHS
export BASEDIR="/leonardo_work/cin_emon/uc/Marco/ElmerIceEnergy"
export RUNDIR="${BASEDIR}/runs/Leonardo_talp/N${SLURM_NNODES}_n${SLURM_NTASKS_PER_NODE}_c${SLURM_CPUS_PER_TASK}_ML${MESH_LEVEL}_MPS/run_Elmer_leonardo_N${SLURM_NNODES}_n${SLURM_NTASKS_PER_NODE}_c${SLURM_CPUS_PER_TASK}_ML${MESH_LEVEL}_MPS_${SLURM_JOB_ID}"
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
srun -n ${SLURM_NTASKS} --cpu-bind=cores --cpus-per-task=${SLURM_CPUS_PER_TASK} ${SCRIPTSDIR}/Leonardo_talp/wrapper-start.sh ${MESH_LEVEL}
srun -n $SLURM_NTASKS ${SCRIPTSDIR}/Leonardo_talp/wrapper-stop.sh
end=$(date +%s)

echo "Elapsed time: $(($end-$start)) s"
echo "-----------------------------------"
rm -r ${GREENLAND}/MESH

