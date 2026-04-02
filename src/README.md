Usage:

Make sure that in `recipe_Elmer_ubuntu24.py` the correct architecture is imported. 

Then, for Thea

```
hpccm --recipe recipe_Elmer_ubuntu24.py  --format singularity --singularity-version=3.2 > ../definitions/Elmer_ubuntu24_thea.def
```

While for Leonardo

```
hpccm --recipe recipe_Elmer_ubuntu24.py  --format singularity --singularity-version=3.2 > ../definitions/Elmer_ubuntu24_leonardo.def
```

To be fixed:

Use command line for architecture selection

