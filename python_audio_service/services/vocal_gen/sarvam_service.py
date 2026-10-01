"""Optional Sarvam speech adapter. Missing credentials never fabricate a response.
Contracts: Bulbul v3 and Saaras v3 (official REST documentation, October 2026).
Speech synthesis produces speech; it is not a singing or voice-cloning model.
"""
import base64
import io
import os
from pathlib import Path
import numpy as np
import requests
import soundfile as sf
from scipy.signal import resample_poly

BASE_URL = 'https://api.sarvam.ai'
SUPPORTED_LANGUAGES = {'en-IN':'English','hi-IN':'Hindi','bn-IN':'Bengali','kn-IN':'Kannada','ml-IN':'Malayalam','mr-IN':'Marathi','od-IN':'Odia','pa-IN':'Punjabi','ta-IN':'Tamil','te-IN':'Telugu','gu-IN':'Gujarati'}

def is_sarvam_available():
    return bool(os.getenv('SARVAM_API_KEY', '').strip())

def _headers():
    key = os.getenv('SARVAM_API_KEY', '').strip()
    if not key:
        raise ValueError('Sarvam is not configured. Add a provider key or use your own recording.')
    return {'api-subscription-key': key}

def synthesize_sarvam_vocal(text, output_path, genre='rap', language_code='en-IN', speaker=None):
    if not text.strip():
        raise ValueError('Enter text to synthesize.')
    if language_code not in SUPPORTED_LANGUAGES:
        raise ValueError('This speech language is not supported.')
    chunks=[]
    for start in range(0, len(text), 2400):
        response=requests.post(BASE_URL+'/text-to-speech', headers=_headers(), json={
            'text':text[start:start+2400], 'language_code':language_code,
            'model':'bulbul:v3', 'speaker':speaker or 'shubh',
            'pace':0.9 if genre=='rnb' else 1.0, 'speech_sample_rate':44100,
        },timeout=60)
        response.raise_for_status()
        audios=response.json().get('audios',[])
        if not audios:
            raise ValueError('The speech provider returned no audio.')
        for encoded in audios:
            samples,rate=sf.read(io.BytesIO(base64.b64decode(encoded,validate=True)),always_2d=True,dtype='float32')
            if rate!=44100:
                from math import gcd
                factor=gcd(rate,44100)
                samples=resample_poly(samples,44100//factor,rate//factor,axis=0)
            if not len(samples) or not np.isfinite(samples).all():
                raise ValueError('The speech provider returned invalid audio.')
            chunks.append(samples.mean(axis=1))
            chunks.append(np.zeros(8820,dtype=np.float32))
    sf.write(output_path,np.concatenate(chunks),44100,subtype='PCM_24')
    return output_path

def transcribe_voice_prompt(audio_file_path,language_code='unknown'):
    headers=_headers()
    samples,rate=sf.read(audio_file_path,always_2d=True,dtype='float32')
    if rate!=16000:
        from math import gcd
        factor=gcd(rate,16000)
        samples=resample_poly(samples,16000//factor,rate//factor,axis=0)
    mono=samples.mean(axis=1)
    transcripts=[]
    detected=language_code
    # The interactive REST API accepts audio under 30 seconds. Use independent
    # real 25-second chunks for the studio's bounded recordings.
    for start in range(0,len(mono),25*16000):
        buffer=io.BytesIO()
        sf.write(buffer,mono[start:start+25*16000],16000,format='WAV',subtype='PCM_16')
        response=requests.post(BASE_URL+'/speech-to-text',headers=headers,
            files={'file':('voice.wav',buffer.getvalue(),'audio/wav')},
            data={'model':'saaras:v3','language_code':language_code,'mode':'transcribe'},timeout=60)
        response.raise_for_status()
        result=response.json()
        transcripts.append(result.get('transcript','').strip())
        detected=result.get('language_code') or detected
    transcript=' '.join(part for part in transcripts if part)
    if not transcript:
        raise ValueError('No speech was recognized. The recording is preserved.')
    return {'transcript':transcript,'language':detected,'source':'sarvam_saaras'}
