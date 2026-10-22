"""Make the game's music, assets/music/*.ogg, from the masters in tools/music/ (that folder has a
.gdignore, so Godot neither imports nor exports the masters). Needs ffmpeg with libvorbis:

    python3 -I tools/make_music.py

The masters are 320 kbps MP3s (12.7 MB for the two). Ogg Vorbis at quality 4 (about 128 kbps)
is about 5 MB and still sounds the same under the sound effects, and unlike MP3 it loops
without a gap: an MP3 carries the encoder's padding, which Godot plays as a short silence at the
loop point. "Woodland Fantasy" is cut at the end of its fade-out (the master has 5 s of silence
after it), so its loop has no gap either. Godot reimports the files on its next filesystem scan.
"""
import pathlib
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MASTERS = ROOT / "tools/music"
OUT = ROOT / "assets/music"
QUALITY = "4"  # libvorbis -q:a (0-10)
TRACKS = {  # master file -> seconds to keep (None: all of it)
    "Woodland Fantasy.mp3": 144.6,
    "The Last Encounter.mp3": None,
}


def main() -> None:
    if shutil.which("ffmpeg") is None:
        sys.exit("ffmpeg is needed")
    for name, keep in TRACKS.items():
        master = MASTERS / name
        out = OUT / (master.stem + ".ogg")
        cut = ["-t", str(keep)] if keep else []
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(master), *cut, "-map", "0:a",
                        "-c:a", "libvorbis", "-q:a", QUALITY, "-map_metadata", "-1",
                        "-fflags", "+bitexact", str(out)], check=True)
        print(f"{out.relative_to(ROOT)}: {master.stat().st_size / 1e6:.1f} MB -> {out.stat().st_size / 1e6:.1f} MB")


main()
