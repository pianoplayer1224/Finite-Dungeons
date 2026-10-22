"""Make the sound effects in assets/sfx/ safe for Godot: every WAV above 44.1 kHz is resampled to
44.1 kHz with a proper (anti-aliasing) resampler, in place. The original is kept, untouched, in
tools/sfx/<category>/ (that folder has a .gdignore, so Godot neither imports nor exports it).

Why: Godot changes sample rates without a low-pass filter, both on import (force/max_rate) and
when mixing a file whose rate differs from the output's. The HY_PC packs are 96 kHz, and the UI
sounds keep 70-85 % of their energy above 22 kHz: inaudible in a media player (which filters it
out), but Godot folds it back into the audible band as a harsh hiss, so a positive click comes
out buzzy, much like the "denied" one. Run this after adding sounds (needs ffmpeg with soxr):

    python3 -I tools/make_sfx.py

The output is 16-bit PCM with dither: Godot stores audio at 16 bits (or compressed) anyway, and
ffmpeg writes 24-bit WAVs as WAVE_FORMAT_EXTENSIBLE, which Godot's importer rejects. Files already
at 44.1 kHz or below in plain PCM are left alone, so rerunning it is safe. Godot reimports the
changed files on its next filesystem scan.
"""
import os
import pathlib
import shutil
import struct
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SFX = ROOT / "assets/sfx"
MASTERS = ROOT / "tools/sfx"
RATE = 44100  # Godot's default mix rate (audio/driver/mix_rate)


def sample_rate(path: pathlib.Path) -> int:
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries",
                          "stream=sample_rate", "-of", "csv=p=0", str(path)],
                         capture_output=True, text=True, check=True).stdout
    return int(out.strip())


def format_tag(path: pathlib.Path) -> int:
    """The fmt chunk's format tag: 1 is plain PCM, 0xFFFE is WAVE_FORMAT_EXTENSIBLE."""
    head = path.read_bytes()[:4096]
    i = head.find(b"fmt ")
    return struct.unpack("<H", head[i + 8:i + 10])[0] if i >= 0 else -1


def main() -> None:
    if shutil.which("ffmpeg") is None or shutil.which("ffprobe") is None:
        sys.exit("ffmpeg and ffprobe are needed")
    MASTERS.mkdir(parents=True, exist_ok=True)
    (MASTERS / ".gdignore").touch()
    done = kept = 0
    for wav in sorted(SFX.glob("*/*.wav")):
        if wav.parent.name.startswith("."):  # Godot skips dot-folders (e.g. .ignore/)
            continue
        rate = sample_rate(wav)
        if rate <= RATE and format_tag(wav) == 1:
            kept += 1
            continue
        master = MASTERS / wav.parent.name / wav.name
        master.parent.mkdir(exist_ok=True)
        if not master.exists():
            shutil.copy2(wav, master)
        tmp = wav.with_suffix(".tmp.wav")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(master),
                        "-af", f"aresample={RATE}:resampler=soxr:precision=28:dither_method=triangular",
                        "-c:a", "pcm_s16le", "-map_metadata", "-1", "-fflags", "+bitexact", str(tmp)],
                       check=True)
        os.replace(tmp, wav)
        done += 1
        print(f"{wav.relative_to(ROOT)}: {sample_rate(master)} Hz -> {RATE} Hz")
    print(f"{done} resampled, {kept} already at {RATE} Hz or below; originals in {MASTERS.relative_to(ROOT)}/")


main()
