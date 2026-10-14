plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// إذا وضع المستخدم ملف google-services.json في المجلد الرئيسي للمشروع، ننسخه تلقائياً إلى android/app/
val rootGoogleServices = file("../../google-services.json")
val appGoogleServices = file("google-services.json")
if (rootGoogleServices.exists() && !appGoogleServices.exists()) {
    rootGoogleServices.copyTo(appGoogleServices, overwrite = true)
}

// قراءة package_name تلقائياً من ملف google-services.json لضمان تطابق applicationId وعدم فشل البناء أبداً
val detectedApplicationId: String = if (appGoogleServices.exists()) {
    val content = appGoogleServices.readText()
    val match = Regex(""""package_name"\s*:\s*"([^"]+)"""").find(content)
    match?.groupValues?.get(1) ?: "com.our.loveStory"
} else {
    "com.our.loveStory"
}

if (appGoogleServices.exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.our.loveStory"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = detectedApplicationId
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
