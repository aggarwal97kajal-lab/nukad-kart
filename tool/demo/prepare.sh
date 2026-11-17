#!/usr/bin/env bash
# Android project for a demo build: same patches as the real APKs, plus plain http to the local demo server.
#   tool/demo/prepare.sh customer|kirana|thela   (needs KEYSTORE_PASSWORD)
set -euo pipefail
TOUR="$1"
ROOT=$(pwd)
if [ "$TOUR" = customer ]; then
  flutter create --platforms=android --org com.nukadkart --project-name nukad_kart .
  cp -r android_res/. android/app/src/main/res/
  python3 tool/patch_manifest.py
  python3 tool/patch_activity.py
  cp android_extra/proguard-rules.pro android/app/proguard-rules.pro
  sed -i 's/android:label="[^"]*"/android:label="Nukkad Kart"/' android/app/src/main/AndroidManifest.xml
else
  cd partner
  flutter create --platforms=android --org com.nukadkart --project-name nukad_partner .
  python3 tool/configure_android.py > /dev/null
  sudo apt-get install -y -qq espeak-ng ffmpeg > /dev/null || true
  pip install -q gTTS || true
  python3 tool/make_voice.py || true
  cp ../android_extra/proguard-rules.pro android/app/proguard-rules.pro
fi
M=android/app/src/main/AndroidManifest.xml
sed -i 's/<application/<application android:usesCleartextTraffic="true"/' $M
# Skia instead of Impeller: faster on the emulator's software GPU.
sed -i 's#</application>#<meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false" /></application>#' $M
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -in "$ROOT/android_extra/upload.jks.enc" -out android/app/upload.jks -pass env:KEYSTORE_PASSWORD
printf 'storePassword=%s\nkeyPassword=%s\nkeyAlias=nukadkart\nstoreFile=upload.jks\n' "$KEYSTORE_PASSWORD" "$KEYSTORE_PASSWORD" > android/key.properties
python3 "$ROOT/tool/patch_gradle.py" > /dev/null
flutter pub get
dart run flutter_launcher_icons
