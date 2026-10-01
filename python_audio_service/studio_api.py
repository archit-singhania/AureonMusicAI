"""Authenticated studio API. Durable jobs and versioned edits, no simulated inference."""
import asyncio, hashlib, hmac, importlib.util, json, os, re, secrets, time, zipfile
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Literal
from fastapi import Depends, FastAPI, File, Header, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import delete, select
import audio_engine as audio
from settings import ASSETS, DATA, INTERNAL_KEY, MAX_UPLOAD, ORIGINS, REDIS_URL
from store import AuthSession, Document, Event, User, create, emit, identifier, issue_token, lookup_token, password_hash, password_matches, public, replace, session

DEFAULT_PARAMS={'vocals_gain':.8,'drums_gain':.85,'bass_gain':.8,'other_gain':.8,'saturation':.1,'delay_mix':.1,'delay_ms':180.0,'stereo_width':.5,'de_esser':.2,'target_lufs':-14.0}
secret_path=DATA/'media-signing.key'
if not secret_path.exists(): secret_path.write_bytes(secrets.token_bytes(32))
MEDIA_SECRET=secret_path.read_bytes()

class Account(BaseModel):
    email:str=Field(min_length=5,max_length=254)
    password:str=Field(min_length=10,max_length=128)
    name:str=Field(default='Creator',min_length=1,max_length=80)
    @field_validator('email')
    @classmethod
    def valid_email(cls,value):
        if not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+',value): raise ValueError('Enter a valid email address.')
        return value.lower().strip()

class ProjectState(BaseModel):
    title:str=Field(default='Untitled session',min_length=1,max_length=100)
    genre:Literal['rnb','trap','pop','rap','drill']='rnb'
    lyrics:str=Field(default='',max_length=8000)
    preset_id:str='afterglow'
    beat_asset_id:str|None=None
    vocal_asset_id:str|None=None
    cover_asset_id:str|None=None
    bpm:float=Field(default=88,ge=40,le=220)
    key:str=Field(default='A minor',max_length=30)
    language:str=Field(default='en-IN',max_length=12)
    engine:Literal['instrumental','recording','sarvam','xtts']='instrumental'
    params:dict[str,float|bool]=Field(default_factory=lambda:dict(DEFAULT_PARAMS))
    @field_validator('params')
    @classmethod
    def valid_params(cls,values):
        bounds={**{f'{n}_gain':(0,2) for n in audio.STEM_NAMES},'saturation':(0,1),'delay_mix':(0,.8),'delay_ms':(20,1000),'stereo_width':(0,1),'de_esser':(0,1),'target_lufs':(-24,-9)}
        for k,v in values.items():
            if k.endswith(('_mute','_solo')) and k.split('_')[0] in audio.STEM_NAMES:
                if not isinstance(v,bool): raise ValueError('Mute and solo must be booleans.')
            elif k not in bounds or not bounds[k][0]<=v<=bounds[k][1]: raise ValueError(f'Invalid DSP parameter {k}.')
        return values

class ProjectSave(BaseModel):
    revision:int=Field(ge=1)
    state:ProjectState
    action:str=Field(default='Saved session',max_length=120)
class JobStart(BaseModel):
    kind:Literal['generate','remix','video','mp3']='generate'
class Prompt(BaseModel):
    prompt:str=Field(min_length=1,max_length=2000)
    context:str=Field(default='',max_length=8000)
class Publish(BaseModel):
    title:str=Field(min_length=1,max_length=100)
    description:str=Field(default='',max_length=1000)
class Comment(BaseModel):
    text:str=Field(min_length=1,max_length=500)
class Invite(BaseModel):
    code:str=Field(min_length=8,max_length=80)

def user(authorization:str=Header(default='')):
    result=lookup_token(authorization.removeprefix('Bearer ').strip()) if authorization else None
    if not result: raise HTTPException(401,'Sign in to continue.')
    return result

def owned(db,doc_id,owner,kind=None):
    doc=db.get(Document,doc_id) if doc_id else None
    if not doc or (kind and doc.kind!=kind): raise HTTPException(404,'Item not found.')
    if doc.owner!=owner:
        project_id=doc.id if doc.kind=='project' else doc.parent
        project=db.get(Document,project_id) if project_id else None
        member=project and (project.owner==owner or db.scalar(select(Document).where(Document.kind=='member',Document.parent==project_id,Document.owner==owner)))
        if not member: raise HTTPException(404,'Item not found.')
    return doc

