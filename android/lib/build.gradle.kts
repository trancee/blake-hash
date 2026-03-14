plugins {
    kotlin("jvm")
}

repositories {
    mavenCentral()
}

kotlin {
    jvmToolchain(21)
}

dependencies {
    testImplementation(kotlin("test"))
    testImplementation("org.junit.jupiter:junit-jupiter:5.12.2")
    testImplementation("org.json:json:20240303")
}

tasks.test {
    useJUnitPlatform()
    systemProperty(
        "test.vectors.dir",
        rootProject.rootDir.resolve("../test-vectors").absolutePath
    )
}
