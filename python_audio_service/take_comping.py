"""Owned take banks and non-destructive phrase selections, rendered by the timeline DSP."""
from pydantic import BaseModel, Field, model_validator
from arrangement import Arrangement, Clip

class TakeGroup(BaseModel):
    id: str = Field(min_length=1, max_length=80)
    name: str = Field(min_length=1, max_length=100)
    asset_ids: list[str] = Field(default_factory=list, max_length=24)
    phrases: list[Clip] = Field(default_factory=list, max_length=100)

    @model_validator(mode='after')
    def valid(self):
        if len(set(self.asset_ids)) != len(self.asset_ids):
            raise ValueError('A take may appear once in a take bank.')
        if any(p.asset_id not in self.asset_ids or p.repeats != 1 for p in self.phrases):
            raise ValueError('Select phrases from the take bank, with one repeat.')
        self.arrangement()
        return self

    def arrangement(self):
        return Arrangement.model_validate({'tracks':[{'id':self.id,'name':self.name,'clips':[p.model_dump() for p in self.phrases]}]}).model_dump()