def signed_asset(doc):
    expires=int(time.time())+3600
    signature=hmac.new(MEDIA_SECRET,f'{doc.id}:{expires}'.encode(),hashlib.sha256).hexdigest()
    data=public(doc); data.pop('path',None)
    data['url']=f'/api/v1/assets/{doc.id}/content?expires={expires}&signature={signature}'
    return data

def asset(db,owner,project_id,path,name,mime,measured=True):
    info=audio.metrics(path) if measured and mime.startswith('audio') else {}
    from media_store import persist
    persist(path)
    return create(db,'asset',owner,{'name':name,'path':str(Path(path).resolve()),'media_type':mime,'metrics':info},project_id)

def safe_path(doc):
    path=Path(doc.data['path']).resolve()
    if not path.is_relative_to(ASSETS): raise HTTPException(404,'Media is unavailable.')
    from media_store import recover
    recover(path)
    if not path.exists(): raise HTTPException(404,'Media is unavailable.')
    return path

def progress(job_id,status=None,value=None,**changes):
    with session() as db:
        job=db.get(Document,job_id)
        if job.data.get('cancel_requested'):
            replace(db,job,{**job.data,'status':'cancelled','finished_at':time.time()}); emit(db,job,'job.cancelled')
            raise InterruptedError()
        data={**job.data,**changes,'heartbeat':time.time()}
        if status is not None: data['status']=status
        if value is not None: data['progress']=value
        replace(db,job,data); emit(db,job,'job.progress')

def voice(state,output):
    if not state['lyrics'].strip(): raise ValueError('Add lyrics before synthesizing a vocal.')
    if state['engine']=='sarvam':
        if not os.getenv('SARVAM_API_KEY'): raise ValueError('Sarvam requires a provider key. Choose instrumental or your own recording.')
        from services.vocal_gen.sarvam_service import synthesize_sarvam_vocal
        if not synthesize_sarvam_vocal(state['lyrics'],str(output),genre=state['genre'],language_code=state['language']): raise ValueError('Sarvam synthesis failed; no substitute vocal was generated.')
    else:
        if not importlib.util.find_spec('TTS'): raise ValueError('XTTS is not installed in this worker.')
        from TTS.api import TTS
        model=TTS(os.getenv('XTTS_MODEL','tts_models/multilingual/multi-dataset/xtts_v2'))
        model.tts_to_file(text=state['lyrics'],speaker='Ana Florence',language=state['language'].split('-')[0],file_path=str(output))

