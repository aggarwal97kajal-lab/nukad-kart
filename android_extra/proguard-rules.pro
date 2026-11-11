# MapLibre (Ola Maps) native map: keep classes used through JNI in release builds.
-keep class org.maplibre.** { *; }
-dontwarn org.maplibre.**
