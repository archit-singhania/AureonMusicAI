"""Bounded MIDI note editing, standard file interchange and four local instruments."""
from bisect import bisect_right
from collections import Counter, defaultdict, deque
from io import BytesIO
from typing import Literal

import mido
import numpy as np
import soundfile as sf
from pydantic import BaseModel, Field, model_validator

RATE = 44100
MAX_TICK = 8_000_000


class Note(BaseModel):
    start: int = Field(ge=0, le=MAX_TICK)
    length: int = Field(ge=1, le=MAX_TICK)
    pitch: int = Field(ge=0, le=127)
    velocity: int = Field(ge=1, le=127)
    channel: int = Field(default=0, ge=0, le=15)


class Tempo(BaseModel):
    tick: int = Field(ge=0, le=MAX_TICK)
    microseconds: int = Field(ge=1, le=0xffffff)


class Pedal(BaseModel):
    tick: int = Field(ge=0, le=MAX_TICK)
    value: int = Field(ge=0, le=127)
    channel: int = Field(default=0, ge=0, le=15)


class Score(BaseModel):
    version: Literal[1] = 1
    ppq: int = Field(default=480, ge=1, le=32767)
    preset: Literal['keys','bass','pad','pluck'] = 'keys'
    notes: list[Note] = Field(default_factory=list, max_length=2048)
    tempos: list[Tempo] = Field(default_factory=list, max_length=256)
    sustain: list[Pedal] = Field(default_factory=list, max_length=4096)
    loop_start: int = Field(default=0,ge=0,le=MAX_TICK)
    loop_end: int = Field(default=0,ge=0,le=MAX_TICK)
    loop_repeats: int = Field(default=1,ge=1,le=8)

    @model_validator(mode='after')
    def check_bounds(self):
        if any(n.start+n.length>MAX_TICK for n in self.notes):
            raise ValueError('Note end exceeds the supported timeline.')
        if (self.loop_end or self.loop_repeats>1 or self.loop_start) and self.loop_end<=self.loop_start:
            raise ValueError('Loop end must follow loop start.')
        return self


def import_midi(raw):
    if len(raw)>262144: raise ValueError('MIDI file exceeds 256 KiB.')
    midi=mido.MidiFile(file=BytesIO(raw))
    if midi.type not in (0,1) or midi.ticks_per_beat<=0: raise ValueError('Use a synchronous type 0/1 MIDI file with ticks per quarter note.')
    tick=0; pending=defaultdict(deque); notes=[]; tempos=[]; pedals=[]; skipped=Counter()
    for message in mido.merge_tracks(midi.tracks):
        tick+=message.time
        if tick>MAX_TICK: raise ValueError('MIDI timeline exceeds the supported length.')
        if message.type=='note_on' and message.velocity:
            pending[message.channel,message.note].append((tick,message.velocity))
        elif message.type in ('note_off','note_on'):
            queue=pending[message.channel,message.note]
            if not queue: skipped['unmatched_note_off']+=1;continue
            start,velocity=queue.popleft()
            if tick==start: skipped['zero_length_note']+=1;continue
            notes.append(Note(start=start,length=tick-start,pitch=message.note,velocity=velocity,channel=message.channel))
        elif message.type=='set_tempo': tempos.append(Tempo(tick=tick,microseconds=message.tempo))
        elif message.type=='control_change' and message.control==64: pedals.append(Pedal(tick=tick,value=message.value,channel=message.channel))
        elif message.type!='end_of_track': skipped[message.type]+=1
    unfinished=sum(len(q) for q in pending.values())
    if unfinished: skipped['unterminated_note']+=unfinished
    # Standard MIDI defaults to 120 bpm until a tempo event occurs.
    if not tempos or tempos[0].tick>0: tempos.insert(0,Tempo(tick=0,microseconds=500000))
    return Score(ppq=midi.ticks_per_beat,notes=notes,tempos=tempos,sustain=pedals),dict(skipped)


