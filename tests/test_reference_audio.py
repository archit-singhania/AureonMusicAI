import io
import numpy as np
import pytest
import soundfile as sf
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'python_audio_service'))
import reference_audio as ref

def tone(scale=.1):
    t = np.arange(44100) / 44100
    return np.column_stack((scale*np.sin(2*np.pi*440*t), scale*np.sin(2*np.pi*440*t)))

def test_matched_auditions_and_explainable_metrics(tmp_path):
    a, b = tmp_path/'a.wav', tmp_path/'b.wav'
    sf.write(a, tone(), 44100, subtype='FLOAT'); sf.write(b,tone(.2),44100,subtype='FLOAT')
    comparison, outputs = ref.compare(a,b,tmp_path)
    assert comparison['suggestion']['gain_db'] == pytest.approx(6.021,abs=.01)
    assert comparison['master']['stereo_width']==0
    assert sum(comparison['master']['bands_percent'].values()) == pytest.approx(100,abs=.01)
    left,_=sf.read(outputs[0]); right,_=sf.read(outputs[1])
    assert np.allclose(left,right,atol=1e-6)
    assert abs(left).max()<.9

def test_headroom_cancellation_and_silent_input(tmp_path):
    source=tmp_path/'a.wav'; sf.write(source,tone(.8),44100,subtype='FLOAT')
    output=tmp_path/'out.wav'
    with pytest.raises(ValueError,match='headroom'): ref.render(source,output,12,1)
    assert not output.exists()
    def cancel(): raise InterruptedError()
    with pytest.raises(InterruptedError): ref.render(source,output,0,1,check=cancel)
    assert not output.exists()
    with pytest.raises(ValueError,match='Silent'): ref.measure(np.zeros((44100,2)),44100)

def test_reference_job_ownership_revision_and_real_render():
    from fastapi.testclient import TestClient
    from studio_api import app
    from test_studio import account,wait
    with TestClient(app) as client:
        headers,initial=account(client); other,_=account(client); pid=initial['project']['id']
        buf=io.BytesIO();sf.write(buf,tone(),44100,format='WAV',subtype='FLOAT')
        reference=client.post('/api/v1/assets?project_id='+pid,headers=headers,files={'file':('private.wav',buf.getvalue(),'audio/wav')}).json()
        queued=client.post(f'/api/v1/projects/{pid}/jobs',headers=headers,json={'kind':'generate'})
        master=wait(client,headers,queued.json()['id']); assert master['status']=='done'
        state={**initial['project'],'reference':{'asset_id':reference['id'],'gain_db':-3,'width':1}}
        saved=client.put(f'/api/v1/projects/{pid}',headers=headers,json={'revision':initial['project']['revision'],'state':state})
        assert saved.status_code==200,saved.text
        assert client.post('/api/v1/projects',headers=other,json=state).status_code==404
        assert client.post(f'/api/v1/projects/{pid}/jobs',headers=headers,json={'kind':'reference_analysis','source_master_asset_id':'stale'}).status_code==409
        request={'kind':'reference_analysis','source_master_asset_id':master['master_asset_id']}
        analysis=client.post(f'/api/v1/projects/{pid}/jobs',headers={**headers,'Idempotency-Key':'ref-qa'},json=request)
        assert analysis.status_code==202,analysis.text
        repeated=client.post(f'/api/v1/projects/{pid}/jobs',headers={**headers,'Idempotency-Key':'ref-qa'},json=request)
        assert repeated.json()['id']==analysis.json()['id']
        result=wait(client,headers,analysis.json()['id']);assert result['status']=='done',result
        assert result['reference_asset_id']==reference['id'] and len(result['audition_asset_ids'])==2
        assert client.get('/api/v1/jobs/'+result['id'],headers=other).status_code==404
        render=client.post(f'/api/v1/projects/{pid}/jobs',headers=headers,json={'kind':'reference_render','source_master_asset_id':master['master_asset_id']})
        rendered=wait(client,headers,render.json()['id']);assert rendered['status']=='done',rendered
        for aid in [*result['audition_asset_ids'],rendered['master_asset_id']]:
            asset=client.get('/api/v1/assets/'+aid,headers=headers).json()
            y,rate=sf.read(io.BytesIO(client.get(asset['url']).content));assert rate==44100 and y.shape[1]==2 and np.isfinite(y).all()
        assert client.get('/api/v1/assets/'+master['master_asset_id'],headers=headers).status_code==200
        assert client.get(f'/api/v1/projects/{pid}',headers=headers).json()['reference']['gain_db']==-3
        publication=client.post(f'/api/v1/projects/{pid}/publish',headers=headers,json={'title':'Illustrative adjusted master'})
        assert publication.status_code==201,publication.text
        assert publication.json()['master_asset_id']==rendered['master_asset_id']
        assert 'reference' not in publication.json()
