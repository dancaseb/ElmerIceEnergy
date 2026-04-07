#!/bin/bash -l
#SBATCH --ntasks-per-node=32
#SBATCH --cpus-per-task=1
#SBATCH --nodes=1
#SBATCH --partition=boost_usr_prod
#SBATCH --time=0:30:00
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --job-name=run_Elmer_leonardo_N1_n32_c1_ML3_MPS
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --gres=gpu:4
#SBATCH --qos=boost_qos_dbg

module load openmpi/4.1.6--gcc--12.2.0
export PRESERVE_TIMESERIES=1
export CINEMON="/leonardo_work/cin_emon/git/cinemon-public/build/cinemon"

export BASEDIR="/leonardo_work/cin_emon/uc/Marco/ElmerIceEnergy"
export RUNDIR="${BASEDIR}/runs/Leonardo/run_Elmer_leonardo_N${SLURM_NNODES}_n${SLURM_NTASKS_PER_NODE}_c${SLURM_CPUS_PER_TASK}_ML3_MPS_${SLURM_JOB_ID}"
export SCRIPTSDIR="${BASEDIR}/scripts"
export CONTAINERSDIR="${BASEDIR}/containers"
export INPUTSDIR="${BASEDIR}/inputs"

export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}
export PMIX_MCA_gds=hash
export PMIX_MCA_psec=native
export OMPI_MCA_btl=^openib 

export ELMERGRID="singularity exec -B ${RUNDIR}/Greenland_SSA --nv ${CONTAINERSDIR}/Elmer_ubuntu24_leonardo.sif ElmerGrid"
export ELMERSOLVER="singularity exec -B ${RUNDIR}/Greenland_SSA --env UCX_POSIX_USE_PROC_LINK=n --nv ${CONTAINERSDIR}/Elmer_ubuntu24_leonardo.sif ElmerSolver_mpi"
export ELMERF90="singularity exec -B ${RUNDIR}/Greenland_SSA --nv ${CONTAINERSDIR}/Elmer_ubuntu24_leonardo.sif elmerf90"

mkdir -p ${RUNDIR}

tar -xvzf "${INPUTSDIR}/Greenland_SSA.tar.gz" -C ${RUNDIR}

cd ${RUNDIR}/Greenland_SSA

srun -N1 -n1 ${ELMERGRID} 2 2 MESH -partdual -metiskway ${SLURM_NTASKS}

srun -N1 -n1 ${ELMERF90} Scalar_OUTPUT.F90 -o Scalar_OUTPUT

export CUDA_MPS_LOG_DIRECTORY=./pipe_${SLURM_JOB_ID}_${SLURM_NODEID}
export CUDA_MPS_PIPE_DIRECTORY=./pipe_${SLURM_JOB_ID}_${SLURM_NODEID}
mkdir -p $CUDA_MPS_PIPE_DIRECTORY
echo "SLURM_LOCALID=$SLURM_LOCALID"
if [ $SLURM_LOCALID -eq 0 ]; then
    echo "DEBUG!"	
    nvidia-cuda-mps-control -d
fi
sleep 1
start=$(date +%s)
srun -n ${SLURM_NTASKS} --cpu-bind=cores --cpus-per-task=${SLURM_CPUS_PER_TASK} ${CINEMON} ${ELMERSOLVER} SSA_amgx_ML3.sif
end=$(date +%s)
if [[ $SLURM_LOCALID -eq 0 ]]; then
    echo quit | nvidia-cuda-mps-control
fi

#start=$(date +%s)
#srun -n $SLURM_NTASKS --cpus-per-task=$SLURM_CPUS_PER_TASK --cpu-bind=cores ${SCRIPTSDIR}/Leonardo/wrapper-start_ML3.sh
#srun -n $SLURM_NTASKS --cpus-per-task=$SLURM_CPUS_PER_TASK --cpu-bind=cores ${SCRIPTSDIR}/Leonardo/wrapper-stop.sh
#end=$(date +%s)

echo "Elapsed time: $(($end-$start)) s"
echo "-----------------------------------"
rm -r ${RUNDIR}/Greenland_SSA/MESH

