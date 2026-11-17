import io
import os
import numpy as np
import soundfile as sf
from test_studio import client, account, wait


def test_compare_selected_renders_and_restore_without_erasing_history(client):
    exercise_mix_versions(client)


def test_mix_versions_through_public_gateway():
    import httpx
    import pytest
    gateway = os.getenv('AUREON_GATEWAY_URL')
    if not gateway:
        pytest.skip('Set AUREON_GATEWAY_URL to an isolated gateway to run this transport check.')
    with httpx.Client(base_url=gateway, timeout=30) as transport:
        exercise_mix_versions(transport)


def exercise_mix_versions(client):
    owner, initial = account(client)
    outsider, outsider_account = account(client)
    project = initial['project']
    root = '/api/v1/projects/' + project['id']
    versions = root + '/mix-versions'
    wav = io.BytesIO()
    samples = .2 * np.sin(2*np.pi*220*np.arange(88200)/44100)
    sf.write(wav,samples,44100,format='WAV')
    response = client.post('/api/v1/assets?project_id='+project['id'],headers=owner,files={'file':('tone.wav',wav.getvalue(),'audio/wav')})
    assert response.status_code == 201, response.text
    source = response.json()['id']
    saved = []
    for label,gain in [('Quiet',.25),('Louder',.8)]:
        track = {'id':'t','name':'Tone','gain':gain,'clips':[{'id':'c','asset_id':source,'start':0,'length':88200}]}
        update = client.put(root,headers=owner,json={'revision':project['revision'],'state':{**project,'arrangement':{'tracks':[track]}}})
        assert update.is_success,update.text
        project = update.json()
        queued = client.post(root+'/jobs',headers=owner,json={'kind':'arrangement_render'}).json()
        job = wait(client,owner,queued['id'])
        assert job['status']=='done',job
        version = client.post(versions,headers=owner,json={'job_id':job['id'],'name':label})
        assert version.status_code==201,version.text
        saved.append(version.json())
    pair = {'left':saved[0]['id'],'right':saved[1]['id'],'match_audio':True}
    assert client.post(versions+'/compare',headers=outsider,json=pair).status_code==404
    result = client.post(versions+'/compare',headers=owner,json=pair)
    assert result.is_success,result.text
    comparison = result.json()
    assert [a['id'] for a in comparison['audio']]==[v['master_asset_id'] for v in saved]
    assert {'field':'arrangement.tracks[t].gain','before':.25,'after':.8} in comparison['changes']
    originals = [client.get(asset['url']).content for asset in comparison['audio']]
    def rms(blob):
        samples, rate = sf.read(io.BytesIO(blob))
        assert rate==44100 and len(samples)==88200
        return np.sqrt(np.mean(samples**2))
    assert rms(originals[1]) > 3*rms(originals[0])
    job = wait(client,owner,comparison['job_id'])
    assert job['status']=='done',job
    assert len(set(job['audition_asset_ids']))==2
    matched = [client.get(client.get('/api/v1/assets/'+aid,headers=owner).json()['url']).content for aid in job['audition_asset_ids']]
    assert abs(20*np.log10(rms(matched[0])/rms(matched[1]))) < .2
    assert [client.get(asset['url']).content for asset in comparison['audio']] == originals
    restore = versions+'/'+saved[0]['id']+'/restore'
    assert client.post(restore,headers=owner,json={'revision':1}).status_code==409
    latest = client.get(root,headers=owner).json()
    restored = client.post(restore,headers=owner,json={'revision':latest['revision']})
    assert restored.is_success,restored.text
    assert restored.json()['arrangement']['tracks'][0]['gain']==.25
    assert restored.json()['revision']>latest['revision']
    assert len(client.get(versions,headers=owner).json())==2
    reviewer = client.get('/api/v1/auth/me',headers=outsider).json()
    grant = client.post(root+'/mix-reviews',headers=owner,json={'reviewer_email':reviewer['email'],'version_id':saved[0]['id']})
    assert grant.status_code == 201,grant.text
    review = grant.json(); route='/api/v1/mix-reviews/'+review['id']
    assert client.get(root,headers=outsider).status_code==404
    assert client.get('/api/v1/assets/'+saved[0]['master_asset_id'],headers=outsider).status_code==404
    url=client.get(route+'/audition',headers=outsider).json()['url']
    assert client.get(url).content==originals[0]
    def act(actor,action,**params):
        return client.post(route+'/feedback',headers=actor,json={'revision':review['revision'],'action':action,**params})
    assert act(outsider,'comment',start_ms=3000,text='Outside').status_code==422
    review=act(outsider,'comment',start_ms=200,end_ms=400,text='Raise this phrase').json()
    cid=review['comments'][0]['id']
    review=act(owner,'reply',comment_id=cid,text='Heard it').json()
    review=act(owner,'resolve',comment_id=cid).json()
    assert review['comments'][0]['resolved']
    assert act(owner,'approve').status_code==403
    review=act(outsider,'approve').json()
    assert review['decision']=='approved' and review['version_id']==saved[0]['id']
    assert act(owner,'revoke').is_success
    assert client.get(url).status_code==404
    assert client.get('/api/v1/mix-reviews',headers=outsider).json()==[]
