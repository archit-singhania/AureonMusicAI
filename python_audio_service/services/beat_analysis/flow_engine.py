"""
flow_engine.py — Syllable Timing + AI Critic
LLM     : Ollama  (free, local, no API key, no cost)
Fallback: BPM-math rule-based timing (works with Ollama offline)

Setup:
  brew install ollama
  ollama pull mistral        # 4 GB  best quality
  ollama pull qwen2.5:3b     # 2 GB  fastest on CPU
  ollama serve               # starts local server
"""
import json
import re
import logging
import requests
from typing import List, Dict

from services.beat_analysis.analyzer import BeatGrid
from services.beat_analysis.syllable_mapper import FlowMap

logger = logging.getLogger(__name__)

OLLAMA_HOST    = "http://localhost:11434"
OLLAMA_MODEL   = "mistral"    # swap to qwen2.5:3b for speed
OLLAMA_TIMEOUT = 120

GENRE_STYLE = {
    "trap":  "slow menacing triplet flow, long pauses, heavy 8th/16th triplets",
    "drill": "aggressive rapid-fire, staccato punches, dark cadence, words on downbeats",
    "rap":   "rhythmic clear diction, emphasis on rhymes, consistent 16th-note subdivision",
    "rnb":   "smooth melodic, notes held long, melisma on vowels, laid-back timing",
    "pop":   "melodic hooky, strong vowel extension, high-energy chorus, clear pitch",
}
_DENSITY = {"trap": 0.50, "drill": 0.90, "rap": 0.85, "rnb": 0.70, "pop": 0.75}


# ── Ollama caller ─────────────────────────────────────────────────────────────

def _ollama(prompt: str) -> str:
    """Try ollama Python package first, fall back to raw HTTP."""
    try:
        import ollama as _pkg
        r = _pkg.generate(model=OLLAMA_MODEL, prompt=prompt, format="json")
        return r.get("response", "") if isinstance(r, dict) else r.response
    except ImportError:
        pass
    except Exception as e:
        logger.debug(f"ollama pkg: {e}")
    r = requests.post(
        f"{OLLAMA_HOST}/api/generate",
        json={"model": OLLAMA_MODEL, "prompt": prompt,
              "stream": False, "format": "json"},
        timeout=OLLAMA_TIMEOUT,
    )
    r.raise_for_status()
    return r.json()["response"]


def _parse(raw: str):
    raw = re.sub(r"^```(?:json)?", "", raw.strip()).strip()
    raw = re.sub(r"```$", "", raw).strip()
    return json.loads(raw)


# ── Rule-based BPM fallback (zero AI, fully offline) ─────────────────────────

def _math_timings(flow_map: FlowMap, beat_grid: BeatGrid, genre: str) -> List[Dict]:
    beat = 60.0 / beat_grid.bpm
    s16  = beat / 4
    dur  = s16 / _DENSITY.get(genre, 0.80)
    gap  = beat * 2
    cur  = beat_grid.beat_times[0] if beat_grid.beat_times else 0.0
    out  = []
    for i, line in enumerate(flow_map.lines):
        entries, t = [], cur
        for j, syl in enumerate(line.syllables):
            snap = round(t / s16) * s16
            if j in line.stressed_positions:
                hb = beat / 2
                sl = int(hb / s16)
                st = round(snap / hb) * sl * s16
                if abs(st - snap) < s16 * 2:
                    snap = st
            entries.append({"syllable": syl,
                             "start":    round(snap, 4),
                             "duration": round(dur,  4)})
            t += dur
        out.append({"line_index": i, "line_text": line.text,
                    "syllable_timings": entries})
        cur = t + gap
    return out


def _math_critique(timings: List[Dict], beat_grid: BeatGrid) -> Dict:
    s16   = (60.0 / beat_grid.bpm) / 4
    total = on_beat = 0
    for line in timings:
        for s in line.get("syllable_timings", []):
            if abs(s["start"] / s16 - round(s["start"] / s16)) <= 0.25:
                on_beat += 1
            total += 1
    ratio = on_beat / total if total else 0.80
    score = round(min(ratio + 0.10, 1.0), 3)
    return {
        "score":          score,
        "on_beat_ratio":  round(ratio, 3),
        "overflow_lines": [],
        "issues":         ["AI critic offline — math scoring used"] if score < 0.75 else [],
        "approved":       score >= 0.60,
    }


