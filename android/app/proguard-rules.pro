# v1.16.5: КОРНЕВОЙ фикс краша Vosk (UnsatisfiedLinkError: Can't obtain peer
# field ID for class com.sun.jna.Pointer). R8 (minifyEnabled true) переименовывал
# com.sun.jna.Pointer — у него нет native-методов, поэтому дефолтное правило AGP
# (-keepclasseswithmembernames class * { native <methods>; }) сохраняло имя только
# com.sun.jna.Native. Нативный initIDs() внутри libjnidispatch.so ищет классы JNA
# ПО ИМЕНИ через JNI (FindClass/GetFieldID) — переименованный Pointer не находится,
# первый же вызов Model(...) падал и ронял всё приложение. JNA — это
# "Java Native Access": ВСЕ классы com.sun.jna трогаются из нативного кода по
# строковым именам, для R8 они невидимы. Хранить целиком, с членами.
-keep class com.sun.jna.** { *; }
-dontwarn com.sun.jna.**

# vosk-android: весь Java-код живёт в пакете org.vosk / org.vosk.android.
# Старое правило com.alphacephei.** (ниже) сохраняло пустоту: com.alphacephei —
# это maven-ГРУППА артефакта, а не Java-пакет. Конструкторы Model/Recognizer и
# колбэки RecognitionListener вызываются/реализуются через нативный и рефлексивный
# код — хранить целиком.
-keep class org.vosk.** { *; }
-dontwarn org.vosk.**

# (историческое, безвредно) maven-группа vosk — Java-пакетов с таким именем нет
-keep class com.alphacephei.** { *; }
-dontwarn com.alphacephei.**

# Keep MethodChannel classes
-keep class com.vetvoice.vetvoice.** { *; }

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
