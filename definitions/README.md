Usage:

Make sure that in the `.sif` files are correct. 
Then, for Thea

```
apptainer build --arch arm64 ../conatiners/Elmer_ubuntu24_thea.sif     Elmer_ubuntu24_thea.def
```

While for Leonardo

```
apptainer build --arch amd64 ../containers/Elmer_ubuntu24_leonardo.sif Elmer_ubuntu24_leonardo.def
```

