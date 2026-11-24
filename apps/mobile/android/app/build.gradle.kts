import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingFile = rootProject.file("key.properties")
val uploadSigning = Properties().apply {
    if (signingFile.isFile) {
        signingFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "org.reparaai.reparaai"
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
        applicationId = "org.reparaai.reparaai"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (signingFile.isFile) {
        signingConfigs.create("upload") {
            fun property(name: String): String =
                requireNotNull(uploadSigning.getProperty(name)?.takeIf { it.isNotBlank() }) {
                    "Missing '$name' in android/key.properties"
                }
            storeFile = rootProject.file(property("storeFile"))
            storePassword = property("storePassword")
            keyAlias = property("keyAlias")
            keyPassword = property("keyPassword")
        }
    }
    buildTypes {
        release {
            // The debug signer permits local test builds before an upload key is provisioned.
            signingConfig = signingConfigs.getByName(if (signingFile.isFile) "upload" else "debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
