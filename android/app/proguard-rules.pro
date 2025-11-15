# Keep ProGuard annotations
-dontwarn proguard.annotation.**
-keep class proguard.annotation.** { *; }
-keepattributes *Annotation*

# Razorpay
-keepclassmembers class * {
    @proguard.annotation.Keep *;
    @proguard.annotation.KeepClassMembers *;
}

-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# Keep all classes with @Keep annotation
-keep @proguard.annotation.Keep class * {*;}
-keepclassmembers class * {
    @proguard.annotation.Keep *;
}

# Additional common rules
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses