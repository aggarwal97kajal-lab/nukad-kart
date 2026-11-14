# MapLibre (Ola Maps) native map: keep classes used through JNI in release builds.
-keep class org.maplibre.** { *; }
-dontwarn org.maplibre.**
# In-app voice calls (flutter_webrtc): WebRTC classes are called from native code.
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**
-keep class com.cloudwebrtc.webrtc.** { *; }
