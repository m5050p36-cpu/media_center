import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ═══ قراءة إعدادات التوقيع ═══
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// ═══ حل المسار بشكل مطلق (يحل مشكلة android/app/keys vs android/keys) ═══
val keystoreFilePath: String? = if (keystorePropertiesFile.exists()) {
    val rawPath = keystoreProperties["storeFile"] as? String
    if (rawPath != null) {
        // إذا كان مساراً نسبياً، حلّه بالنسبة لمجلد android/
        val f = File(rawPath)
        if (f.isAbsolute) rawPath else File(rootProject.projectDir, rawPath).absolutePath
    } else null
} else null

android {
    namespace = "com.mediahub.mediacenter"
    compileSdk = 36
    // ═══ تحديث NDK إلى 28.2.13676358 حسب متطلب jni ═══
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.mediahub.mediacenter"
        minSdk = 23
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists() && keystoreFilePath != null) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = File(keystoreFilePath)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists() && keystoreFilePath != null)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            // ═══ R8 معطّل مؤقتاً لتشخيص انهيار التطبيق ═══
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")
}
