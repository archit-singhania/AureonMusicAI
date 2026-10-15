import io
import json
import hashlib
import zipfile
from pathlib import Path
import sys
import numpy as np
import pytest
import soundfile as sf
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'python_audio_service'))
from take_comping import TakeGroup
from arrangement import render
import release_kit
import audio_engine as audio

def test_comping_crossfade_preserves_originals_and_sample_boundaries(tmp_path):
    a=tmp_path/'a.wav';b=tmp_path/'b.wav'
    sf.write(a,np.ones((44100,2))*.1,44100,subtype='FLOAT');sf.write(b,np.ones((44100,2))*.2,44100,subtype='FLOAT')
    hashes=[hashlib.sha256(p.read_bytes()).hexdigest() for p in (a,b)]
    group=TakeGroup.model_validate({'id':'g','name':'Takes','asset_ids':['a','b'],'phrases':[
      {'id':'first','asset_id':'a','start':0,'length':44100,'fade_out':4100},
      {'id':'second','asset_id':'b','start':40000,'length':44100,'fade_in':4100}]})
    output=render(group.arrangement(),{'a':a,'b':b},tmp_path/'comp.wav')
    y,sr=sf.read(output);assert sr==44100 and y.shape==(84100,2)
    assert abs(y[39999,0]-.1)<1e-6 and abs(y[44100,0]-.2)<1e-6
    assert abs(np.diff(y[39999:44101,0])).max()<.00003
    assert hashes==[hashlib.sha256(p.read_bytes()).hexdigest() for p in (a,b)]
    with pytest.raises(ValueError):TakeGroup.model_validate({'id':'g','name':'Takes','asset_ids':['a'],'phrases':[{'id':'p','asset_id':'b','start':0,'length':1}]})

def test_release_encoding_cancellation_terminates_child(tmp_path):
    import time
    marker=tmp_path/'should-not-exist'
    def cancel():raise InterruptedError()
    with pytest.raises(InterruptedError):release_kit.run([sys.executable,'-c',f"import time;from pathlib import Path;time.sleep(1);Path({str(marker)!r}).touch()"],cancel)
    time.sleep(1.1);assert not marker.exists()

def test_comp_job_release_rights_manifest_media_and_ownership(tmp_path):
    from fastapi.testclient import TestClient
    from studio_api import app
    from test_studio import account,wait
    with TestClient(app) as client:
        headers,initial=account(client);other,_=account(client);pid=initial['project']['id']
        t=np.arange(88200)/44100;y=np.column_stack((np.sin(2*np.pi*440*t),np.sin(2*np.pi*440*t)))*.1
        buffer=io.BytesIO();sf.write(buffer,y,44100,format='WAV',subtype='FLOAT')
        uploaded=client.post('/api/v1/assets?project_id='+pid,headers=headers,files={'file':('Take A.wav',buffer.getvalue(),'audio/wav')})
        assert uploaded.status_code==201;aid=uploaded.json()['id']
        uploaded_asset=client.get('/api/v1/assets/'+aid,headers=headers).json()
        original_bytes=client.get(uploaded_asset['url']).content
        group={'id':'performer','name':'Performance A','asset_ids':[aid],'phrases':[{'id':'p','asset_id':aid,'start':0,'source_start':22050,'length':66150,'fade_in':100,'fade_out':100}]}
        state={**initial['project'],'take_groups':[group],'lyrics':'A real lyric card\nWith original credits','release_kit':{'artist':'Illustrative QA','credits':'Original performance, owned recording','teaser_seconds':1,'teaser_start':0}}
        saved=client.put(f'/api/v1/projects/{pid}',headers=headers,json={'revision':initial['project']['revision'],'state':state});assert saved.status_code==200,saved.text
        assert client.post('/api/v1/projects',headers=other,json=state).status_code==404
        queued=client.post(f'/api/v1/projects/{pid}/jobs',headers=headers,json={'kind':'comp_render','take_group_id':'performer'});assert queued.status_code==202,queued.text
        comp=wait(client,headers,queued.json()['id']);assert comp['status']=='done',comp
        original=client.get('/api/v1/assets/'+aid,headers=headers).json()
        assert client.get(original['url']).content==original_bytes
        master=client.get('/api/v1/assets/'+comp['master_asset_id'],headers=headers).json()
        actual,sr=sf.read(io.BytesIO(client.get(master['url']).content));assert actual.shape==(66150,2) and sr==44100
        request={'kind':'release_kit','source_master_asset_id':comp['master_asset_id']}
        assert client.post(f'/api/v1/projects/{pid}/jobs',headers=headers,json=request).status_code==400
        kit=client.post(f'/api/v1/projects/{pid}/jobs',headers=headers,json={**request,'confirm_rights':True});assert kit.status_code==202,kit.text
        result=wait(client,headers,kit.json()['id']);assert result['status']=='done',result
        assert client.get('/api/v1/jobs/'+result['id'],headers=other).status_code==404
        bundle=client.get('/api/v1/assets/'+result['bundle_asset_id'],headers=headers).json()
        with zipfile.ZipFile(io.BytesIO(client.get(bundle['url']).content)) as zip:
            manifest=json.loads(zip.read('manifest.json'))
            assert {'square-teaser.mp4','portrait-teaser.mp4','artwork.png','credits.txt','master.wav'}.issubset(zip.namelist())
            for entry in manifest['files']:assert hashlib.sha256(zip.read(entry['name'])).hexdigest()==entry['sha256']
            from PIL import Image
            assert Image.open(io.BytesIO(zip.read('artwork.png'))).size==(1080,1080)
            for name in ('square-teaser.mp4','portrait-teaser.mp4'):
                video=tmp_path/name;video.write_bytes(zip.read(name))
                audio.command([audio.ffmpeg(),'-v','error','-i',str(video),'-map','0:v:0','-map','0:a:0','-f','null','-'],timeout=30)
            assert 'owned recording' in zip.read('credits.txt').decode('utf-8')
        reloaded=client.get(f'/api/v1/projects/{pid}',headers=headers).json();assert reloaded['take_groups'][0]['phrases'][0]['source_start']==22050
        assert client.post(f'/api/v1/projects/{pid}/undo',headers=headers,json={'revision':reloaded['revision']}).status_code==200
        assert not client.get(f'/api/v1/projects/{pid}',headers=headers).json()['take_groups']