def process(job_id):
    with session() as db:
        job=db.get(Document,job_id)
        state,kind,owner,pid,source_id=job.data['state'],job.data['job_kind'],job.owner,job.parent,job.data.get('source_job_id')
    directory=ASSETS/job_id; directory.mkdir(exist_ok=True)
    try:
        if kind=='generate':
            progress(job_id,'analyzing',10)
            if state.get('beat_asset_id'):
                with session() as db: beat_path=str(safe_path(owned(db,state['beat_asset_id'],owner,'asset')))
                detected=audio.analysis(beat_path); progress(job_id,'separating',25)
                stems,separation=audio.separate(beat_path,directory)
            else:
                beat_path,stems,preset=audio.synthesize_preset(state['preset_id'],directory,bpm=state['bpm'],key=state['key'])
                detected={'bpm':preset['bpm'],'key':preset['key'],'key_confidence':1,'analysis_method':'preset composition metadata'}
                separation='original synthesized instrument stems'
            progress(job_id,'vocals',50,analysis=detected,separation=separation)
            if state['engine']=='recording':
                with session() as db: y,sr=audio.read_audio(safe_path(owned(db,state.get('vocal_asset_id'),owner,'asset')))
                stems['vocals']=audio.write_audio(directory/'vocals.wav',y,sr)
            elif state['engine'] in ('sarvam','xtts'):
                voice(state,directory/'vocals.wav'); stems['vocals']=str(directory/'vocals.wav')
            progress(job_id,'mixing',75)
            output=audio.render_mix(stems,state['params'],directory/'master.wav')
            with session() as db:
                stem_ids={name:asset(db,owner,pid,path,name.title(),'audio/wav',False).id for name,path in stems.items()}
                master_id=asset(db,owner,pid,output,state['title'],'audio/wav').id
            progress(job_id,'done',100,master_asset_id=master_id,stem_asset_ids=stem_ids,finished_at=time.time())
        else:
            with session() as db:
                source=db.get(Document,source_id)
                if not source or source.data.get('status')!='done': raise ValueError('Generate a complete master first.')
                source_path=safe_path(db.get(Document,source.data['master_asset_id']))
                stem_ids=source.data.get('stem_asset_ids',{})
                stems={n:str(safe_path(db.get(Document,aid))) for n,aid in stem_ids.items()}
            progress(job_id,'rendering',20)
            if kind=='remix': output,mime=audio.render_mix(stems,state['params'],directory/'remix.wav'),'audio/wav'
            elif kind=='video': output,mime=audio.video(source_path,directory/'visualizer.mp4'),'video/mp4'
            else: output,mime=audio.export_mp3(source_path,directory/'master.mp3'),'audio/mpeg'
            progress(job_id,'rendering',90)
            with session() as db: result_id=asset(db,owner,pid,output,state['title'],mime,kind=='remix').id
            progress(job_id,'done',100,master_asset_id=result_id,stem_asset_ids=stem_ids,finished_at=time.time())
    except InterruptedError: pass
    except Exception as error:
        with session() as db:
            job=db.get(Document,job_id); replace(db,job,{**job.data,'status':'failed','error':str(error)[:600],'finished_at':time.time()}); emit(db,job,'job.failed')

async def worker():
    while True:
        job_id=None
        with session() as db:
            for job in db.scalars(select(Document).where(Document.kind=='job').order_by(Document.created)):
                stale=job.data.get('status') in ('analyzing','separating','vocals','mixing','rendering') and time.time()-job.data.get('heartbeat',job.updated)>600
                if job.data.get('status')=='queued' or stale:
                    try: replace(db,job,{**job.data,'status':'analyzing','heartbeat':time.time(),'error':None}); job_id=job.id
                    except ValueError: continue
                    break
        if job_id: await asyncio.to_thread(process,job_id)
        elif REDIS_URL:
            def wait_for_work():
                try:
                    import redis
                    redis.Redis.from_url(REDIS_URL,socket_timeout=2,socket_connect_timeout=1).blpop('aureon:work',timeout=1)
                except Exception:
                    time.sleep(.4)
            await asyncio.to_thread(wait_for_work)
        else: await asyncio.sleep(.4)

@asynccontextmanager
async def lifespan(app):
    task=asyncio.create_task(worker()); yield; task.cancel()
    try: await task
    except asyncio.CancelledError: pass

app=FastAPI(title='Aureon Studio',version='1.0.0',lifespan=lifespan)
app.add_middleware(CORSMiddleware,allow_origins=ORIGINS,allow_methods=['GET','POST','PUT','DELETE','OPTIONS'],allow_headers=['Authorization','Content-Type','Idempotency-Key'],allow_credentials=False)
@app.exception_handler(ValueError)
async def value_error(request,error):
    return JSONResponse(status_code=409 if 'another device' in str(error) else 400,content={'detail':str(error)})

@app.get('/health')
@app.get('/api/v1/health')
def health(): return {'status':'ok','database':'postgresql' if os.getenv('DATABASE_URL','').startswith('postgres') else 'sqlite','ffmpeg':bool(audio.ffmpeg())}
@app.get('/api/v1/capabilities')
def capabilities():
    return {'instrumental':True,'recording':True,'sarvam':bool(os.getenv('SARVAM_API_KEY')),'xtts':bool(importlib.util.find_spec('TTS')),'lyric_ai':bool(os.getenv('OLLAMA_URL')),'mp3':bool(audio.ffmpeg()),'video':bool(audio.ffmpeg()),'separation':'spectral-dsp','experimental':{k:'unavailable' for k in ('musicgen','rvc','vocoder','midi','ableton')},'providers_note':'Configured providers can fail or incur costs. Speech synthesis is not a singing model.'}
