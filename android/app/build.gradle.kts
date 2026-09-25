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

val uploadKeyPropertiesFile = rootProject.file("key.properties")
val uploadKeyProperties = Properties().apply {
    if (uploadKeyPropertiesFile.isFile) {
        uploadKeyPropertiesFile.inputStream().use(::load)
    }
}
val requiredUploadKeyProperties = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
)
val productionReleaseRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("ProductionRelease", ignoreCase = true)
}
val missingUploadKeyProperties = requiredUploadKeyProperties.filter { name ->
    uploadKeyProperties.getProperty(name)?.trim().isNullOrEmpty()
}

if (productionReleaseRequested) {
    require(uploadKeyPropertiesFile.isFile) {
        "Production release signing requires ignored android/key.properties. " +
            "See android/key.properties.example and docs/android_release_signing.md."
    }
    require(missingUploadKeyProperties.isEmpty()) {
        "Production release signing configuration is incomplete. Missing: " +
            missingUploadKeyProperties.joinToString(", ") + "."
    }
    val uploadKeystore = rootProject.file(uploadKeyProperties.getProperty("storeFile"))
    require(uploadKeystore.isFile) {
        "Production upload keystore was not found at the configured local path."
    }
}

val uploadSigningReady = uploadKeyPropertiesFile.isFile &&
    missingUploadKeyProperties.isEmpty() &&
    rootProject.file(uploadKeyProperties.getProperty("storeFile", "")).isFile

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

    signingConfigs {
        if (uploadSigningReady) {
            create("upload") {
                storeFile = rootProject.file(uploadKeyProperties.getProperty("storeFile"))
                storePassword = uploadKeyProperties.getProperty("storePassword")
                keyAlias = uploadKeyProperties.getProperty("keyAlias")
                keyPassword = uploadKeyProperties.getProperty("keyPassword")
            }
        }
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
            if (uploadSigningReady) {
                signingConfig = signingConfigs.getByName("upload")
            }
        }
    }

    buildTypes {
        release {
            // Production receives the dedicated upload-key configuration from
            // its flavor. Never fall back to debug signing for store artifacts.
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
