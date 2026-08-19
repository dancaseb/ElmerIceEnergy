#!/bin/bash -l
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=8
#SBATCH --nodes=1
#SBATCH --partition=boost_usr_prod
#SBATCH --time=0:30:00
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --job-name=run_Elmer_leonardo_N1_n4_c8_ML3_MPS
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --gres=gpu:4
#SBATCH --qos=boost_qos_dbg

#!/bin/bash
#SBATCH --job-name=amgx_ssa
#SBATCH --account=project_2001659
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --partition=gputest
#SBATCH --nodes=1
#SBATCH --time=00:15:00
#SBATCH --ntasks-per-node=1 --cpus-per-task=1 # The product should be 72 if requesting 1 GPU per node
#SBATCH --gres=gpu:gh200:1
#SBATCH --mem=0


# module load openmpi/4.1.6--gcc--12.2.0

# CINEMON
# some energy measurment software
# export PRESERVE_TIMESERIES=1
# export CINEMON="/leonardo_work/cin_emon/git/cinemon-public/build/cinemon"

#MESH LEVEL
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

# CONTAINERPATH
export CONTAINER=${CONTAINERSDIR}/container.sif
export GREENLAND=${RUNDIR}/Greenland_SSA

# PREPROCESS
mkdir -p ${RUNDIR}
tar -xvzf "${INPUTSDIR}/Greenland_SSA.tar.gz" -C ${RUNDIR}
cd ${GREENLAND}

# rewrite these 
# ELMERGRID
srun -N1 -n1 singularity exec -B ${GREENLAND} --nv ${CONTAINER} ElmerGrid 2 2 MESH -partdual -metiskway ${SLURM_NTASKS}

# ELMERF90
srun -N1 -n1 singularity exec -B ${GREENLAND} --nv ${CONTAINER} elmerf90 Scalar_OUTPUT.F90 -o Scalar_OUTPUT

# ELMERSOLVER
start=$(date +%s)
srun -n ${SLURM_NTASKS} --cpu-bind=cores --cpus-per-task=${SLURM_CPUS_PER_TASK} ${SCRIPTSDIR}/Leonardo/wrapper-start.sh SSA_amgx_ML${MESH_LEVEL}.sif
srun -n $SLURM_NTASKS ${SCRIPTSDIR}/Leonardo/wrapper-stop.sh
end=$(date +%s)

echo "Elapsed time: $(($end-$start)) s"
echo "-----------------------------------"
rm -r ${GREENLAND}/MESH

