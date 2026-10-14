//! Builds an Android app with the project's own Gradle, and runs it on the
//! irisrun host from runtimes/android.

use std::path::{Path, PathBuf};

use anyhow::{Context, Result, bail, ensure};
use tokio::process::Command;

use super::AndroidSdk;

/// Puts the host on the app's unit-test classpath; see the script itself.
const INIT_SCRIPT: &str = include_str!("../../../../runtimes/android/irisrun.gradle");

/// The dev.irisrun.android:host version the init script asks Gradle for.
const HOST_VERSION: &str = "0.1.0";

/// Robolectric's screen when the host asks for none: a 1080 × 2424 px phone
/// at 420 dpi.
pub const DEFAULT_QUALIFIERS: &str = "w411dp-h923dp-420dpi";

pub struct AndroidProject {
    root: PathBuf,
}

impl AndroidProject {
    /// Opens the Gradle project in `dir`. irisrun builds with the project's
    /// own Gradle, so it needs the Gradle wrapper.
    pub fn open(dir: &Path) -> Result<AndroidProject> {
        let has_settings = ["settings.gradle.kts", "settings.gradle"]
            .iter()
            .any(|name| dir.join(name).is_file());
        ensure!(
            has_settings,
            "{} has no settings.gradle(.kts)",
            dir.display()
        );
        ensure!(
            dir.join("gradlew").is_file(),
            "{} has no Gradle wrapper (gradlew)",
            dir.display()
        );
        let root = dir
            .canonicalize()
            .with_context(|| format!("cannot open {}", dir.display()))?;
        Ok(AndroidProject { root })
    }

    /// Runs Gradle with the irisrun init script and returns how to launch the
    /// app module's unit-test JVM, whose classpath then holds the app, its
    /// dependencies and the host. `maven_repo` must hold the
    /// dev.irisrun.android artifacts.
    pub async fn build(
        &self,
        java_home: &Path,
        sdk: &AndroidSdk,
        maven_repo: &Path,
    ) -> Result<Launch> {
        let out = self.root.join(".irisrun/build");
        tokio::fs::create_dir_all(&out).await?;
        // Keeps irisrun's files out of git without editing the project's .gitignore.
        tokio::fs::write(self.root.join(".irisrun/.gitignore"), "*\n").await?;
        let script = out.join("irisrun.gradle");
        tokio::fs::write(&script, INIT_SCRIPT).await?;

        let status = Command::new(self.root.join("gradlew"))
            .current_dir(&self.root)
            .env("JAVA_HOME", java_home)
            .env("ANDROID_HOME", sdk.root())
            .arg("--init-script")
            .arg(&script)
            .arg(format!("-Pirisrun.repo={}", maven_repo.display()))
            .arg(format!("-Pirisrun.version={HOST_VERSION}"))
            .arg(format!("-Pirisrun.out={}", out.display()))
            .arg("irisrunClasspath")
            .status()
            .await
            .context("cannot run gradlew")?;
        ensure!(status.success(), "the Gradle build failed");

        let file = app_launch_file(&out)?;
        let text = tokio::fs::read_to_string(&file)
            .await
            .with_context(|| format!("cannot read {}", file.display()))?;
        let mut lines = text.lines();
        let (Some(working_dir), Some(classpath)) = (lines.next(), lines.next()) else {
            bail!("{} is malformed", file.display());
        };
        Ok(Launch {
            working_dir: working_dir.into(),
            classpath: classpath.to_owned(),
            jvm_args: lines
                .next()
                .unwrap_or_default()
                .split('\t')
                .filter(|arg| !arg.is_empty())
                .map(String::from)
                .collect(),
        })
    }
}

/// The JVM the app module's unit tests would run in, as the init script
/// found it.
pub struct Launch {
    /// Robolectric resolves the app's resource paths from here.
    pub working_dir: PathBuf,
    pub classpath: String,
    /// Includes the --add-opens flags Robolectric needs on recent JDKs.
    pub jvm_args: Vec<String>,
}

/// The command that runs the app on the host, which speaks the Device
/// Protocol on stdin and stdout.
pub fn host_command(java_home: &Path, launch: &Launch, qualifiers: &str) -> Command {
    let mut command = Command::new(java_home.join("bin/java"));
    command
        .current_dir(&launch.working_dir)
        .args(&launch.jvm_args)
        .arg(format!("-Dirisrun.qualifiers={qualifiers}"))
        .arg("-cp")
        .arg(&launch.classpath)
        .arg("dev.irisrun.android.host.HostMain");
    command
}

/// The init script writes one `<module>.launch` per application module; pick
/// `app`, the usual name, or the only one.
fn app_launch_file(out: &Path) -> Result<PathBuf> {
    let mut modules = Vec::new();
    for entry in std::fs::read_dir(out)? {
        let path = entry?.path();
        if path.extension().is_some_and(|ext| ext == "classpath") {
            modules.push(path);
        }
    }
    if let Some(app) = modules
        .iter()
        .find(|path| path.file_stem().is_some_and(|stem| stem == "app"))
    {
        return Ok(app.clone());
    }
    match modules.as_slice() {
        [only] => Ok(only.clone()),
        [] => bail!("the project has no Android application module"),
        _ => bail!("the project has several application modules; irisrun runs `app` for now"),
    }
}
