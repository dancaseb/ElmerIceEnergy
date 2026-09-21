#!/bin/bash

export CUDA_MPS_LOG_DIRECTORY=./pipe_${SLURM_JOB_ID}_${SLURM_NODEID}
export CUDA_MPS_PIPE_DIRECTORY=./pipe_${SLURM_JOB_ID}_${SLURM_NODEID}

nvidia-cuda-mps-control -d

export APPTAINERENV_CUDA_MPS_PIPE_DIRECTORY=$CUDA_MPS_PIPE_DIRECTORY
export APPTAINERENV_CUDA_MPS_LOG_DIRECTORY=$CUDA_MPS_LOG_DIRECTORY

# TALP (DLB): set TALP=1 in the environment to LD_PRELOAD libdlb_mpi.so and
# have it dump a per-run efficiency report; see analysis/talp_compare.py.
# RANKS/CPUS_PER_RANK/MESH_LEVEL come from the sourcing script (run_mps.sh).
export DLB_PREFIX="/opt/dlb"
if [ "${TALP:-0}" = "1" ]; then
    export APPTAINERENV_LD_PRELOAD="${DLB_PREFIX}/lib/libdlb_mpi.so"
    export APPTAINERENV_DLB_ARGS="--talp --talp-output-file=ElmerIce_Talp_N${SLURM_NNODES}_n${RANKS}_c${CPUS_PER_RANK}_ML${MESH_LEVEL}_MPS_${SLURM_JOB_ID}.json"
fi
