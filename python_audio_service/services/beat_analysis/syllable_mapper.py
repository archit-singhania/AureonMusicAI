import pyphen
import pronouncing
import re
from typing import List, Tuple
from dataclasses import dataclass


@dataclass
class LyricLine:
    text: str
    syllables: List[str]
    syllable_count: int
    words: List[str]
    stressed_positions: List[int]


@dataclass
class FlowMap:
    lines: List[LyricLine]
    total_syllables: int
    avg_syllables_per_line: float
    rhyme_scheme: List[str]


dic = pyphen.Pyphen(lang='en_US')


def syllabify_word(word: str) -> List[str]:
    clean = re.sub(r"[^a-zA-Z']", "", word).lower()
    if not clean:
        return [word]
    phones = pronouncing.phones_for_word(clean)
    if phones:
        count = pronouncing.syllable_count(phones[0])
        parts = dic.inserted(clean).split('-')
        if len(parts) != count:
            parts = [clean[i:i + max(1, len(clean) // count)] for i in range(0, len(clean), max(1, len(clean) // count))]
        return parts[:count] if len(parts) >= count else parts
    return dic.inserted(clean).split('-') or [clean]


def get_stress_positions(word: str) -> List[int]:
    clean = re.sub(r"[^a-zA-Z']", "", word).lower()
    phones = pronouncing.phones_for_word(clean)
    if not phones:
        return []
    stresses = pronouncing.stresses(phones[0])
    return [i for i, s in enumerate(stresses) if s == '1']


def get_rhyme_key(word: str) -> str:
    clean = re.sub(r"[^a-zA-Z']", "", word).lower()
    phones = pronouncing.phones_for_word(clean)
    if phones:
        p = phones[0].split()
        vowels = [ph for ph in p if ph[-1].isdigit()]
        if vowels:
            idx = p.index(vowels[-1])
            return ' '.join(p[idx:])
    return clean[-3:] if len(clean) >= 3 else clean


def label_rhyme_scheme(rhyme_keys: List[str]) -> List[str]:
    mapping = {}
    labels = []
    counter = ord('A')
    for key in rhyme_keys:
        matched = False
        for existing_key, label in mapping.items():
            phones_a = pronouncing.phones_for_word(existing_key.split()[-1] if ' ' in existing_key else existing_key)
            phones_b = pronouncing.phones_for_word(key.split()[-1] if ' ' in key else key)
            if phones_a and phones_b and phones_a[0][-6:] == phones_b[0][-6:]:
                labels.append(label)
                matched = True
                break
        if not matched:
            label = chr(counter)
            counter += 1
            mapping[key] = label
            labels.append(label)
    return labels


def parse_lyrics(lyrics: str) -> FlowMap:
    raw_lines = [l.strip() for l in lyrics.strip().split('\n') if l.strip()]
    lyric_lines = []
    end_words = []

    for line in raw_lines:
        words = line.split()
        all_syllables = []
        all_stressed = []
        offset = 0
        for word in words:
            syls = syllabify_word(word)
            stress = get_stress_positions(word)
            stressed_abs = [offset + s for s in stress]
            all_syllables.extend(syls)
            all_stressed.extend(stressed_abs)
            offset += len(syls)

        end_word = re.sub(r"[^a-zA-Z']", "", words[-1]).lower() if words else ""
        end_words.append(end_word)

        lyric_lines.append(LyricLine(
            text=line,
            syllables=all_syllables,
            syllable_count=len(all_syllables),
            words=words,
            stressed_positions=all_stressed,
        ))

    rhyme_keys = [get_rhyme_key(w) for w in end_words]
    rhyme_scheme = label_rhyme_scheme(rhyme_keys)

    total = sum(l.syllable_count for l in lyric_lines)
    avg = total / len(lyric_lines) if lyric_lines else 0

    return FlowMap(
        lines=lyric_lines,
        total_syllables=total,
        avg_syllables_per_line=avg,
        rhyme_scheme=rhyme_scheme,
    )
