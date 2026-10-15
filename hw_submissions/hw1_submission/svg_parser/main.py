from svgelements import *

svg = SVG.parse('Icebreaker.svg')

ems = []
for element in svg.elements():
    ems.append(element)


# This just spams all of the SVG data to the console, formatted as JSON
# Then you can copy the JSON into one of the scene files
# Currently, only filled polylines are supported
for element in reversed(ems):
    if isinstance(element, Group):
        if isinstance(element, SVG):
            print('found svg')
        print('found group')
    if isinstance(element, Path):
        mySegs = element.segments()
        # print(f'#segs: {len(mySegs)}')
        # print(f'#color: {element.fill}, {element.fill.rgba}')
        r = (element.fill.rgba >> 24)
        g = (element.fill.rgba >> 16) & 0xFF
        b = (element.fill.rgba >> 8) & 0xFF
        a = (element.fill.opacity)
        print(a)
        print('{')
        print(f'"type": "polyline",')
        print(f'"points": [')
        itr = 0
        for mySeg in mySegs:
            itr += 1
            if itr == len(mySegs):  print(f'{mySeg.point(0)}')
            else: print(f'{mySeg.point(0)},')
        print(f'],')
        print(f'"fill_rgba": [{r/255},{g/255},{b/255},{a/255}],')
        print('"closed": true')
        print('},')