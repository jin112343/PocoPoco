# Flutterアプリ用のProGuard設定

# Flutterの基本設定
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutterのネイティブコード
-keep class io.flutter.embedding.** { *; }

# 広告関連の設定（Google Mobile Ads）
-keep class com.google.android.gms.ads.** { *; }

# 課金関連の設定（In-App Purchase）
-keep class com.android.billingclient.** { *; }

# SharedPreferences関連
-keep class android.content.SharedPreferences { *; }

# 基本的なAndroid設定
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Exceptions,InnerClasses

# ログ出力の保持
-keepclassmembers class * {
    @android.util.Log *;
}

# ネイティブメソッドの保持
-keepclasseswithmembernames class * {
    native <methods>;
}

# 列挙型の保持
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Parcelableの保持
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Serializableの保持
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Rファイルの保持
-keep class **.R$* {
    public static <fields>;
}

# カスタム編み目クラスの保持
-keep class com.example.poco.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Play Core関連の警告を抑制
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
