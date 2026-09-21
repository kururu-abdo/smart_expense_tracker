import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}
val releaseKeys = Properties()
val releaseKeyFile = rootProject.file("key.properties")
if (releaseKeyFile.exists()) releaseKeys.load(FileInputStream(releaseKeyFile))
android {
    namespace = "com.kururu.masar"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }
    defaultConfig {
        applicationId = "com.kururu.masar"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        if (releaseKeyFile.exists()) create("release") {
            keyAlias = releaseKeys["keyAlias"] as String
            keyPassword = releaseKeys["keyPassword"] as String
            storeFile = file(releaseKeys["storeFile"] as String)
            storePassword = releaseKeys["storePassword"] as String
        }
    }
    buildTypes {
        release { if (releaseKeyFile.exists()) signingConfig = signingConfigs.getByName("release") }
    }
}
flutter { source = "../.." }
