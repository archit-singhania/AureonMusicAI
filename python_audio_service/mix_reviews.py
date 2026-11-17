"""Version-specific review grants, separate from project membership."""
import hashlib
import hmac
import time
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field
from sqlalchemy import select
from store import Document, User, create, identifier, public, replace, session


class Invite(BaseModel):
    reviewer_email: str = Field(min_length=3, max_length=254)
    version_id: str


class Feedback(BaseModel):
    revision: int = Field(ge=1)
    action: Literal['comment','reply','resolve','reopen','approve','request_changes','revoke']
    text: str = Field(default='', max_length=3000)
    comment_id: str | None = None
    start_ms: int = Field(default=0, ge=0)
    end_ms: int | None = Field(default=None, ge=0)


def review_routes(authenticate, media_path, secret):
    router = APIRouter(prefix='/api/v1')

    def access(db, rid, uid):
        row = db.get(Document, rid)
        if not row or row.kind != 'mix_review' or uid not in (row.owner,row.data['reviewer_id']):
            raise HTTPException(404,'Review unavailable.')
        if row.data['revoked'] and uid != row.owner:
            raise HTTPException(404,'Review unavailable.')
        return row

    def signature(rid, expiry):
        return hmac.new(secret,f'mix-review:{rid}:{expiry}'.encode(),hashlib.sha256).hexdigest()

    @router.post('/projects/{pid}/mix-reviews',status_code=201)
    def invite(pid, body: Invite, current=Depends(authenticate)):
        with session() as db:
            project=db.get(Document,pid)
            if not project or project.kind!='project' or project.owner!=current.id:
                raise HTTPException(404,'Owner project unavailable.')
            version=db.get(Document,body.version_id)
            if not version or version.kind!='mix_version' or version.parent!=pid:
                raise HTTPException(422,'Choose a named version in this project.')
            reviewer=db.scalar(select(User).where(User.email==body.reviewer_email.strip().lower()))
            if not reviewer or reviewer.id==current.id:
                raise HTTPException(422,'Select another existing Aureon account.')
            master=db.get(Document,version.data['master_asset_id'])
            duration=master.data.get('metrics',{}).get('duration') if master else None
            if not duration:
                raise HTTPException(422,'The selected master has no measured duration.')
            for row in db.scalars(select(Document).where(Document.kind=='mix_review',Document.parent==pid)):
                if row.data['version_id']==version.id and row.data['reviewer_id']==reviewer.id and not row.data['revoked']:
                    return public(row)
            row=create(db,'mix_review',project.owner,{'version_id':version.id,'version_name':version.data['name'],
                'reviewer_id':reviewer.id,'reviewer_name':reviewer.name,'duration_ms':round(duration*1000),
                'revoked':False,'decision':'pending','events':[],'comments':[]},pid)
            return public(row)

    @router.get('/mix-reviews')
    def inbox(current=Depends(authenticate)):
        with session() as db:
            rows=db.scalars(select(Document).where(Document.kind=='mix_review',
                (Document.owner==current.id)|(Document.data['reviewer_id'].as_string()==current.id)).order_by(Document.created.desc()))
            return [public(r) for r in rows if r.owner==current.id or not r.data['revoked']]

    @router.get('/mix-reviews/{rid}/audition')
    def audition(rid,current=Depends(authenticate)):
        with session() as db:
            row=access(db,rid,current.id)
            if row.data['revoked']:raise HTTPException(404,'Review revoked.')
            expiry=int(time.time())+300
            return {'url':f'/api/v1/mix-reviews/{rid}/audio?expires={expiry}&signature={signature(rid,expiry)}'}

    @router.get('/mix-reviews/{rid}/audio')
    def audio(rid,expires:int,signature:str):
        expected=hmac.new(secret,f'mix-review:{rid}:{expires}'.encode(),hashlib.sha256).hexdigest()
        if not time.time()<=expires<=time.time()+301 or not hmac.compare_digest(signature,expected):
            raise HTTPException(403,'Audition link expired or invalid.')
        with session() as db:
            row=db.get(Document,rid)
            if not row or row.kind!='mix_review' or row.data['revoked']:raise HTTPException(404,'Review revoked.')
            version=db.get(Document,row.data['version_id']);master=db.get(Document,version.data['master_asset_id'])
            return FileResponse(media_path(master),media_type=master.data['media_type'],headers={'Cache-Control':'private, no-store'})

    @router.post('/mix-reviews/{rid}/feedback')
    def feedback(rid, body: Feedback,current=Depends(authenticate)):
        with session() as db:
            row=access(db,rid,current.id);data=dict(row.data)
            if data['revoked'] or row.revision!=body.revision:raise HTTPException(409,'Reload the current review.')
            text=body.text.strip();action=body.action
            if action in ('comment','reply','request_changes') and not text:raise HTTPException(422,'Enter feedback first.')
            if action=='revoke':
                if current.id!=row.owner:raise HTTPException(403,'Only the owner can revoke review access.')
                data['revoked']=True
            elif action in ('approve','request_changes'):
                if current.id!=data['reviewer_id']:raise HTTPException(403,'Only the invited reviewer can decide.')
                data['decision']='approved' if action=='approve' else 'changes_requested'
            elif action=='comment':
                end=body.end_ms if body.end_ms is not None else body.start_ms
                if not body.start_ms<=end<=data['duration_ms']:raise HTTPException(422,'Choose a range within this render.')
                data['comments']=[*data['comments'],{'id':identifier(),'start_ms':body.start_ms,'end_ms':end,'author':current.name,'text':text,'resolved':False,'replies':[]}]
            else:
                comments=[dict(c) for c in data['comments']];comment=next((c for c in comments if c['id']==body.comment_id),None)
                if not comment:raise HTTPException(422,'Choose a comment in this review.')
                if action=='reply':comment['replies']=[*comment['replies'],{'author':current.name,'text':text,'at':time.time()}]
                else:comment['resolved']=action=='resolve'
                data['comments']=comments
            data['events']=[*data['events'],{'actor_id':current.id,'action':action,'at':time.time(),'comment_id':body.comment_id,'text':text}]
            replace(db,row,data,body.revision)
            return public(row)
    return router
