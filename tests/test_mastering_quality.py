import hashlib
import json
import sys
from pathlib import Path
import numpy as np
import pytest
import soundfile as sf
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'python_audio_service'))
from mastering_quality import analyze, QualitySettings


def test_mastering_real_measurements_silence_and_source_preservation(tmp_path):
    path = tmp_path / 'fixture.wav'
    tone = .2 * np.sin(2*np.pi*440*np.arange(44100)/44100)
    samples = np.column_stack((tone, -tone))
    samples = np.concatenate((samples, np.zeros((3*44100, 2))))
    sf.write(path, samples, 44100, subtype='FLOAT')
    before = hashlib.sha256(path.read_bytes()).hexdigest()
    result = analyze(path, QualitySettings())
    codes = {x['code'] for x in result['findings']}
    assert {'phase', 'mono_loss', 'silence'} <= codes
    assert result['stereo_correlation'] == pytest.approx(-1)
    assert result['clipped_frames'] == 0
    assert result['estimated_true_peak_dbtp'] == pytest.approx(-13.98, abs=.1)
    assert hashlib.sha256(path.read_bytes()).hexdigest() == before
    json.dumps(result, allow_nan=False)


def test_mastering_clipping_silent_nulls_and_cancellation(tmp_path):
    path = tmp_path / 'fixture.wav'
    sf.write(path, np.full((44100, 2), 1.1), 44100, subtype='FLOAT')
    result = analyze(path, QualitySettings())
    assert result['clipped_frames'] == 44100
    assert result['stereo_correlation'] is None
    json.dumps(result, allow_nan=False)
    sf.write(path, np.zeros((44100, 2)), 44100, subtype='FLOAT')
    result = analyze(path, QualitySettings())
    assert result['integrated_lufs'] is None and result['estimated_true_peak_dbtp'] is None
    json.dumps(result, allow_nan=False)
    def cancel(): raise InterruptedError('cancelled')
    with pytest.raises(InterruptedError): analyze(path, QualitySettings(), cancel)


def test_mastering_job_owned_export_and_stale_master():
    from fastapi.testclient import TestClient
    from studio_api import app
    from test_studio import account, wait
    with TestClient(app) as client:
        headers, initial = account(client)
        other, _ = account(client)
        pid = initial['project']['id']
        root = f'/api/v1/projects/{pid}'
        generated = client.post(root+'/jobs', headers=headers, json={'kind': 'generate'})
        master = wait(client, headers, generated.json()['id'])
        assert master['status'] == 'done', master
        assert client.post(root+'/jobs', headers=headers, json={'kind': 'mastering_analysis', 'source_master_asset_id': 'stale'}).status_code == 409
        queued = client.post(root+'/jobs', headers=headers, json={'kind': 'mastering_analysis', 'source_master_asset_id': master['master_asset_id']})
        assert queued.status_code == 202, queued.text
        result = wait(client, headers, queued.json()['id'])
        assert result['status'] == 'done', result
        assert result['source_master_asset_id'] == master['master_asset_id']
        aid = result['report_asset_id']
        assert client.get('/api/v1/assets/'+aid, headers=other).status_code == 404
        asset = client.get('/api/v1/assets/'+aid, headers=headers).json()
        assert client.get(asset['url']).json() == result['quality_report']