@app.post('/api/v1/auth/register',status_code=201)
def register(body:Account):
    with session() as db:
        if db.scalar(select(User).where(User.email==body.email)): raise HTTPException(409,'Email is already registered.')
        u=User(id=identifier(),email=body.email,name=body.name.strip(),password=password_hash(body.password)); db.add(u); db.flush()
        return {'token':issue_token(db,u.id),'user':{'id':u.id,'name':u.name,'email':u.email}}
@app.post('/api/v1/auth/login')
def login(body:Account):
    with session() as db:
        u=db.scalar(select(User).where(User.email==body.email))
        if not u or not password_matches(body.password,u.password): raise HTTPException(401,'Email or password is incorrect.')
        return {'token':issue_token(db,u.id),'user':{'id':u.id,'name':u.name,'email':u.email}}
@app.get('/api/v1/auth/me')
def me(current=Depends(user)): return {'id':current.id,'name':current.name,'email':current.email}
@app.post('/api/v1/auth/logout')
def logout(authorization:str=Header(default=''),current=Depends(user)):
    with session() as db: db.execute(delete(AuthSession).where(AuthSession.token_hash==hashlib.sha256(authorization.removeprefix('Bearer ').encode()).hexdigest()))
    return {'status':'signed_out'}
@app.post('/api/v1/demo',status_code=201)
def demo():
    with session() as db:
        u=User(id=identifier(),email=f'{identifier()}@demo.aureon.local',name='Guest creator',password=password_hash(secrets.token_urlsafe(30))); db.add(u); db.flush()
        p=create(db,'project',u.id,{**ProjectState(title='Afterglow Sessions',lyrics='A little light in the midnight air\nA rhythm only we can share').model_dump(),'invite_code':secrets.token_urlsafe(12)})
        j=create(db,'job',u.id,{'job_kind':'generate','status':'queued','progress':0,'state':ProjectState.model_validate(p.data).model_dump()},p.id)
        return {'token':issue_token(db,u.id),'user':{'id':u.id,'name':u.name,'email':u.email},'project':public(p),'job':public(j)}
@app.get('/api/v1/presets')
def presets(): return audio.PRESETS
@app.get('/api/v1/presets/{preset_id}/preview')
def preview(preset_id):
    if preset_id not in [p['id'] for p in audio.PRESETS]: raise HTTPException(404,'Preset not found.')
    directory=ASSETS/'previews'/preset_id; path=directory/'beat.wav'
    if not path.exists(): directory.mkdir(parents=True,exist_ok=True); audio.synthesize_preset(preset_id,directory,4)
    return FileResponse(path,media_type='audio/wav')
@app.get('/api/v1/projects')
def projects(current=Depends(user)):
    with session() as db:
        docs=list(db.scalars(select(Document).where(Document.kind=='project',Document.owner==current.id).order_by(Document.updated.desc())))
        docs += [db.get(Document,m.parent) for m in db.scalars(select(Document).where(Document.kind=='member',Document.owner==current.id))]
        return [public(d) for d in docs if d and not d.data.get('archived')]
@app.post('/api/v1/projects',status_code=201)
def create_project(body:ProjectState,current=Depends(user)):
    with session() as db:
        p=create(db,'project',current.id,{**body.model_dump(),'invite_code':secrets.token_urlsafe(12)}); emit(db,p,'project.created'); return public(p)
@app.get('/api/v1/projects/{pid}')
def project(pid,current=Depends(user)):
    with session() as db: return public(owned(db,pid,current.id,'project'))
@app.put('/api/v1/projects/{pid}')
def save(pid,body:ProjectSave,current=Depends(user)):
    with session() as db:
        p=owned(db,pid,current.id,'project')
        for aid in (body.state.beat_asset_id,body.state.vocal_asset_id,body.state.cover_asset_id):
            if aid: owned(db,aid,current.id,'asset')
        create(db,'version',p.owner,{'action':body.action,'state':ProjectState.model_validate(p.data).model_dump(),'author':current.name},pid)
        replace(db,p,{**body.state.model_dump(),'invite_code':p.data['invite_code']},body.revision); emit(db,p,'project.saved'); return public(p)
