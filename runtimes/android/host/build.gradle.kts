// Runs Android apps on Robolectric for `irisrun start`; see HostMain.kt.
plugins {
    `maven-publish`
    alias(libs.plugins.kotlin.jvm)
}

kotlin {
    jvmToolchain(21)
}

dependencies {
    implementation(project(":protocol"))
    implementation(libs.junit)
    implementation(libs.robolectric)
    compileOnly(libs.robolectric.android.all)
}

publishing {
    publications.create<MavenPublication>("maven") { from(components["java"]) }
    val irisrunHome = System.getenv("IRISRUN_HOME") ?: "${System.getProperty("user.home")}/.irisrun"
    repositories.maven("$irisrunHome/maven")
}
