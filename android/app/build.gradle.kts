plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.padelx"
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
        applicationId = "com.example.padelx"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("staging") {
            dimension = "environment"
            applicationId = "com.example.padelx"
        }
        create("production") {
            dimension = "environment"
            applicationId = "com.pabloware.padelx"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

val stagingGoogleServices = file("src/staging/google-services.json")
tasks.configureEach {
    if (name.startsWith("processStaging") && name.endsWith("GoogleServices")) {
        doFirst {
            require(stagingGoogleServices.isFile) {
                "Missing staging Firebase config: android/app/src/staging/google-services.json"
            }
            val contents = stagingGoogleServices.readText()
            require(Regex("\\\"project_id\\\"\\s*:\\s*\\\"padelx-staging\\\"").containsMatchIn(contents)) {
                "Android staging Firebase config must target padelx-staging."
            }
            require(Regex("\\\"package_name\\\"\\s*:\\s*\\\"com\\.example\\.padelx\\\"").containsMatchIn(contents)) {
                "Android staging Firebase config has the wrong package identity."
            }
        }
    }
}

flutter {
    source = "../.."
}