@app.delete('/api/v1/projects/{pid}')
def archive(pid,current=Depends(user)):
    with session() as db:
        p=owned(db,pid,current.id,'project')
        if p.owner!=current.id: raise HTTPException(403,'Only the owner can archive.')
        replace(db,p,{**p.data,'archived':True})
    return {'status':'archived'}
@app.get('/api/v1/projects/{pid}/versions')
def versions(pid,current=Depends(user)):
    with session() as db:
        owned(db,pid,current.id,'project'); return [public(d) for d in db.scalars(select(Document).where(Document.kind=='version',Document.parent==pid).order_by(Document.created.desc()).limit(100))]
@app.post('/api/v1/projects/{pid}/restore/{vid}')
def restore(pid,vid,current=Depends(user)):
    with session() as db:
        p,v=owned(db,pid,current.id,'project'),owned(db,vid,current.id,'version')
        if v.parent!=pid: raise HTTPException(404,'Version not found.')
        create(db,'version',p.owner,{'action':'Before restore','state':ProjectState.model_validate(p.data).model_dump(),'author':current.name},pid)
        replace(db,p,{**v.data['state'],'invite_code':p.data['invite_code']}); emit(db,p,'project.restored'); return public(p)
@app.post('/api/v1/assets',status_code=201)
async def upload(file:UploadFile=File(...),project_id:str='',consent:bool=False,current=Depends(user)):
    suffix=Path(file.filename or '').suffix.lower()
    if suffix not in ('.wav','.mp3','.m4a','.ogg','.flac','.webm','.png','.jpg','.jpeg'): raise HTTPException(415,'Upload supported audio, PNG or JPEG.')
    with session() as db:
        if project_id: owned(db,project_id,current.id,'project')
    directory=ASSETS/identifier(); directory.mkdir(); path=directory/('source'+suffix); size=0
    try:
        with path.open('wb') as f:
            while data:=await file.read(1024*1024):
                size+=len(data)
                if size>MAX_UPLOAD: raise HTTPException(413,'Maximum upload size is 50 MB.')
                f.write(data)
        image=suffix in ('.png','.jpg','.jpeg')
        if image:
            from PIL import Image
            with Image.open(path) as cover: cover.verify()
            mime='image/png' if suffix=='.png' else 'image/jpeg'
        else:
            y,sr=await asyncio.to_thread(audio.read_audio,path); path=Path(audio.write_audio(directory/'source.wav',y,sr)); mime='audio/wav'
        with session() as db:
            a=asset(db,current.id,project_id,path,file.filename or 'Recording',mime); a.data={**a.data,'consented':consent,'size':size}; return signed_asset(a)
    except Exception:
        import shutil
        shutil.rmtree(directory,ignore_errors=True); raise
@app.get('/api/v1/assets')
def assets(current=Depends(user)):
    with session() as db: return [signed_asset(a) for a in db.scalars(select(Document).where(Document.kind=='asset',Document.owner==current.id).order_by(Document.created.desc()).limit(100))]
@app.get('/api/v1/assets/{aid}')
def get_asset(aid,current=Depends(user)):
    with session() as db: return signed_asset(owned(db,aid,current.id,'asset'))
@app.get('/api/v1/assets/{aid}/content')
def content(aid,expires:int=0,signature:str='',authorization:str=Header(default='')):
    expected=hmac.new(MEDIA_SECRET,f'{aid}:{expires}'.encode(),hashlib.sha256).hexdigest()
    signed=expires>=time.time() and expires<=time.time()+3601 and hmac.compare_digest(signature,expected)
    with session() as db:
        doc=db.get(Document,aid) if signed else owned(db,aid,user(authorization).id,'asset')
        if not doc or doc.kind!='asset': raise HTTPException(404,'Media not found.')
        return FileResponse(safe_path(doc),media_type=doc.data['media_type'],filename=Path(doc.data['path']).name)
@app.post('/api/v1/assets/{aid}/analyze')
async def analyze(aid,current=Depends(user)):
    with session() as db: path=safe_path(owned(db,aid,current.id,'asset'))
    result=await asyncio.to_thread(audio.analysis,path)
    with session() as db:
        a=db.get(Document,aid); replace(db,a,{**a.data,'analysis':result})
    return result
