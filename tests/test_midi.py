import io
import os
import mido
import numpy as np
import pytest
import soundfile as sf
from test_studio import account, client, wait
from midi_studio import import_midi, export_midi, render, Score


def fixture():
    midi=mido.MidiFile(type=1,ticks_per_beat=480);track=mido.MidiTrack();midi.tracks.append(track)
    track.extend([mido.MetaMessage('set_tempo',tempo=500000),mido.Message('program_change',program=20),
                  mido.Message('note_on',note=69,velocity=90),mido.Message('control_change',control=64,value=127,time=120),
                  mido.Message('note_off',note=69,time=120),mido.MetaMessage('set_tempo',tempo=1000000,time=240),
                  mido.Message('control_change',control=64,value=0,time=480)])
    blob=io.BytesIO();midi.save(file=blob);return blob.getvalue()


def test_midi_roundtrip_and_instruments(tmp_path):
    score,skipped=import_midi(fixture());assert skipped=={'program_change':1}
    reopened,_=import_midi(export_midi(score,88));assert reopened==score
    assert (score.notes[0].start,score.notes[0].length,score.notes[0].pitch,score.notes[0].velocity)==(0,240,69,90)
    outputs=[]
    for preset in ('keys','bass','pad','pluck'):
        score.preset=preset;path=tmp_path/(preset+'.wav');render(score,88,path)
        samples,rate=sf.read(path);assert rate==44100 and len(samples)==66150
        part=samples[7000:17000];peak=np.argmax(abs(np.fft.rfft(part*np.hanning(len(part)))))*rate/len(part)
        assert abs(peak-440)<5 and np.max(abs(samples[20000:25000]))>.001
        outputs.append(samples)
    assert all(not np.allclose(outputs[i],outputs[j]) for i in range(4) for j in range(i))


def test_midi_project_import_render_export_reopen(client):
    exercise_midi_project(client)


def test_midi_through_gateway():
    import httpx
    gateway=os.getenv('AUREON_GATEWAY_URL')
    if not gateway:pytest.skip('Start the isolated .NET gateway to check MIDI transport.')
    with httpx.Client(base_url=gateway,timeout=30) as client:exercise_midi_project(client)


def exercise_midi_project(client):
    headers,initial=account(client);other,_=account(client);p=initial['project'];root='/api/v1/projects/'+p['id']
    upload={'file':('example.mid',fixture(),'audio/midi')}
    assert client.post(root+'/midi/import',files=upload,headers=other).status_code==404
    imported=client.post(root+'/midi/import',files=upload,headers=headers);assert imported.is_success,imported.text
    assert client.post(root+'/midi/import',files={'file':('bad.mid',b'bad')},headers=headers).status_code==422
    assert client.get(root,headers=headers).json().get('midi',{}).get('notes',[])==[]
    score=imported.json()['midi'];score.update(loop_start=0,loop_end=480,loop_repeats=2)
    updated=client.put(root,headers=headers,json={'revision':p['revision'],'state':{**p,'midi':score}});assert updated.is_success,updated.text
    assert client.get(root,headers=headers).json()['midi']==score
    older_state={**updated.json(),'title':'Legacy-client edit'};older_state.pop('midi')
    legacy=client.put(root,headers=headers,json={'revision':updated.json()['revision'],'state':older_state})
    assert legacy.is_success and legacy.json()['midi']==score
    reopened,_=import_midi(client.get(root+'/midi/export',headers=headers).content);assert reopened.notes==Score.model_validate(score).notes
    queued=client.post(root+'/jobs',headers=headers,json={'kind':'midi_render'});assert queued.status_code==202,queued.text
    job=wait(client,headers,queued.json()['id']);assert job['status']=='done',job
    asset=client.get('/api/v1/assets/'+job['master_asset_id'],headers=headers).json()
    samples,rate=sf.read(io.BytesIO(client.get(asset['url']).content));assert rate==44100 and len(samples)==88200
