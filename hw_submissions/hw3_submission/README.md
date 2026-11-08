# CSE167
Nick Mitroff & Owen Atis

## Homework 3.7
We converted a weapon from Owen's game from an FBX model to a JSON format.

- The website https://fileconverterx.com/convert/fbx-to-json was used for the initial JSON conversion.
- OpenAI Codex was used to compare the converted JSON with the example meshes and apply  formatting changes to match the format used by our scene parser.
- The scene file `mace.json` includes custom animations with the mace.

To run the scene for yourself, copy mace_mesh.json into the meshes folder and mace.json into the scenes folder. Then run: 
```
uv run python main.py 3_6 scenes/hw3/mace.json
```
