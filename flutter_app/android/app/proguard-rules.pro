# Omnio loads Cloudstream extension DEX files at runtime and mpv calls into
# its Android bridge through JNI, so these classes must remain discoverable.
-keep class is.xyz.mpv.** { *; }
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }
-keep class okhttp3.** { *; }
-keepclassmembers class okhttp3.** { *; }
-keep class okio.** { *; }
-keepclassmembers class okio.** { *; }
-keep class org.jsoup.** { *; }
-keepclassmembers class org.jsoup.** { *; }
-keep class com.fasterxml.jackson.** { *; }
-keepclassmembers class com.fasterxml.jackson.** { *; }

# Optional JVM-only classes referenced by Cloudstream's Rhino/JS stack.
-dontwarn org.mozilla.javascript.**
-dontwarn com.google.re2j.**
-dontwarn javax.script.**
-dontwarn okhttp3.internal.sse.**
-dontwarn org.jsoup.helper.Re2jRegex
