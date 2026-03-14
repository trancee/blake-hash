plugins {
    kotlin("jvm")
    `maven-publish`
    signing
}

group = "ch.trancee"
version = providers.gradleProperty("releaseVersion").getOrElse("0.0.0-SNAPSHOT")

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
    useJUnitPlatform {
        excludeTags("benchmark")
    }
    systemProperty(
        "test.vectors.dir",
        rootProject.rootDir.resolve("../test-vectors").absolutePath
    )
}

tasks.register<Test>("benchmark") {
    description = "Runs benchmark tests."
    group = "verification"
    useJUnitPlatform {
        includeTags("benchmark")
    }
    testClassesDirs = tasks.test.get().testClassesDirs
    classpath = tasks.test.get().classpath
    testLogging {
        showStandardStreams = true
    }
    systemProperty(
        "test.vectors.dir",
        rootProject.rootDir.resolve("../test-vectors").absolutePath
    )
}

// ── Publishing ──────────────────────────────────────────────────────────

java {
    withSourcesJar()
    withJavadocJar()
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            from(components["java"])

            artifactId = "blake-hash"

            pom {
                name = "blake-hash"
                description = "Pure-Kotlin BLAKE2 and BLAKE3 cryptographic hash library with zero dependencies."
                url = "https://github.com/trancee/blake-hash"

                licenses {
                    license {
                        name = "MIT License"
                        url = "https://opensource.org/licenses/MIT"
                    }
                }

                developers {
                    developer {
                        id = "trancee"
                        name = "trancee"
                        url = "https://github.com/trancee"
                    }
                }

                scm {
                    url = "https://github.com/trancee/blake-hash"
                    connection = "scm:git:https://github.com/trancee/blake-hash.git"
                    developerConnection = "scm:git:ssh://git@github.com/trancee/blake-hash.git"
                }
            }
        }
    }

    repositories {
        maven {
            name = "OSSRH"
            url = uri("https://central.sonatype.com/repository/maven-snapshots/").let { snap ->
                if (version.toString().endsWith("-SNAPSHOT")) snap
                else uri("https://ossrh-staging-api.central.sonatype.com/service/local/staging/deploy/maven2/")
            }
            credentials {
                username = providers.environmentVariable("OSSRH_USERNAME").orNull
                password = providers.environmentVariable("OSSRH_PASSWORD").orNull
            }
        }

        maven {
            name = "GitHubPackages"
            url = uri("https://maven.pkg.github.com/trancee/blake-hash")
            credentials {
                username = providers.environmentVariable("GITHUB_ACTOR").orNull
                password = providers.environmentVariable("GITHUB_TOKEN").orNull
            }
        }
    }
}

signing {
    val signingKey = providers.environmentVariable("GPG_PRIVATE_KEY").orNull
    val signingPassword = providers.environmentVariable("GPG_PASSPHRASE").orNull
    if (signingKey != null) {
        useInMemoryPgpKeys(signingKey, signingPassword)
        sign(publishing.publications["maven"])
    }
}
