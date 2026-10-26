# CSE167
Nick Mitroff & Owen Atis

## Homework 2.8
We converted one of the characters from Nick's game from an FBX model to a JSON format like the one used in `avocado.json`.

- The website https://fileconverterx.com/convert/fbx-to-json was used for the initial JSON conversion.
- OpenAI Codex was used to compare the converted JSON with `avocado.json` and apply  formatting changes to match the format used by our scene parser.
- The scene file `dolphin_scene.json` is the same as the avocado scene file, just with the mesh and texture files swapped out.

To run the scene for yourself, copy the contents of the `Assets` folder, then open the `balboa_slang_public` repository and paste them into `scenes/hw2`. Then launch the new scene: 
```
uv run python main.py 2_7 scenes/hw2/dolphin_scene.json
```
