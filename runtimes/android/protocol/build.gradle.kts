// Device Protocol bindings. src/main is generated from proto/ by `pnpm proto:generate`.
plugins {
    `java-library`
    `maven-publish`
    alias(libs.plugins.kotlin.jvm)
}

kotlin {
    jvmToolchain(21)
}

dependencies {
    api(libs.protobuf.kotlin.lite)
    testImplementation(kotlin("test"))
}

tasks.test {
    useJUnitPlatform()
}

publishing {
    publications.create<MavenPublication>("maven") { from(components["java"]) }
    val irisrunHome = System.getenv("IRISRUN_HOME") ?: "${System.getProperty("user.home")}/.irisrun"
    repositories.maven("$irisrunHome/maven")
}
