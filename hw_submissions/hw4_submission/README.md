# CSE167
Nick Mitroff & Owen Atis

## Homework 4.7
We downloaded a basic cube model and a wooden chair model from the internet. We then experimented with dropping cloths with different numbers of vertices (4, 8, 16, 32, 64 for the cube, and 64, 128 for the chair).

- The chair model was downloaded from https://www.artec3d.com/3d-models/wooden-chair-hd, and the cube was downloaded from https://github.com/PointCloudLibrary/pcl/blob/master/test/cube.ply
- We tried creating our own cube model in Blockbench, then converting it to a .ply file, but this resulted in a cube with incorrect vertex data, causing the cloth to get "launched" when it landed on the cube. 
- We observed issues with the cloth clipping through the object at low vertex counts, since there is no collision applied in between the particles. 
- The scene file `cloth_custom.json`, which is based on the `cloth_bunny` scene, was used to make these renders.

To run the scene for yourself, copy `cube.ply`, `wooden_chair.ply`, and `cloth_custom.json` into the scenes folder. In `cloth_custom`, you can set `NUM_VERTICES` and `MESH_NAME` to tweak the output. Then run: 
```
uv run python main.py 4_6 scenes/hw4/cloth_custom.json
```
