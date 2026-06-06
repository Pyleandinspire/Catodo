# Isar Database - Keep native bindings
-keep class dev.isar.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep R8 from stripping Native method bindings
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep annotations
-keepattributes *Annotation*

# Fix: Missing class com.google.android.play.core (Play Store Deferred Components)
# Catodo doesn't use Play Store dynamic delivery, so we can safely ignore these
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**