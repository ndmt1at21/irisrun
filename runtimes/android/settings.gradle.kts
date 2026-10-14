pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositoriesMode = RepositoriesMode.FAIL_ON_PROJECT_REPOS
    repositories {
        mavenCentral()
        // Robolectric depends on androidx.test.
        google()
    }
}

rootProject.name = "irisrun-android"

include(":host", ":protocol")
