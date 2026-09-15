# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# App Locker Native Enforcement components
-keep class com.example.applockbytime.AppLockAccessibilityService { *; }
-keep class com.example.applockbytime.LockScreenActivity { *; }
-keep class com.example.applockbytime.MainActivity { *; }
-keep class com.example.applockbytime.BootReceiver { *; }
-keep class com.example.applockbytime.PackageChangeReceiver { *; }
-keep class com.example.applockbytime.LockStorage { *; }
-keep class com.example.applockbytime.LockInfo { *; }
