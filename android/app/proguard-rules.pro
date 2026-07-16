# Flutter ProGuard Rules
# These rules prevent R8 from stripping classes that Flutter accesses via
# reflection at runtime. Without these, release APKs can crash or misbehave.

# Keep Flutter engine classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep Dart/Flutter generated code
-keep class com.example.kanakku_flutter.** { *; }

# Keep Supabase/OkHttp networking classes used via reflection
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep Kotlin coroutines metadata
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }
-dontwarn kotlinx.coroutines.**

# Suppress warnings for classes not present in release builds
-dontwarn java.lang.instrument.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
