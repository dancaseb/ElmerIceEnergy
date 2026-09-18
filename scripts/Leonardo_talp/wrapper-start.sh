#!/bin/bash

export MESH_LEVEL="$1"

export CUDA_MPS_LOG_DIRECTORY=./pipe_${SLURM_JOB_ID}_${SLURM_NODEID}
export CUDA_MPS_PIPE_DIRECTORY=./pipe_${SLURM_JOB_ID}_${SLURM_NODEID}

if [ "$SLURM_LOCALID" -eq 0 ]; then
    nvidia-cuda-mps-control -d
fi

export DLB_PREFIX="/opt/dlb"
export SINGULARITYENV_CUDA_MPS_PIPE_DIRECTORY="${CUDA_MPS_PIPE_DIRECTORY}"
export SINGULARITYENV_CUDA_MPS_LOG_DIRECTORY="${CUDA_MPS_LOG_DIRECTORY}"
export SINGULARITYENV_UCX_POSIX_USE_PROC_LINK="n"
export SINGULARITYENV_LD_PRELOAD="${DLB_PREFIX}/lib/libdlb_mpi.so"
export SINGULARITYENV_DLB_ARGS="--talp --talp-output-file=ElmerIce_Talp_N${SLURM_NNODES}_n${SLURM_NTASKS_PER_NODE}_c${SLURM_CPUS_PER_TASK}_ML${MESH_LEVEL}_MPS_${SLURM_JOB_ID}.json"


singularity exec --nv -B ${GREENLAND} ${CONTAINER} ElmerSolver_mpi "SSA_amgx_ML${MESH_LEVEL}.sif"

#singularity exec --nv "${CONTAINER}" bash -lc '
#    echo "=== DLB files ==="
#    ls -l /opt/dlb/lib/libdlb_mpi.so
#
#    echo "=== Dependencies ==="
#    ldd /opt/dlb/lib/libdlb_mpi.so
#
#    echo "=== DLB executables ==="
#    find /opt/dlb -maxdepth 2 -type f -name "dlb*" -o -name "talp*"
#'

#singularity exec \
#    --env "LD_PRELOAD=/opt/dlb/lib/libdlb_mpi.so" \
#    --env "DLB_ARGS=--talp" \
#    --nv "${CONTAINER}" \
#    bash -lc '
#        echo "LD_PRELOAD=${LD_PRELOAD}"
#        echo "DLB_ARGS=${DLB_ARGS}"
#        cat /proc/self/maps | grep -E "libdlb|dlb_mpi" || true
#    '