@app.post('/api/v1/projects/{pid}/jobs',status_code=202)
def start(pid,body:JobStart,idempotency_key:str=Header(default=''),current=Depends(user)):
    with session() as db:
        p=owned(db,pid,current.id,'project'); jobs=list(db.scalars(select(Document).where(Document.kind=='job',Document.parent==pid).order_by(Document.created.desc())))
        existing=next((j for j in jobs if idempotency_key and j.data.get('idempotency_key')==idempotency_key),None)
        if existing: return public(existing)
        if sum(j.data.get('status') not in ('done','failed','cancelled') for j in jobs)>=3: raise HTTPException(429,'Wait for an active render.')
        source=next((j for j in jobs if j.data.get('status')=='done' and j.data.get('job_kind') in ('generate','remix')),None)
        if body.kind!='generate' and not source: raise HTTPException(409,'Generate a master first.')
        state=ProjectState.model_validate(p.data).model_dump()
        if state['engine']=='recording':
            recording=owned(db,state.get('vocal_asset_id'),current.id,'asset')
            if not recording.data.get('consented'): raise HTTPException(400,'Confirm permission to use this voice.')
        j=create(db,'job',p.owner,{'job_kind':body.kind,'status':'queued','progress':0,'state':state,'source_job_id':source.id if source else None,'idempotency_key':idempotency_key},pid); emit(db,j,'job.queued'); return public(j)
@app.get('/api/v1/jobs')
def jobs(project_id:str='',current=Depends(user)):
    with session() as db:
        q=select(Document).where(Document.kind=='job')
        if project_id: owned(db,project_id,current.id,'project'); q=q.where(Document.parent==project_id)
        else: q=q.where(Document.owner==current.id)
        return [public(d) for d in db.scalars(q.order_by(Document.created.desc()).limit(100))]
@app.get('/api/v1/jobs/{jid}')
def job(jid,current=Depends(user)):
    with session() as db: return public(owned(db,jid,current.id,'job'))
@app.post('/api/v1/jobs/{jid}/cancel')
def cancel(jid,current=Depends(user)):
    with session() as db:
        j=owned(db,jid,current.id,'job')
        if j.data['status'] not in ('done','failed','cancelled'):
            replace(db,j,{**j.data,'cancel_requested':True,'status':'cancelled' if j.data['status']=='queued' else j.data['status']}); emit(db,j,'job.cancel_requested')
        return public(j)
@app.post('/api/v1/jobs/{jid}/retry',status_code=202)
def retry(jid,current=Depends(user)):
    with session() as db:
        j=owned(db,jid,current.id,'job')
        if j.data['status'] not in ('failed','cancelled'): raise HTTPException(409,'Only failed or cancelled jobs can be retried.')
        clone=create(db,'job',j.owner,{**j.data,'status':'queued','progress':0,'cancel_requested':False,'error':None,'retried_from':j.id,'idempotency_key':''},j.parent); emit(db,clone,'job.queued'); return public(clone)
@app.get('/api/v1/jobs/{jid}/stems.zip')
def stems_zip(jid,current=Depends(user)):
    with session() as db:
        j=owned(db,jid,current.id,'job')
        if j.data['status']!='done' or not j.data.get('stem_asset_ids'): raise HTTPException(409,'Stems are not ready.')
        directory=ASSETS/jid; directory.mkdir(exist_ok=True); path=directory/'Aureon-stems.zip'
        with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED) as archive:
            for name,aid in j.data['stem_asset_ids'].items(): archive.write(safe_path(db.get(Document,aid)),name+'.wav')
            archive.writestr('session.json',json.dumps({'title':j.data['state']['title'],'bpm':j.data['state']['bpm'],'key':j.data['state']['key'],'params':j.data['state']['params']},indent=2))
        return FileResponse(path,media_type='application/zip',filename='Aureon-stems.zip')
