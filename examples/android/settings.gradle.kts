pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        // sMap for Android (ca.superroute:smap).
        maven { url = uri("https://goodneo-solutions.github.io/smap-sdk-releases/maven") }
    }
}

rootProject.name = "smap-android-example"
include(":app")
project(":app").projectDir = file("app")
