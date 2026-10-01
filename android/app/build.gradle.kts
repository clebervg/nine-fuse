import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Credenciais de release vêm de android/key.properties (fora do git). O
// template está em key.properties.example.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.game.ninefuse"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications usa java.time internamente; sem
        // desugaring o build falha em dispositivos com API < 26.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.game.ninefuse"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        // App ID do AdMob por tipo de build, injetado no manifest. Debug fica
        // com o ID de TESTE do Google: um build de desenvolvimento pedindo
        // inventário real conta como tráfego inválido e arrisca a conta.
        // Release (e profile, que herda dele) usa o ID de produção.
        debug {
            manifestPlaceholders["admobAppId"] =
                "ca-app-pub-3940256099942544~3347511713"
        }
        release {
            manifestPlaceholders["admobAppId"] =
                "ca-app-pub-5525495238538539~6427370565"
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Sem key.properties o release cai na chave de debug, só para
                // `flutter run --release` funcionar em desenvolvimento. Esse
                // APK/AAB NÃO serve para a Play Store, que recusa chave de
                // debug — por isso o aviso, para não passar despercebido.
                logger.warn(
                    "key.properties ausente: build release assinado com a chave " +
                        "de DEBUG (não publicável). Veja android/key.properties.example."
                )
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
