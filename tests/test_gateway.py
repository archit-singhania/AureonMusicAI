"""Optional black-box contract and SignalR checks against the running .NET gateway."""
import json, os, time
import httpx
import pytest
from websockets.sync.client import connect

URL=os.getenv('AUREON_GATEWAY_URL','')
pytestmark=pytest.mark.skipif(not URL,reason='Start gateway and set AUREON_GATEWAY_URL to run black-box transport checks.')

def test_gateway_contract_streaming_and_live_events():
    with httpx.Client(base_url=URL,timeout=30) as client:
        assert client.get('/health').status_code==200
        demo=client.post('/api/v1/demo').json()
        assert demo['job']['id'] and 'preset_id' in demo['project']
        token=demo['token']; pid=demo['project']['id']; headers={'Authorization':'Bearer '+token}
        assert client.get('/api/v1/projects/'+pid).status_code==401
        negotiate=client.post('/hub/music/negotiate?negotiateVersion=1&access_token='+token).json()
        websocket=URL.replace('http://','ws://').replace('https://','wss://')+'/hub/music?id='+negotiate['connectionToken']+'&access_token='+token
        with connect(websocket,open_timeout=10) as socket:
            socket.send('{"protocol":"json","version":1}\x1e')
            assert '{}' in socket.recv(timeout=10)
            socket.send(json.dumps({'type':1,'invocationId':'1','target':'JoinProject','arguments':[pid]})+'\x1e')
            reply=socket.recv(timeout=10); assert 'error' not in reply,reply
            state=demo['project']; state['title']='A live, authorized edit'
            saved=client.put('/api/v1/projects/'+pid,headers=headers,json={'revision':1,'state':state})
            assert saved.status_code==200,saved.text
            deadline=time.monotonic()+10; received=False
            while time.monotonic()<deadline:
                raw=socket.recv(timeout=10)
                if 'StudioEvent' in raw and 'A live, authorized edit' in raw: received=True;break
            assert received,'The durable outbox did not reach the authorized project group.'
        deadline=time.monotonic()+40
        while time.monotonic()<deadline:
            job=client.get('/api/v1/jobs/'+demo['job']['id'],headers=headers).json()
            if job['status'] in ('done','failed'):break
            time.sleep(.2)
        assert job['status']=='done',job
        media=client.get('/api/v1/assets/'+job['master_asset_id'],headers=headers).json()
        part=client.get(media['url'],headers={'Range':'bytes=0-127'})
        assert part.status_code==206 and len(part.content)==128
        assert 'bytes 0-127/' in part.headers['content-range']
