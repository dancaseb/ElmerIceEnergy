Set up the directory structure with absolute path in `config_thea.sh` for Thea (`config_thea.sh` for Leonardo)

Job scripts have the following sctructure:

```
submit_Elmer_${ARCH}_N${NUMBER_OF_NODES}_n${TASKS_PER_NODE}_c${CORES_PER_TASK}_ML${MESH_LEVEL_SPLITTING}.sh
```

where 

- `ARCH` = "thea" or "leonardo"
- `NUMBER_OF_NODES` = 4 for these simulations
- `TASKS_PER_NODE` = 1 or 4
- `CORES_PER_TASK` = on thea 72/`TASKS_PER_NODE`; on leonardo 32/`TASKS_PER_NODE`
- `MESH_LEVEL_SPLITTING` = 4 (smaller problem) or 5 (larger problem)

For example, on Thea

```
sbatch submit_Elmer_thea_N4_n1_c72_ML4.sh 
```

has a runtime of about 1h 30m and produces a total of 86G 

```
sbatch submit_Elmer_thea_N4_n4_c18_ML4.sh
```

has a runtime of about 40m and produces a total of 123G

```
sbatch submit_Elmer_thea_N4_n4_c18_ML5.sh
```

has a runtime of about 2h 5m and produces a total of 487G

The scripts

- `preprocess.sh` launches
- - `nvsmi_start.sh` to perform some energy measurements using `nvidia-smi`
- `postprocess.sh`
- - `nvsmi_stop.sh` to kill the `nvsmi_start.sh` process

