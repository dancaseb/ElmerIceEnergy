import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path

def plot(dframe, y_axis_str, outfilename):
    # ---- Parameters ----
    groups_lvl1 = dframe["NODES"].unique().tolist()
    groups_lvl2 = dframe["NTASKS_PER_NODE"].unique().tolist()
    mps_vals = dframe["MPS"].unique().tolist()
    mesh_levels = dframe["MESH_LEVEL"].unique().tolist()
    if len(mesh_levels)==1:
        mesh_levels = mesh_levels * len(groups_lvl1)
    bar_width = 0.15
    subgroup_width = bar_width * 2      # two bars (MPS F/T)
    group_width = subgroup_width * len(groups_lvl2)
    x_main = np.arange(len(groups_lvl1)) * (group_width + 0.5)
    fig, ax = plt.subplots(figsize=(12,6))
    # ---- Plot ----
    for i, nodes in enumerate(groups_lvl1):
        for j, ntasks_per_node in enumerate(groups_lvl2):
            for k, mps in enumerate(mps_vals):

                subset = dframe[
                    (dframe["NODES"] == nodes) &
                    (dframe["NTASKS_PER_NODE"] == ntasks_per_node) &
                    (dframe["MPS"] == mps)
                ]

                if subset.empty:
                    continue

                y = subset[y_axis_str].values[0]

                # position calculation
                x = (x_main[i] + j * subgroup_width + k * bar_width)

                ax.bar(
                    x,
                    y,
                    width=bar_width,
                    color=f"C{j}",
                    hatch='//' if mps else '',
                    label=f"MPIs={ntasks_per_node}, MPS={'On' if mps else 'Off'}"
                )

    # ---- X ticks (centered on main groups) ----
    ax.set_xticks(x_main + group_width / 2 - bar_width)
    ax.set_xticklabels([f"Nodes={g}\nMesh Level={ml}" for g,ml in zip(groups_lvl1, mesh_levels)])

    # ---- Labels ----
    if y_axis_str == "TOTAL_TIME":
        y_lab = "Time To Solution [s]"
        title_lab = "Elmer/Ice Greenland SSA: Execution Time Breakdown"

    if y_axis_str == "TOTAL_ENERGY":
        y_lab = "Energy To Solution [J]"
        title_lab = "Elmer/Ice Greenland SSA: Execution Energy Breakdown"

    if y_axis_str == "EDP":
        y_lab = "Energy-Delay Product [J * s]"
        title_lab = "Elmer/Ice Greenland SSA: Execution Energy-Delay Product Breakdown"
    
    ax.set_yscale("log")
    ax.set_ylabel(y_lab)
    ax.set_title(title_lab)

    # ---- Clean legend (avoid duplicates) ----
    handles, labels = ax.get_legend_handles_labels()
    unique = dict(zip(labels, handles))
    ax.legend(unique.values(), unique.keys(), fontsize=8, ncol=2)

    plt.tight_layout()
    plt.savefig(outfilename, dpi=150)
    plt.show()



input_data_path = "/leonardo_work/cin_emon/uc/Marco/ElmerIceEnergy/results/Leonardo/data.csv"
output_dir = "/leonardo_work/cin_emon/uc/Marco/ElmerIceEnergy/results/Leonardo/"
Path(output_dir).mkdir(parents=True, exist_ok=True)

df = pd.read_csv(input_data_path)

strong_scaling = df[df["MESH_LEVEL"]==3].sort_values(by=["NODES", "NTASKS_PER_NODE", "MPS"])
weak_scaling = df[df['MESH_LEVEL'].isin([4, 5]) | df['NODES'].isin([1])].sort_values(by=["NODES", "NTASKS_PER_NODE", "MPS"])

plot(strong_scaling, "TOTAL_TIME", output_dir + "/strong_time_breakdown.png")
plot(strong_scaling, "TOTAL_ENERGY", output_dir + "/strong_energy_breakdown.png")
plot(strong_scaling, "EDP", output_dir + "/strong_energydelayprod_breakdown.png")

plot(weak_scaling, "TOTAL_TIME", output_dir + "/weak_time_breakdown.png")
plot(weak_scaling, "TOTAL_ENERGY", output_dir + "/weak_energy_breakdown.png")
plot(weak_scaling, "EDP", output_dir + "/weak_energydelayprod_breakdown.png")

