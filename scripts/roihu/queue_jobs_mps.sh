#!/bin/bash -l

ML=4
gpus=4

for N in 4 8 16 32 64 288; do
    cpus=$((gpus * 72 / N))
    # cpus=1
    sbatch --job-name="run_Elmer_roihu_N1_n${N}_c${cpus}_ML${ML}" \
           --nodes=1 \
           --exclusive \
           --time="00:45:00" \
           --output="logs/%x_%j.out" \
           --error="logs/%x_%j.err" \
           --mem=0 \
           --gres=gpu:gh200:${gpus} \
           --cpus-per-task=${cpus} \
           --ntasks-per-node=${N} \
           --partition=gpumedium \
           --account=project_2001659 \
           run_mps.sh ${ML}
done