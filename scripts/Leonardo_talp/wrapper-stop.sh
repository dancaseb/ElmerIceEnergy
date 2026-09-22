#!/bin/bash

export CUDA_MPS_LOG_DIRECTORY=./pipe_${SLURM_JOB_ID}_${SLURM_NODEID}
export CUDA_MPS_PIPE_DIRECTORY=./pipe_${SLURM_JOB_ID}_${SLURM_NODEID}

if [[ -p "${CUDA_MPS_PIPE_DIRECTORY}/control" ]]; then
    if [ $SLURM_LOCALID -eq 0 ]; then
        echo quit | nvidia-cuda-mps-control
    else
        echo "MPS control pipe is no longer present"
    fi
fi

