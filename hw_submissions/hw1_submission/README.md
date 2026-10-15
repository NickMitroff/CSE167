# CSE167
 Nick Mitroff & Owen Atis

## Homework 1.9
We implemented a small SVG parser, located at `hw1/svg_parser/main.py`.
We created two scenes using the parser, `freeze_ray.json` and `icebreaker.json`.
We also rendered these scenes to the output files `freeze_ray.png` and `icebreaker.png`.
To get the same output as us, uncomment line 13 of `hw1_shape_drawing.slang`, and uncomment line 28 of `hw1_8.slang`. Then run:
``` $ uv run python main.py -output outputs/freeze_ray.png 1_8 scenes/hw1/freeze_ray.json ```
for the first scene and
``` $ uv run python main.py -output outputs/freeze_ray.png 1_8 scenes/hw1/icebreaker.json ```
for the second scene