@app.post('/api/v1/lyrics')
async def lyrics(body:Prompt,current=Depends(user)):
    endpoint=os.getenv('OLLAMA_URL','').rstrip('/')
    if not endpoint: raise HTTPException(503,'Lyric AI is not configured. Your editor and syllable guide remain available.')
    import httpx
    try:
        async with httpx.AsyncClient(timeout=90) as client:
            r=await client.post(endpoint+'/api/generate',json={'model':os.getenv('OLLAMA_MODEL','qwen2.5:3b'),'prompt':f'Write original song lyrics. Context: {body.context}\nInstruction: {body.prompt}','stream':False}); r.raise_for_status()
            text=r.json().get('response','').strip()
            if not text: raise ValueError('Lyric provider returned an empty response.')
            return {'lyrics':text,'source':'ollama'}
    except httpx.HTTPError: raise HTTPException(503,'Lyric provider is unavailable. Your draft was preserved.')
@app.post('/api/v1/assets/{aid}/transcribe')
async def transcribe(aid,current=Depends(user)):
    if not os.getenv('SARVAM_API_KEY'): raise HTTPException(503,'Transcription requires a configured Sarvam key.')
    with session() as db: path=safe_path(owned(db,aid,current.id,'asset'))
    from services.vocal_gen.sarvam_service import transcribe_voice_prompt
    result=await asyncio.to_thread(transcribe_voice_prompt,str(path))
    if not result.get('transcript') or result.get('source')!='sarvam_saaras': raise HTTPException(503,'Transcription failed. Recording is preserved.')
    return result
@app.post('/api/v1/copilot')
def copilot(body:Prompt,current=Depends(user)):
    text,values,reasons=body.prompt.lower(),{},[]
    rules=[(['warm','tape','vintage'],'saturation',.5,'Add gentle harmonic saturation'),(['wide','stereo'],'stereo_width',.85,'Widen the side channel'),(['delay','echo','dreamy'],'delay_mix',.3,'Add stereo delay'),(['dry'],'delay_mix',0,'Remove delay'),(['sibilance','harsh','smooth'],'de_esser',.7,'Reduce sibilance'),(['bass','808'],'bass_gain',1.1,'Raise the bass stem'),(['vocal','voice'],'vocals_gain',1,'Bring the voice forward')]
    for words,key,value,reason in rules:
        if any(word in text for word in words): values[key]=value; reasons.append(reason)
    return {'params':values,'explanation':reasons or ['Try warmth, stereo width, delay, vocals or bass.'],'source':'deterministic DSP assistant','requires_confirmation':True}
@app.post('/api/v1/projects/{pid}/artwork')
def artwork(pid,current=Depends(user)):
    from PIL import Image,ImageDraw
    with session() as db: title=owned(db,pid,current.id,'project').data['title']
    directory=ASSETS/identifier(); directory.mkdir(); path=directory/'artwork.png'
    image=Image.new('RGB',(1024,1024),'#191C2B'); draw=ImageDraw.Draw(image)
    for i in range(120):
        r=500-i*3; draw.ellipse((512-r,470-r,512+r,470+r),fill=(int(70+i*.6),int(60+i*.45),int(125+i*.5)))
    draw.line([(270,650),(512,200),(754,650)],fill='#F6E9E0',width=26)
    for x,height in [(435,90),(475,150),(515,210),(555,150),(595,90)]: draw.rounded_rectangle((x,550-height,x+12,550),radius=6,fill='#F6E9E0')
    draw.text((64,880),title[:48],fill='white',font_size=40); image.save(path)
    with session() as db: return signed_asset(asset(db,current.id,pid,path,title,'image/png',False))
@app.post('/api/v1/projects/{pid}/join')
def join(pid,body:Invite,current=Depends(user)):
    with session() as db:
        p=db.get(Document,pid)
        if not p or p.kind!='project' or not hmac.compare_digest(p.data.get('invite_code',''),body.code): raise HTTPException(404,'This invitation is invalid.')
        if p.owner!=current.id and not db.scalar(select(Document).where(Document.kind=='member',Document.parent==pid,Document.owner==current.id)): create(db,'member',current.id,{'name':current.name,'role':'editor'},pid)
        return public(p)
@app.get('/api/v1/projects/{pid}/members')
def members(pid,current=Depends(user)):
    with session() as db:
        p=owned(db,pid,current.id,'project'); owner=db.get(User,p.owner)
        return [{'id':owner.id,'name':owner.name,'role':'owner'}]+[{'id':m.owner,**m.data} for m in db.scalars(select(Document).where(Document.kind=='member',Document.parent==pid))]
