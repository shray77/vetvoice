# Vosk native libraries
-keep class com.alphacephei.** { *; }
-dontwarn com.alphacephei.**

# Keep MethodChannel classes
-keep class com.vetvoice.vetvoice.** { *; }

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
