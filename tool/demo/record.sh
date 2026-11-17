#!/usr/bin/env bash
# Runs on the GitHub emulator (demo-video.yml): installs the demo build, records the screen while the tour test drives the app.
#   tool/demo/record.sh customer
set -uo pipefail
TOUR="${1:-customer}"
OUT=demo-out
PKG=com.nukadkart.nukad_kart
tok() { node -e "process.stdout.write(require('./$OUT/tokens.json').$1)"; }

adb shell settings put system screen_off_timeout 1800000
adb shell settings put global window_animation_scale 1
adb shell settings put global transition_animation_scale 1
adb shell settings put global animator_duration_scale 1
adb shell cmd overlay enable com.android.internal.systemui.navbar.gestural || true
adb emu geo fix 77.0884 28.5895

DEFINES="--dart-define=API_BASE=http://10.0.2.2:8787 --dart-define=DEMO_TOKEN=$(tok customer) --dart-define=SHOP_TOKEN=$(tok gupta) --dart-define=THELA_TOKEN=$(tok ramesh)"
flutter build apk --profile --target=integration_test/${TOUR}_tour_test.dart $DEFINES 2>&1 | tail -25
APK=build/app/outputs/flutter-apk/app-profile.apk
adb install -r -g "$APK"
for p in ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION POST_NOTIFICATIONS RECORD_AUDIO CAMERA; do adb shell pm grant $PKG android.permission.$p 2>/dev/null || true; done

# Thelas show for 10 minutes after their last location: send a fresh one now.
for k in ramesh sita; do
  pos=$(node -e "const t=require('./$OUT/tokens.json');const id={ramesh:'t_ramesh',sita:'t_sita'}['$k'];process.stdout.write(JSON.stringify(t.thelas[id]))")
  curl -s -X POST localhost:8787/v1/partner/location -H "authorization: Bearer $(tok $k)" -H 'content-type: application/json' -d "$pos"; echo
done

adb logcat -c
adb logcat -v epoch -s flutter:I NKREC:I > $OUT/logcat.txt &
LOGPID=$!
adb shell 'log -t NKREC start; screenrecord --bit-rate 16000000 --time-limit 180 /sdcard/r1.mp4; log -t NKREC r2; screenrecord --bit-rate 16000000 --time-limit 180 /sdcard/r2.mp4' &
RECPID=$!
sleep 1

flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/${TOUR}_tour_test.dart \
  --use-application-binary="$APK" $DEFINES > $OUT/drive.log 2>&1
echo "drive exit $?" | tee -a $OUT/drive.log
sleep 2
adb shell pkill -INT screenrecord || true
sleep 4
kill $LOGPID 2>/dev/null || true
wait $RECPID 2>/dev/null || true
adb pull /sdcard/r1.mp4 $OUT/r1.mp4 || true
adb pull /sdcard/r2.mp4 $OUT/r2.mp4 || true
adb exec-out screencap -p > $OUT/last.png || true
ls -la $OUT
