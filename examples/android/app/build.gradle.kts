plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// A map token for the example: `./gradlew :app:assembleDebug -PsmapToken=sm1....` (empty = no token).
val smapToken: String = (project.findProperty("smapToken") as String?) ?: ""
// Or a map key whose allowlist names this app: `-PsmapApiKey=smk_...` (empty = no key).
val smapApiKey: String = (project.findProperty("smapApiKey") as String?) ?: ""
// Another map service, e.g. a local node: `-PsmapBaseUrl=http://...` (empty = the public one).
val smapBaseUrl: String = (project.findProperty("smapBaseUrl") as String?) ?: ""

android {
    namespace = "ca.superroute.smap.example"
    compileSdk = 36

    defaultConfig {
        applicationId = "ca.superroute.smap.example"
        minSdk = 23
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
        buildConfigField("String", "SMAP_TOKEN", "\"$smapToken\"")
        buildConfigField("String", "SMAP_API_KEY", "\"$smapApiKey\"")
        buildConfigField("String", "SMAP_BASE_URL", "\"$smapBaseUrl\"")
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    implementation("ca.superroute:smap:1.5.1")
}
