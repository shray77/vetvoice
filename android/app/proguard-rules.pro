# Vosk offline speech recognition & JNA
-keep class com.alphacephei.** { *; }
-keepclassmembers class com.alphacephei.** { *; }
-dontwarn com.alphacephei.**

-keep class org.vosk.** { *; }
-keepclassmembers class org.vosk.** { *; }
-dontwarn org.vosk.**

# Java Native Access (JNA) - critical for JNI field reflection (Pointer.peer, etc.)
-keep class com.sun.jna.** { *; }
-keepclassmembers class com.sun.jna.** { *; }
-dontwarn com.sun.jna.**
-keepclassmembers class * extends com.sun.jna.Structure {
    public <fields>;
}

# Keep native methods and JNI callbacks
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep MethodChannel and Kotlin application classes
-keep class com.vetvoice.vetvoice.** { *; }
-keepclassmembers class com.vetvoice.vetvoice.** { *; }

# Kotlin Coroutines
-keep class kotlinx.coroutines.** { *; }
-keepclassmembers class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Attributes
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,Exceptions
-dontwarn sun.misc.**