def tempo_map(score,bpm):
    result={0:round(60_000_000/bpm)}
    result.update((tempo.tick,tempo.microseconds) for tempo in score.tempos)
    return sorted(result.items())


def export_midi(score,bpm):
    midi=mido.MidiFile(type=0,ticks_per_beat=score.ppq);track=mido.MidiTrack();midi.tracks.append(track)
    events=[(tick,0,mido.MetaMessage('set_tempo',tempo=tempo)) for tick,tempo in tempo_map(score,bpm)]
    for pedal in score.sustain:
        events.append((pedal.tick,1,mido.Message('control_change',channel=pedal.channel,control=64,value=pedal.value)))
    for note in score.notes:
        events.append((note.start,3,mido.Message('note_on',channel=note.channel,note=note.pitch,velocity=note.velocity)))
        events.append((note.start+note.length,2,mido.Message('note_off',channel=note.channel,note=note.pitch,velocity=0)))
    previous=0
    for tick,_,message in sorted(events,key=lambda e:(e[0],e[1])):
        track.append(message.copy(time=tick-previous));previous=tick
    blob=BytesIO();midi.save(file=blob);return blob.getvalue()


def render(score,bpm,output,check=lambda:None):
    if not score.notes: raise ValueError('Add notes before rendering.')
    tempos=tempo_map(score,bpm);ticks=[tick for tick,_ in tempos];seconds=[0.0]
    for i in range(1,len(tempos)):
        seconds.append(seconds[-1]+(ticks[i]-ticks[i-1])*tempos[i-1][1]/(score.ppq*1e6))
    def frame(tick):
        i=bisect_right(ticks,tick)-1
        return round(RATE*(seconds[i]+(tick-ticks[i])*tempos[i][1]/(score.ppq*1e6)))
    last=max([n.start+n.length for n in score.notes]+[p.tick for p in score.sustain]+[score.loop_end]);end=frame(last)
    lo,hi=frame(score.loop_start),frame(score.loop_end)
    if end+(hi-lo)*(score.loop_repeats-1)>180*RATE: raise ValueError('Rendered MIDI must fit within 180 seconds.')
    mix=np.zeros(max(1,end),dtype=np.float32);work=0
    timbres={'keys':([1,.32,.10],.008,1.7),'bass':([1,.25,.09],.004,.9),'pad':([1,.37,.21,.12],.12,5.),'pluck':([1,.62,.26,.1],.002,.18)}
    harmonics,attack,decay=timbres[score.preset]
    pedals=defaultdict(list)
    for pedal in sorted(score.sustain,key=lambda p:p.tick):pedals[pedal.channel].append(pedal)
    for note in score.notes:
        check();stop=note.start+note.length;down=False
        for pedal in pedals[note.channel]:
            if pedal.tick<=stop:down=pedal.value>=64
            elif down and pedal.value<64:stop=pedal.tick;break
        else:
            if down:stop=last
        start=frame(note.start);length=frame(stop)-start;work+=length
        if work>RATE*180*12: raise ValueError('Reduce overlapping MIDI notes before rendering.')
        freq=440*2**((note.pitch-69)/12)
        for offset in range(0,length,65536):
            check();pos=np.arange(offset,min(length,offset+65536));t=pos/RATE
            wave=sum(level*np.sin(2*np.pi*freq*i*t) for i,level in enumerate(harmonics,1) if i*freq<RATE/2)
            env=np.minimum(1,t/attack)*np.exp(-t/decay)*np.minimum(1,(length-1-pos)/(RATE*.018))
            mix[start+offset:start+offset+len(t)] += wave*env*(note.velocity/127)*.35
    if score.loop_repeats>1:mix=np.concatenate([mix[:lo],np.tile(mix[lo:hi],score.loop_repeats),mix[hi:]])
    peak=np.max(np.abs(mix));mix/=max(1,peak/.98)
    sf.write(output,mix,RATE,subtype='PCM_24')