@app.delete('/api/v1/projects/{pid}/members/{uid}')
def remove_member(pid,uid,current=Depends(user)):
    with session() as db:
        if owned(db,pid,current.id,'project').owner!=current.id: raise HTTPException(403,'Only the owner can remove collaborators.')
        db.execute(delete(Document).where(Document.kind=='member',Document.parent==pid,Document.owner==uid))
    return {'status':'removed'}
@app.post('/api/v1/projects/{pid}/publish',status_code=201)
def publish(pid,body:Publish,current=Depends(user)):
    with session() as db:
        p=owned(db,pid,current.id,'project')
        if p.owner!=current.id: raise HTTPException(403,'Only the owner can publish.')
        jobs=list(db.scalars(select(Document).where(Document.kind=='job',Document.parent==pid).order_by(Document.created.desc())))
        master=next((j for j in jobs if j.data.get('status')=='done' and j.data.get('job_kind') in ('generate','remix')),None)
        if not master: raise HTTPException(409,'Generate a complete master before publishing.')
        return public(create(db,'publication',current.id,{**body.model_dump(),'artist':current.name,'genre':p.data['genre'],'master_asset_id':master.data['master_asset_id'],'cover_asset_id':p.data.get('cover_asset_id')},pid))
@app.get('/api/v1/showcase')
def showcase():
    with session() as db:
        result=[]
        for p in db.scalars(select(Document).where(Document.kind=='publication').order_by(Document.created.desc()).limit(60)):
            master=db.get(Document,p.data['master_asset_id']); cover=db.get(Document,p.data.get('cover_asset_id')) if p.data.get('cover_asset_id') else None
            likes=list(db.scalars(select(Document).where(Document.kind=='like',Document.parent==p.id)))
            result.append({**public(p),'master':signed_asset(master),'cover':signed_asset(cover) if cover else None,'likes':len(likes)})
        return result
@app.post('/api/v1/showcase/{pid}/like')
def like(pid,current=Depends(user)):
    with session() as db:
        p=db.get(Document,pid)
        if not p or p.kind!='publication': raise HTTPException(404,'Track not found.')
        existing=db.scalar(select(Document).where(Document.kind=='like',Document.parent==pid,Document.owner==current.id))
        if existing: db.delete(existing)
        else: create(db,'like',current.id,{},pid)
        return {'liked':not bool(existing)}
@app.get('/api/v1/showcase/{pid}/comments')
def comments(pid):
    with session() as db: return [public(c) for c in db.scalars(select(Document).where(Document.kind=='comment',Document.parent==pid).order_by(Document.created).limit(100))]
@app.post('/api/v1/showcase/{pid}/comments',status_code=201)
def comment(pid,body:Comment,current=Depends(user)):
    with session() as db:
        p=db.get(Document,pid)
        if not p or p.kind!='publication': raise HTTPException(404,'Track not found.')
        return public(create(db,'comment',current.id,{'text':body.text,'author':current.name},pid))
@app.delete('/api/v1/showcase/{pid}')
def unpublish(pid,current=Depends(user)):
    with session() as db:
        p=owned(db,pid,current.id,'publication')
        if p.owner!=current.id: raise HTTPException(403,'Only the owner can unpublish.')
        db.delete(p)
    return {'status':'unpublished'}
@app.get('/api/v1/events')
def events(after:int=0,project_id:str='',current=Depends(user)):
    with session() as db:
        q=select(Event).where(Event.id>after)
        if project_id: owned(db,project_id,current.id,'project'); q=q.where(Event.project_id==project_id)
        else: q=q.where(Event.owner==current.id)
        return [{'event_id':e.id,'project_id':e.project_id,**e.payload} for e in db.scalars(q.order_by(Event.id).limit(100))]
@app.get('/internal/events')
def internal_events(after:int=0,x_aureon_internal_key:str=Header(default='')):
    if not INTERNAL_KEY or not hmac.compare_digest(INTERNAL_KEY,x_aureon_internal_key): raise HTTPException(403,'Internal gateway key is required.')
    with session() as db: return [{'event_id':e.id,'project_id':e.project_id,'owner':e.owner,**e.payload} for e in db.scalars(select(Event).where(Event.id>after).order_by(Event.id).limit(100))]
