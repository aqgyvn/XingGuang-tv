# TV
-keep class com.fongmi.quickjs.method.** { *; }
-keep class com.fongmi.android.tv.bean.** { *; }

# Gson
-keep class com.google.gson.** { *; }

# SimpleXML
-keep interface org.simpleframework.xml.core.Label { public *; }
-keep class * implements org.simpleframework.xml.core.Label { public *; }
-keep interface org.simpleframework.xml.core.Parameter { public *; }
-keep class * implements org.simpleframework.xml.core.Parameter { public *; }
-keep interface org.simpleframework.xml.core.Extractor { public *; }
-keep class * implements org.simpleframework.xml.core.Extractor { public *; }
-keepclassmembers,allowobfuscation class * { @org.simpleframework.xml.Path <fields>; }
-keepclassmembers,allowobfuscation class * { @org.simpleframework.xml.Root <fields>; }
-keepclassmembers,allowobfuscation class * { @org.simpleframework.xml.Text <fields>; }
-keepclassmembers,allowobfuscation class * { @org.simpleframework.xml.Element <fields>; }
-keepclassmembers,allowobfuscation class * { @org.simpleframework.xml.Attribute <fields>; }
-keepclassmembers,allowobfuscation class * { @org.simpleframework.xml.ElementList <fields>; }

# Runtime-loaded crawlers (including native/guard loaders) resolve the original ABI.
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-keep class com.thegrizzlylabs.sardineandroid.** { *; }
-keep class com.github.catvod.net.Ok* { *; }
-keep class com.github.catvod.net.XgDns { *; }
-keep class com.github.catvod.net.XgAuthenticator { *; }
-keep class com.github.catvod.net.XgProxySelector { *; }
-keep class com.github.catvod.net.interceptor.** { *; }
-keep class com.github.catvod.bean.Doh { *; }
-keep class com.github.catvod.bean.Proxy { *; }
-keep class com.github.catvod.utils.Util { *; }

# CatVod
-keep class com.github.catvod.Proxy { *; }
-keep class com.github.catvod.crawler.** { *; }
-keep class * extends com.github.catvod.crawler.Spider
-keep class com.github.catvod.net.spider.** { *; }
-keep class com.github.catvod.net.webdav.** { *; }

# Cling
-dontwarn javax.**
-dontwarn sun.net.**
-dontwarn java.awt.**
-dontwarn com.sun.net.**
-dontwarn org.ietf.jgss.**
-keep class org.fourthline.cling.** { *; }
-keep class javax.xml.** { *; }

# EXO
-dontwarn org.kxml2.io.**
-dontwarn org.xmlpull.v1.**
-dontwarn android.content.res.**
-dontwarn org.slf4j.impl.StaticLoggerBinder
-keep class org.xmlpull.** { *; }
-keepclassmembers class org.xmlpull.** { *; }

# Jianpian
-keep class com.p2p.** { *; }

# Nano
-keep class fi.iki.elonen.** { *; }

# NewPipeExtractor
-keep class javax.script.** { *; }
-keep class jdk.dynalink.** { *; }
-keep class org.mozilla.javascript.* { *; }
-keep class org.mozilla.javascript.** { *; }
-keep class org.mozilla.javascript.engine.** { *; }
-keep class org.mozilla.classfile.ClassFileWriter
-keep class org.schabi.newpipe.extractor.timeago.patterns.** { *; }
-keep class org.schabi.newpipe.extractor.services.youtube.protos.** { *; }
-dontwarn org.mozilla.javascript.JavaToJSONConverters
-dontwarn org.mozilla.javascript.tools.**
-dontwarn com.google.re2j.**
-dontwarn javax.script.**
-dontwarn jdk.dynalink.**

# Smbj
-keep class com.hierynomus.** { *; }
-keep class net.engio.mbassy.** { *; }

# TVBus
-keep class com.tvbus.engine.** { *; }

# XunLei
-keep class com.xunlei.downloadlib.** { *; }

# Zxing
-keep class com.google.zxing.** { *; }
