"""iPhone build setup (customer and Partner app), run after `flutter create --platforms=ios`.

Usage: python3 ios_setup.py "<App name>"   (from the app's folder)

- Permission messages iOS needs before an app may use the mic, location, camera, photos or speech (without
  them the app is closed by iOS the moment it asks).
- Background modes: calls keep sound with the screen off, delivery location keeps going, pushes can wake the app.
- Minimum iOS 15 (maps, Firebase, scanner need it).
"""
import pathlib
import plistlib
import re
import sys

name = sys.argv[1] if len(sys.argv) > 1 else "Nukad Kart"

plist_path = pathlib.Path("ios/Runner/Info.plist")
with plist_path.open("rb") as f:
    p = plistlib.load(f)

p["CFBundleDisplayName"] = name
p["CFBundleName"] = name
p.update({
    "NSMicrophoneUsageDescription": "For in-app calls with the shop, delivery partner or customer, and voice search.",
    "NSSpeechRecognitionUsageDescription": "To type what you say in voice search.",
    "NSLocationWhenInUseUsageDescription": "To find shops near you and show deliveries on the map.",
    "NSLocationAlwaysAndWhenInUseUsageDescription": "To show the customer where their delivery is, also when the app is in the background.",
    "NSLocationAlwaysUsageDescription": "To show the customer where their delivery is, also when the app is in the background.",
    "NSCameraUsageDescription": "To take photos of products and documents, and to scan codes.",
    "NSPhotoLibraryUsageDescription": "To pick photos of products and documents.",
    "NSPhotoLibraryAddUsageDescription": "To save bills and documents.",
    "UIBackgroundModes": ["audio", "location", "remote-notification"],
    "ITSAppUsesNonExemptEncryption": False,
    "UIFileSharingEnabled": True,
    "LSSupportsOpeningDocumentsInPlace": True,
})
with plist_path.open("wb") as f:
    plistlib.dump(p, f)

# Podfile: iOS 15, and every pod built for iOS 15 too.
pod = pathlib.Path("ios/Podfile")
s = pod.read_text()
s = re.sub(r"^#?\s*platform :ios, '[\d.]+'", "platform :ios, '15.0'", s, flags=re.M)
if "platform :ios" not in s:
    s = "platform :ios, '15.0'\n" + s
if "IPHONEOS_DEPLOYMENT_TARGET" not in s:
    s = s.replace(
        "    flutter_additional_ios_build_settings(target)",
        "    flutter_additional_ios_build_settings(target)\n"
        "    target.build_configurations.each do |config|\n"
        "      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'\n"
        "    end",
    )
pod.write_text(s)

proj = pathlib.Path("ios/Runner.xcodeproj/project.pbxproj")
t = proj.read_text()
t = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = [\d.]+;", "IPHONEOS_DEPLOYMENT_TARGET = 15.0;", t)
proj.write_text(t)
print("iOS setup done for", name)
