plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.mediscan"
    compileSdk = 36  // خليها 35 أحسن من 36 للتوافق

    ndkVersion = "30.0.14904198"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.mediscan"
        minSdk = 24
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // لو عايز توقع التطبيق بتاعك (للتوزيع)
    signingConfigs {
        create("release") {
            // غير المسار والباسوردات دي حسب ملف الـ keystore بتاعك
            storeFile = file("keystore.jks")
            storePassword = "your_store_password"
            keyAlias = "your_key_alias"
            keyPassword = "your_key_password"
        }
    }

    buildTypes {
        release {
            // للاختبار بس - استخدم debug signing
            signingConfig = signingConfigs.getByName("debug")
            
            // أو لو عايز signing حقيقي: 
            // signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}