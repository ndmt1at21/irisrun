//! iOS: builds an app's Xcode project against OpenKit (the patched
//! OpenSwiftUI in runtimes/ios) and runs it as a device that speaks the
//! Device Protocol on stdio.

use std::ffi::OsString;
use std::path::{Path, PathBuf};
use std::process::Stdio;

use anyhow::{Context, Result, bail, ensure};
use tokio::process::Command;

pub struct IosProject {
    root: PathBuf,
}

impl IosProject {
    /// Opens the directory of an Xcode project, if `dir` is one.
    pub fn open(dir: &Path) -> Result<Option<IosProject>> {
        let has_xcode_project = std::fs::read_dir(dir)
            .with_context(|| format!("cannot open {}", dir.display()))?
            .flatten()
            .any(|entry| {
                entry
                    .path()
                    .extension()
                    .is_some_and(|ext| ext == "xcodeproj")
            });
        if !has_xcode_project {
            return Ok(None);
        }
        Ok(Some(IosProject {
            root: dir.canonicalize()?,
        }))
    }

    /// Builds the app's iOS target with runtimes/ios/Scripts/compile-app.sh
    /// and returns the executable.
    pub async fn build(&self, swift: &SwiftRunner) -> Result<PathBuf> {
        let script = runtime_dir().join("Scripts/compile-app.sh");
        ensure!(
            script.is_file(),
            "{} is missing; set IRISRUN_IOS_RUNTIME to Iris's runtimes/ios",
            script.display()
        );
        let output = swift
            .command(script)
            .arg(&self.root)
            .stderr(Stdio::inherit())
            .output()
            .await
            .context("cannot run the iOS build")?;
        if !output.status.success() {
            bail!("the iOS build failed ({})", output.status);
        }
        // The script prints the executable last; an app without an entry
        // point prints its module name instead.
        let stdout = String::from_utf8(output.stdout)?;
        let executable = PathBuf::from(stdout.lines().last().unwrap_or_default());
        ensure!(
            executable.is_absolute(),
            "the app has no entry point (@main or main.swift) to run"
        );
        Ok(executable)
    }
}

/// How to run Swift 6.4.1 and what it built. On hosts it does not run on,
/// such as Ubuntu 20.04, IRISRUN_SWIFT_RUNNER names a wrapper that runs a
/// command where it does, for example a `docker run` script.
pub struct SwiftRunner {
    wrapper: Option<OsString>,
}

impl SwiftRunner {
    pub fn from_env() -> SwiftRunner {
        SwiftRunner {
            wrapper: std::env::var_os("IRISRUN_SWIFT_RUNNER").filter(|value| !value.is_empty()),
        }
    }

    fn command(&self, program: impl Into<OsString>) -> Command {
        match &self.wrapper {
            Some(wrapper) => {
                let mut command = Command::new(wrapper);
                command.arg(program.into());
                command
            }
            None => Command::new(program.into()),
        }
    }
}

/// The command that runs the app as a device: Device Protocol envelopes on
/// stdin and stdout, the app's own output on stderr.
pub fn host_command(swift: &SwiftRunner, executable: &Path) -> Command {
    // Through env(1), as wrappers such as `docker run` may not pass on the
    // environment.
    let mut command = swift.command("env");
    command.arg("IRISRUN_DEVICE=stdio").arg(executable);
    command
}

/// Iris's runtimes/ios: `$IRISRUN_IOS_RUNTIME`, or the checkout this binary
/// was built from.
fn runtime_dir() -> PathBuf {
    std::env::var_os("IRISRUN_IOS_RUNTIME").map_or_else(
        || Path::new(env!("CARGO_MANIFEST_DIR")).join("../../runtimes/ios"),
        PathBuf::from,
    )
}
