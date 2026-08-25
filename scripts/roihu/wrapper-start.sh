#!/bin/bash

export CUDA_MPS_LOG_DIRECTORY=./pipe_${SLURM_JOB_ID}_${SLURM_NODEID}
export CUDA_MPS_PIPE_DIRECTORY=./pipe_${SLURM_JOB_ID}_${SLURM_NODEID}

if [ "$SLURM_LOCALID" -eq 0 ]; then
    nvidia-cuda-mps-control -d
fi

export APPTAINERENV_CUDA_MPS_PIPE_DIRECTORY=$CUDA_MPS_PIPE_DIRECTORY
export APPTAINERENV_CUDA_MPS_LOG_DIRECTORY=$CUDA_MPS_LOG_DIRECTORY

apptainer run --nv --bind="$(csc-common-bind),${GREENLAND}" --env UCX_POSIX_USE_PROC_LINK=n ${CONTAINER} ElmerSolver_mpi $1