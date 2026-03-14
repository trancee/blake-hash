# Release Process

How to publish a new version of blake-hash to Maven Central, GitHub Packages, and Swift Package Manager.

---

## Overview

Releases are automated via GitHub Actions. Creating a GitHub release with a `v`-prefixed tag triggers the [release workflow](.github/workflows/release.yml), which:

1. Runs the full test suite on both Android and iOS
2. Stages signed artifacts locally, then uploads a bundle to the **Sonatype Central Portal** for publication to **Maven Central**
3. Publishes the Kotlin library to **GitHub Packages**
4. The git tag itself serves as the **Swift Package Manager** release

### Published Artifacts

| Channel | Coordinates / URL |
|---------|-------------------|
| Maven Central | `ch.trancee:blake-hash:<VERSION>` |
| GitHub Packages | `ch.trancee:blake-hash:<VERSION>` via `maven.pkg.github.com/trancee/blake-hash` |
| Swift Package Manager | `https://github.com/trancee/blake-hash.git` (resolved by git tag) |

---

## Prerequisites

Before your first release, configure these repository secrets in **Settings → Secrets and variables → Actions**:

| Secret | Description |
|--------|-------------|
| `OSSRH_USERNAME` | Sonatype Central Portal username (token) |
| `OSSRH_PASSWORD` | Sonatype Central Portal password (token) |
| `GPG_PRIVATE_KEY` | ASCII-armored GPG private key for signing artifacts |
| `GPG_PASSPHRASE` | Passphrase for the GPG key |

`GITHUB_TOKEN` is provided automatically by GitHub Actions.

### Sonatype Central Portal Token

Generate a token at [central.sonatype.com → Account → Generate User Token](https://central.sonatype.com/account). Copy the **username** and **password** values into `OSSRH_USERNAME` and `OSSRH_PASSWORD` respectively. Ensure the namespace `ch.trancee` is verified in the portal.

### Generating a GPG Key

If you don't have a GPG key for signing:

```bash
gpg --full-generate-key          # RSA 4096, no expiry recommended for CI
gpg --armor --export-secret-keys YOUR_KEY_ID
```

Copy the full output (including `-----BEGIN PGP PRIVATE KEY BLOCK-----`) into the `GPG_PRIVATE_KEY` secret. The public key must be published to a keyserver (e.g. `keys.openpgp.org`) for Maven Central verification.

---

## Step-by-Step Release

### 1. Prepare the Release

Ensure `main` is in a releasable state:

```bash
# Run the full test suite on both platforms
./run-tests.sh

# Verify the build produces publishable artifacts
cd android && gradle :lib:publishToMavenLocal -PreleaseVersion=X.Y.Z && cd ..
```

### 2. Choose a Version Number

Follow [Semantic Versioning](https://semver.org):

- **Major** (`X.0.0`) — breaking API changes
- **Minor** (`0.Y.0`) — new features, backward-compatible
- **Patch** (`0.0.Z`) — bug fixes, backward-compatible

### 3. Create the GitHub Release

1. Go to [Releases → Draft a new release](https://github.com/trancee/blake-hash/releases/new)
2. **Tag:** Create a new tag with format `vX.Y.Z` (e.g. `v1.2.0`)
3. **Target:** `main` branch
4. **Title:** `vX.Y.Z`
5. **Description:** Summarize changes (new features, bug fixes, breaking changes)
6. Click **Publish release**

### 4. Monitor the Workflow

The [release workflow](https://github.com/trancee/blake-hash/actions/workflows/release.yml) starts automatically. It will:

1. **Test** — run the full suite on Android (ubuntu/JDK 21) and iOS (macOS 15)
2. **Stage** — build, sign, and stage artifacts to a local directory
3. **Upload** — bundle the staged artifacts and upload to the [Sonatype Central Portal](https://central.sonatype.com) with `publishingType=AUTOMATIC`
4. **GitHub Packages** — publish the same artifacts to GitHub Packages

The version is derived from the tag: `v1.2.0` → `1.2.0`.

### 5. Verify the Release

After the workflow completes:

- **Maven Central:** Check [search.maven.org](https://search.maven.org/search?q=g:ch.trancee%20a:blake-hash) (may take 10–30 minutes to index)
- **GitHub Packages:** Check the [Packages tab](https://github.com/trancee/blake-hash/packages)
- **Swift PM:** Verify the tag is visible:
  ```bash
  swift package resolve --package-url https://github.com/trancee/blake-hash.git
  ```

---

## How Consumers Use a Release

### Android (Gradle — Kotlin DSL)

```kotlin
// build.gradle.kts
repositories {
    mavenCentral()
}

dependencies {
    implementation("ch.trancee:blake-hash:1.2.0")
}
```

Or from GitHub Packages:

```kotlin
repositories {
    maven {
        url = uri("https://maven.pkg.github.com/trancee/blake-hash")
        credentials {
            username = providers.gradleProperty("gpr.user").orNull ?: System.getenv("GITHUB_ACTOR")
            password = providers.gradleProperty("gpr.token").orNull ?: System.getenv("GITHUB_TOKEN")
        }
    }
}

dependencies {
    implementation("ch.trancee:blake-hash:1.2.0")
}
```

### iOS (Swift Package Manager)

In Xcode: **File → Add Package Dependencies** → enter:

```
https://github.com/trancee/blake-hash.git
```

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/trancee/blake-hash.git", from: "1.2.0")
]
```

---

## Publishing Locally (for testing)

To verify the Maven publication without pushing to a remote repository:

```bash
cd android
gradle :lib:publishToMavenLocal -PreleaseVersion=0.0.1-test
```

The artifact is written to `~/.m2/repository/ch/trancee/blake-hash/`.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Workflow fails at signing | Verify `GPG_PRIVATE_KEY` and `GPG_PASSPHRASE` secrets are set correctly. The key must be ASCII-armored. |
| Central Portal rejects the upload (HTTP 401) | Regenerate your token at [central.sonatype.com/account](https://central.sonatype.com/account). Update `OSSRH_USERNAME` / `OSSRH_PASSWORD` secrets. |
| Central Portal rejects the upload (HTTP 403) | Verify the namespace `ch.trancee` is claimed and verified in the [Central Portal](https://central.sonatype.com/publishing/namespaces). |
| Central Portal upload succeeds but validation fails | Check the deployment status in the [Central Portal Deployments tab](https://central.sonatype.com/publishing/deployments). Common causes: missing javadoc JAR, unsigned artifacts, or POM issues. |
| Maven Central doesn't show the artifact | Indexing can take up to 30 minutes after the Central Portal reports success. Check [search.maven.org](https://search.maven.org/search?q=g:ch.trancee%20a:blake-hash). |
| GitHub Packages auth failure | `GITHUB_TOKEN` is automatic in Actions. For local testing, set `GITHUB_ACTOR` and `GITHUB_TOKEN` environment variables. |
| Swift PM can't find the version | Ensure the git tag matches `vX.Y.Z` exactly and is pushed. SPM resolves tags directly from the repository. |
| Tests fail in release workflow | The release workflow runs the same tests as CI. Fix failures on `main` before creating a release. |