# ── Prompts ───────────────────────────────────────────────────────────────────

def _timing_prompt(flow_map: FlowMap, beat_grid: BeatGrid,
                   genre: str, bars: int) -> str:
    lines = [
        {"line_index": i, "text": l.text,
         "syllable_count": l.syllable_count, "syllables": l.syllables,
         "rhyme": flow_map.rhyme_scheme[i] if i < len(flow_map.rhyme_scheme) else "?"}
        for i, l in enumerate(flow_map.lines)
    ]
    return (
        f"You are an expert rap/vocal flow engineer.\n"
        f"BPM={beat_grid.bpm:.1f} Key={beat_grid.key} "
        f"Beats/bar={beat_grid.beats_per_bar} Bars={bars}\n"
        f"First 16 beat timestamps(s): {beat_grid.beat_times[:16]}\n"
        f"GENRE: {genre.upper()} — {GENRE_STYLE.get(genre, '')}\n"
        f"LYRICS: {json.dumps(lines)}\n\n"
        f"Assign start+duration (seconds) to every syllable:\n"
        f"1. Land on 16th-note BPM grid subdivisions\n"
        f"2. No line overflows its bar allocation\n"
        f"3. 2-beat breathing gaps between lines\n"
        f"4. Stressed syllables on beats 1 or 3\n"
        f"5. Feel matches {genre} style above\n\n"
        f"Respond ONLY with a JSON array, no markdown:\n"
        f'[{{"line_index":int,"line_text":str,'
        f'"syllable_timings":[{{"syllable":str,"start":float,"duration":float}}]}}]'
    )


def _critique_prompt(timings: List[Dict], beat_grid: BeatGrid,
                     genre: str) -> str:
    return (
        f"AI music critic for rap/vocal flow.\n"
        f"BPM={beat_grid.bpm:.1f} Genre={genre}\n"
        f"First 8 beat timestamps: {beat_grid.beat_times[:8]}\n"
        f"TIMINGS: {json.dumps(timings)}\n\n"
        f"Evaluate: on-beat ratio, overflow lines, style match, awkward phrasing.\n"
        f"Respond ONLY with JSON, no markdown:\n"
        f'{{"score":float,"on_beat_ratio":float,'
        f'"overflow_lines":[int],"issues":[str],"approved":bool}}'
    )


# ── Public API ────────────────────────────────────────────────────────────────

def generate_flow_timings(flow_map: FlowMap,
                          beat_grid: BeatGrid,
                          genre: str) -> List[Dict]:
    """Primary: Ollama (free local). Fallback: BPM-math grid."""
    bars = max(8, len(beat_grid.bar_times) - 1)
    try:
        timings = _parse(_ollama(_timing_prompt(flow_map, beat_grid, genre, bars)))
        logger.info(f"[Ollama:{OLLAMA_MODEL}] timings for {len(timings)} lines")
        return timings
    except requests.exceptions.ConnectionError:
        logger.warning(
            "Ollama not running — math fallback active.\n"
            "To enable AI flow: brew install ollama && "
            "ollama pull mistral && ollama serve"
        )
    except Exception as e:
        logger.warning(f"Ollama error ({type(e).__name__}: {e}) — math fallback")
    return _math_timings(flow_map, beat_grid, genre)


def critique_flow(timings: List[Dict],
                  beat_grid: BeatGrid,
                  genre: str) -> Dict:
    """Primary: Ollama critique. Fallback: on-beat ratio math."""
    try:
        result = _parse(_ollama(_critique_prompt(timings, beat_grid, genre)))
        logger.info(
            f"[Ollama] critique score={result.get('score')} "
            f"approved={result.get('approved')}"
        )
        return result
    except requests.exceptions.ConnectionError:
        logger.warning("Ollama not running — math critique fallback")
    except Exception as e:
        logger.warning(f"Ollama critique error ({type(e).__name__}: {e}) — math fallback")
    return _math_critique(timings, beat_grid)
