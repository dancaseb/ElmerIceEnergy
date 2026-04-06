import os
import re
import pandas as pd
from io import StringIO
from pathlib import Path

base_dir = "/leonardo_work/cin_emon/uc/Marco/ElmerIceEnergy/runs/Leonardo"
output_dir="/leonardo_work/cin_emon/uc/Marco/ElmerIceEnergy/results/Leonardo"
outout_filename = "data.csv"
Path(output_dir).mkdir(parents=True, exist_ok=True)

all_data = []

# Regex to parse folder name
pattern = re.compile(
    r"run_Elmer_leonardo_"
    r"N(?P<nodes>\d+)_"
    r"n(?P<ntasks_per_node>\d+)_"
    r"c(?P<cpus_per_task>\d+)_"
    r"ML(?P<mesh_level>\d+)"
    r"(?:_(?P<mps>MPS))?"              # optional MPS
    r"_(?P<jobid>\d+)"
)

for root, dirs, files in os.walk(base_dir):
    if "ejob.txt" in files:
        file_path = os.path.join(root, "ejob.txt")

        # ---- Extract metadata from path ----
        match = pattern.search(root)
        if match:
            meta = match.groupdict()

            metadata = {
                "nodes": int(meta["nodes"]),
                "ntasks_per_node": int(meta["ntasks_per_node"]),
                "cpus_per_task": int(meta["cpus_per_task"]),
                "mesh_level": int(meta["mesh_level"]),
                "MPS": meta["mps"] == "MPS",
                "jobid": int(meta["jobid"])
            }
        else:
            metadata = {}

        # ---- Read file ----
        with open(file_path, "r") as f:
            lines = f.readlines()

        csv_lines = lines[:-5]
        energy_lines = lines[-5:]

        # Fix header
        if csv_lines:
            csv_lines[0] = csv_lines[0].lstrip("#")

        # ---- CSV → DataFrame ----
        csv_content = "".join(csv_lines)

        #try:
        df = pd.read_csv(StringIO(csv_content))
        # Add metadata columns
        for k, v in metadata.items():
            df[k] = v

        df["source_folder"] = root
        TOT_ENERGY = df["TOT_ENERGY"].sum()
        EXECUTION_TIME = df["EXECUTION_TIME"].max()
        NODES = df["nodes"].max()
        NTASKS_PER_NODE = df["ntasks_per_node"].max()
        CPUS_PER_TASK = df["cpus_per_task"].max()
        MESH_LEVEL = df["mesh_level"].max()
        MPS = df["MPS"].max()
        #except Exception as e:
        #    print(f"Skipping CSV parsing in {file_path}: {e}")
        #
        # ---- Energy dictionary ----
        data_dict = {}
        data_dict["EXECUTION_TIME"]= EXECUTION_TIME
        data_dict["NODES"]= NODES
        data_dict["NTASKS_PER_NODE"]= NTASKS_PER_NODE
        data_dict["CPUS_PER_TASK"]= CPUS_PER_TASK
        data_dict["MESH_LEVEL"]= MESH_LEVEL
        data_dict["MPS"]= MPS
        data_dict["ROOT"] = root
        for line in energy_lines:
            if ":" in line:
                key, value = line.split(":", 1)
                value_num = value.split("J")[0].strip()
                data_dict[key.strip()] = float(value_num)

        all_data.append(data_dict)

df = pd.DataFrame(all_data)
df.rename(columns={'Total energy consumed by the job': 'TOTAL_ENERGY', 'EXECUTION_TIME': 'TOTAL_TIME'}, inplace=True)
# Combine all dataframes
#if all_dataframes:
#    combined_df = pd.concat(all_dataframes, ignore_index=True)
#print(combined_df.head())
df["EDP"]  = df["TOTAL_ENERGY"] * df["TOTAL_TIME"]
df["ED2P"] = df["TOTAL_ENERGY"] * (df["TOTAL_TIME"] ** 2)
df = df[["NODES", "NTASKS_PER_NODE", "CPUS_PER_TASK", "MESH_LEVEL", "MPS", "TOTAL_TIME", "TOTAL_ENERGY", "EDP", "ED2P"]]
df.to_csv(f"{output_dir}/{outout_filename}", index=False)

