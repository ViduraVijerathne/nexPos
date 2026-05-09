import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}

fun readSigningValue(propertyKey: String, envKey: String): String {
    return keystoreProperties.getProperty(propertyKey)
        ?: System.getenv(envKey)
        ?: ""
}

val releaseStoreFilePath = readSigningValue("storeFile", "ANDROID_KEYSTORE_PATH")
val releaseStorePassword = readSigningValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = readSigningValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = readSigningValue("keyPassword", "ANDROID_KEY_PASSWORD")
val hasReleaseSigning =
    releaseStoreFilePath.isNotBlank() &&
        releaseStorePassword.isNotBlank() &&
        releaseKeyAlias.isNotBlank() &&
        releaseKeyPassword.isNotBlank()

android {
    namespace = "com.vidura.nex_pos_desktop"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.vidura.nex_pos_desktop"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFilePath)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
