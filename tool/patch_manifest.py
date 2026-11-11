"""Adds what voice search needs to the Android manifest made by `flutter create`."""
import pathlib, re

p = pathlib.Path("android/app/src/main/AndroidManifest.xml")
s = p.read_text()
perms = [
    '<uses-permission android:name="android.permission.RECORD_AUDIO"/>',
    '<uses-permission android:name="android.permission.INTERNET"/>',
    '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>',
    '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>',
]
for perm in perms:
    if perm not in s:
        s = s.replace("<application", perm + "\n    <application", 1)
query = '<intent><action android:name="android.speech.RecognitionService"/></intent>'
if query not in s:
    if "<queries>" in s:
        s = s.replace("<queries>", "<queries>\n        " + query, 1)
    else:
        s = s.replace("</manifest>", "    <queries>\n        " + query + "\n    </queries>\n</manifest>", 1)
p.write_text(s)
print(s)
