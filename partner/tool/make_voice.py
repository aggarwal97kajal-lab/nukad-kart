"""Hindi new-order voice for the Partner app: "नया ऑर्डर आया, अभी चेक करें", then silence, 10 seconds in all.
The notification plays it in a loop (FLAG_INSISTENT), so the phone says it every 10 seconds until the order is
opened or 3 minutes pass. Made at build time: Google TTS (gTTS), or espeak-ng if that is not reachable."""
import os, subprocess, sys, tempfile

TEXT = 'नया ऑर्डर आया, अभी चेक करें'
OUT_DIR = 'android/app/src/main/res/raw'
os.makedirs(OUT_DIR, exist_ok=True)
tmp = tempfile.mkdtemp()
src = os.path.join(tmp, 'voice.mp3')

made = False
try:
    from gtts import gTTS
    gTTS(TEXT, lang='hi').save(src)
    made = os.path.getsize(src) > 1000
    print('voice: gTTS')
except Exception as e:  # noqa: BLE001
    print('gTTS failed:', e)
if not made:
    src = os.path.join(tmp, 'voice.wav')
    subprocess.run(['espeak-ng', '-v', 'hi', '-s', '140', '-w', src, TEXT], check=True)
    print('voice: espeak-ng')

out = os.path.join(OUT_DIR, 'order_voice.ogg')
# Louder, mono, then pad with silence to exactly 10 s.
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', src, '-af', 'loudnorm=I=-12:TP=-1,apad=whole_dur=10',
                '-t', '10', '-ac', '1', '-ar', '22050', '-c:a', 'libvorbis', '-q:a', '5', out], check=True)
# Keep the file in release builds (resource shrinking would drop a sound only named in Dart).
with open(os.path.join(OUT_DIR, 'keep.xml'), 'w') as f:
    f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@raw/order_voice" />\n')
print('wrote', out, os.path.getsize(out), 'bytes')
sys.exit(0)
