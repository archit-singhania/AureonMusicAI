"""Editable local release templates and cancellable media exports using actual audio."""
import hashlib
import json
import math
import shutil
import subprocess
import tempfile
import time
import zipfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from pydantic import BaseModel, Field
import audio_engine as audio

class ReleaseSettings(BaseModel):
    artist: str = Field(default='', max_length=100)
    credits: str = Field(default='', max_length=4000)
    teaser_start: int = Field(default=0, ge=0, le=179)
    teaser_seconds: int = Field(default=15, ge=1, le=30)

def font(size):
    for candidate in ('C:/Windows/Fonts/segoeui.ttf', 'DejaVuSans.ttf'):
        try: return ImageFont.truetype(candidate, size)
        except OSError: pass
    return ImageFont.load_default(size=size)

def wrap(draw, text, face, width):
    lines=[]
    for paragraph in text.splitlines() or ['']:
        line=''
        for char in paragraph:
            if draw.textlength(line+char,font=face)>width and line:
                lines.append(line);line=char
            else: line+=char
        lines.append(line)
    return lines

def artwork(state, output):
    style=state['artwork']; image=Image.new('RGB',(1080,1080),style['background']);d=ImageDraw.Draw(image)
    color=style['accent']
    if style['template']=='halo':
        for radius in range(460,30,-6):
            rgb=tuple(int(color[i:i+2],16) for i in (1,3,5))
            d.ellipse((540-radius,460-radius,540+radius,460+radius),fill=tuple(int(v*(.2+.7*(460-radius)/460)) for v in rgb))
    elif style['template']=='wave':
        for x in range(80,1000,24):
            height=80+180*abs(math.sin(x/80));d.rounded_rectangle((x,430-height,x+12,430+height),radius=6,fill=color)
    else: d.rounded_rectangle((70,90,1010,730),radius=70,outline=color,width=5)
    y=780
    for line in wrap(d,state['title'],font(48),920)[:3]:d.text((80,y),line,font=font(48),fill='white');y+=58
    d.text((80,990),state['release_kit']['artist'],font=font(25),fill=color)
    image.save(output);return image

def run(command, check):
    with tempfile.TemporaryFile() as errors:
        child=subprocess.Popen(command,stdout=subprocess.DEVNULL,stderr=errors)
        deadline=time.monotonic()+240
        try:
            while child.poll() is None:
                check()
                if time.monotonic()>deadline:raise ValueError('Teaser encoding timed out.')
                time.sleep(.15)
            if child.returncode:raise ValueError('Teaser encoding failed. Check FFmpeg codec availability.')
        finally:
            if child.poll() is None:child.kill();child.wait()

def build(state, master, directory, check=lambda:None):
    settings=ReleaseSettings.model_validate(state['release_kit'])
    if not settings.artist.strip() or not settings.credits.strip():raise ValueError('Confirm artist and credits before exporting a release kit.')
    binary=audio.ffmpeg()
    if not binary:raise ValueError('Release videos require FFmpeg.')
    measured=audio.metrics(master)
    if settings.teaser_start+settings.teaser_seconds > measured['duration']+.001:raise ValueError('Teaser range extends beyond the chosen master.')
    directory=Path(directory);directory.mkdir(parents=True,exist_ok=True)
    check();cover=artwork(state,directory/'artwork.png')
    cards=[]
    d=ImageDraw.Draw(cover);lines=wrap(d,state.get('lyrics','') or 'Instrumental · no lyrics',font(36),900)
    for index in range(0,len(lines),15):
        check();card=Image.new('RGB',(1080,1080),state['artwork']['background']);draw=ImageDraw.Draw(card)
        draw.text((80,65),settings.artist,font=font(26),fill=state['artwork']['accent'])
        for row,line in enumerate(lines[index:index+15]):draw.text((80,140+row*52),line,font=font(36),fill='white')
        name=f'lyrics-{index//15+1}.png';card.save(directory/name);cards.append(name)
    files=['artwork.png',*cards]
    for name,size in [('square',(1080,1080)),('portrait',(1080,1920))]:
        check();canvas=Image.new('RGB',size,state['artwork']['background']);canvas.paste(cover,(0,(size[1]-1080)//2));image_path=directory/f'{name}-preview.png';canvas.save(image_path)
        output=directory/f'{name}-teaser.mp4'
        run([binary,'-hide_banner','-loglevel','error','-y','-loop','1','-framerate','24','-i',str(image_path),'-ss',str(settings.teaser_start),'-t',str(settings.teaser_seconds),'-i',str(master),'-map','0:v','-map','1:a','-t',str(settings.teaser_seconds),'-c:v','libx264','-preset','ultrafast','-crf','25','-c:a','aac','-pix_fmt','yuv420p','-movflags','+faststart',str(output)],check)
        files += [image_path.name,output.name]
    shutil.copyfile(master,directory/'master.wav');files.append('master.wav')
    (directory/'credits.txt').write_text(f"{state['title']}\nArtist: {settings.artist}\n\n{settings.credits}\n\nCredits and usage rights were confirmed by the exporting user; this is not a legal verification.\n",encoding='utf-8');files.append('credits.txt')
    manifest={'version':1,'title':state['title'],'artist':settings.artist,'teaser_start':settings.teaser_start,'teaser_seconds':settings.teaser_seconds,'files':[{'name':name,'bytes':(directory/name).stat().st_size,'sha256':hashlib.sha256((directory/name).read_bytes()).hexdigest()} for name in files]}
    (directory/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8');files.append('manifest.json')
    check();archive=directory/'release-kit.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as zip:
        for name in files:check();zip.write(directory/name,name)
    return str(archive),files
