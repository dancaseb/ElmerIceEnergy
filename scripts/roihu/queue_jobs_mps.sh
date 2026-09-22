#!/bin/bash -l

ML=3
gpus=4
total_cpus=288  # whole node's cores; rank count and cpus/rank are decided inside run_mps.sh

# for N in 4 8 16 32 64 288; do
for N in 4 8 16 32 ; do
    cpus=$((total_cpus / N))
    # cpus=1
    sbatch --job-name="run_Elmer_roihu_N1_n${N}_c${cpus}_ML${ML}_MPS" \
           --nodes=1 \
           --time="00:60:00" \
           --output="logs/%x_%j.out" \
           --error="logs/%x_%j.err" \
           --mem=0 \
           --gres=gpu:gh200:${gpus} \
           --ntasks-per-node=1 \
           --cpus-per-task=$((cpus * N)) \
           --partition=gpumedium \
           --account=project_2001659 \
           run_mps.sh ${ML} ${N} ${total_cpus}
done

#            --exclusive \