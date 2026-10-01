"""Rasterize the original repo-native A/soundwave mark for platform launchers."""
from pathlib import Path
from PIL import Image, ImageDraw
import re

ROOT=Path(__file__).resolve().parents[1]/'flutter_app'/'aureon'
image=Image.new('RGBA',(1024,1024),'#7862B7')
draw=ImageDraw.Draw(image)
draw.line([(235,750),(512,210),(790,750)],fill='#FFF9F3',width=64,joint='curve')
for x,height in [(385,85),(470,155),(555,220),(640,130)]:
    draw.rounded_rectangle((x,695-height,x+38,695),radius=19,fill='#FFF9F3')
for path in (ROOT/'android'/'app'/'src'/'main'/'res').glob('mipmap-*/ic_launcher.png'):
    size={'mipmap-mdpi':48,'mipmap-hdpi':72,'mipmap-xhdpi':96,'mipmap-xxhdpi':144,'mipmap-xxxhdpi':192}[path.parent.name]
    image.resize((size,size),Image.Resampling.LANCZOS).save(path)
for path in (ROOT/'ios'/'Runner'/'Assets.xcassets'/'AppIcon.appiconset').glob('*.png'):
    width=Image.open(path).width
    image.convert('RGB').resize((width,width),Image.Resampling.LANCZOS).save(path)
for path in (ROOT/'web'/'icons').glob('*.png'):
    size=192 if '192' in path.name else 512
    image.resize((size,size),Image.Resampling.LANCZOS).save(path)
image.resize((64,64),Image.Resampling.LANCZOS).save(ROOT/'web'/'favicon.png')
image.save(ROOT/'windows'/'runner'/'resources'/'app_icon.ico',sizes=[(16,16),(32,32),(48,48),(64,64),(256,256)])
image.save(ROOT/'assets'/'brand'/'aureon-icon.png')
