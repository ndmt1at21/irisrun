plugins {
    alias(libs.plugins.android.application)
}

android {
    namespace = "dev.irisrun.examples.views"
    compileSdk = 36

    defaultConfig {
        applicationId = "dev.irisrun.examples.views"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }
}

dependencies {
    implementation(libs.androidx.appcompat)
    implementation(libs.material)
}
