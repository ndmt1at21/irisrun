//! Downloads the toolchains builds need into `~/.irisrun/toolchains`, so
//! developers never install a JDK or Swift themselves.
//!
//! Each install downloads a pinned archive, checks its SHA-256, unpacks it
//! next to its final place and renames it there, so an interrupted install
//! never leaves a half-unpacked toolchain behind.

mod host;
mod manifest;

pub use host::{Arch, Distro, Host, Os};

use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};

use anyhow::{Context, Result, anyhow, ensure};
use manifest::Artifact;
use sha2::{Digest, Sha256};
use tokio::io::{AsyncWriteExt, BufWriter};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Tool {
    Jdk,
    Swift,
}

impl Tool {
    pub const ALL: [Tool; 2] = [Tool::Jdk, Tool::Swift];

    pub fn name(self) -> &'static str {
        match self {
            Tool::Jdk => "jdk",
            Tool::Swift => "swift",
        }
    }

    pub fn version(self) -> &'static str {
        match self {
            Tool::Jdk => manifest::JDK_VERSION,
            Tool::Swift => manifest::SWIFT_VERSION,
        }
    }
}

/// What an install is busy with, for progress bars.
pub enum Progress {
    Downloading { done: u64, total: Option<u64> },
    Unpacking,
}

pub struct Installed {
    pub path: PathBuf,
    pub downloaded_bytes: u64,
    pub elapsed: Duration,
}

pub struct Toolchains {
    root: PathBuf,
    host: Host,
}

impl Toolchains {
    pub fn new(irisrun_home: &Path, host: Host) -> Toolchains {
        Toolchains {
            root: irisrun_home.join("toolchains"),
            host,
        }
    }

    /// Where `tool` is installed, or will be.
    pub fn path(&self, tool: Tool) -> PathBuf {
        self.root
            .join(format!("{}-{}", tool.name(), tool.version()))
    }

    pub fn is_installed(&self, tool: Tool) -> bool {
        self.path(tool).is_dir()
    }

    /// `JAVA_HOME` for the installed JDK.
    pub fn java_home(&self) -> PathBuf {
        let jdk = self.path(Tool::Jdk);
        match self.host.os {
            Os::MacOs => jdk.join("Contents/Home"),
            Os::Linux => jdk,
        }
    }

    /// The directory holding `swift` and `swiftc`.
    pub fn swift_bin(&self) -> PathBuf {
        self.path(Tool::Swift).join("usr/bin")
    }

    pub async fn install(
        &self,
        tool: Tool,
        mut progress: impl FnMut(Progress),
    ) -> Result<Installed> {
        let artifact = self.artifact(tool)?;
        let started = Instant::now();
        let dest = self.path(tool);
        tokio::fs::create_dir_all(&self.root).await?;

        // Work files sit beside `dest` so the final rename stays on one filesystem.
        let work = |kind: &str| {
            let name = dest.file_name().unwrap_or_default().to_string_lossy();
            self.root
                .join(format!(".{name}.{}.{kind}", std::process::id()))
        };
        let (archive, staging) = (work("download"), work("unpack"));
        let result = async {
            let downloaded_bytes = download(artifact, &archive, &mut progress).await?;
            progress(Progress::Unpacking);
            let (archive, staging, dest) = (archive.clone(), staging.clone(), dest.clone());
            tokio::task::spawn_blocking(move || unpack(&archive, &staging, &dest)).await??;
            anyhow::Ok(downloaded_bytes)
        }
        .await;
        let _ = tokio::fs::remove_file(&archive).await;
        let _ = tokio::fs::remove_dir_all(&staging).await;

        Ok(Installed {
            downloaded_bytes: result?,
            path: dest,
            elapsed: started.elapsed(),
        })
    }

    fn artifact(&self, tool: Tool) -> Result<&'static Artifact> {
        let artifact = match tool {
            Tool::Jdk => manifest::jdk(&self.host),
            Tool::Swift => manifest::swift(&self.host),
        };
        artifact.ok_or_else(|| match (tool, &self.host.distro) {
            (Tool::Swift, Some(distro)) => {
                let supported: Vec<_> = manifest::SWIFT_DISTROS
                    .iter()
                    .map(|(id, version)| format!("{id} {version}"))
                    .collect();
                anyhow!(
                    "Swift {} has no build for {distro} here; irisrun supports macOS and {} on Linux",
                    tool.version(),
                    supported.join(", ")
                )
            }
            _ => anyhow!("no {} build for {:?} {:?}", tool.name(), self.host.os, self.host.arch),
        })
    }
}

/// How many times a download starts over, resuming where the connection dropped.
const DOWNLOAD_ATTEMPTS: u32 = 5;

/// Downloads `artifact` to `to`, checking its hash, and returns its size.
async fn download(
    artifact: &Artifact,
    to: &Path,
    progress: &mut impl FnMut(Progress),
) -> Result<u64> {
    let client = crate::http_client()?;
    let mut file = BufWriter::with_capacity(1 << 20, tokio::fs::File::create(to).await?);
    let mut hasher = Sha256::new();
    let mut done = 0;
    for attempt in 1.. {
        let result = async {
            let mut request = client.get(artifact.url);
            if done > 0 {
                request = request.header(reqwest::header::RANGE, format!("bytes={done}-"));
            }
            let mut response = request.send().await?.error_for_status()?;
            ensure!(
                done == 0 || response.status() == reqwest::StatusCode::PARTIAL_CONTENT,
                "the server cannot resume the download"
            );
            let total = response.content_length().map(|rest| done + rest);
            while let Some(chunk) = response.chunk().await? {
                hasher.update(&chunk);
                file.write_all(&chunk).await?;
                done += chunk.len() as u64;
                progress(Progress::Downloading { done, total });
            }
            anyhow::Ok(())
        }
        .await;
        match result {
            Ok(()) => break,
            Err(error) if attempt < DOWNLOAD_ATTEMPTS && is_transient(&error) => {
                tokio::time::sleep(Duration::from_secs(1 << attempt)).await;
            }
            Err(error) => return Err(error.context(format!("cannot download {}", artifact.url))),
        }
    }
    file.flush().await?;

    let actual = hex(&hasher.finalize());
    ensure!(
        actual == artifact.sha256,
        "{} has SHA-256 {actual}, expected {}; the download is corrupt or was tampered with",
        artifact.url,
        artifact.sha256
    );
    Ok(done)
}

/// Dropped connections and server errors are worth retrying; a 404 is not.
fn is_transient(error: &anyhow::Error) -> bool {
    error
        .downcast_ref::<reqwest::Error>()
        .is_some_and(|error| error.status().is_none_or(|status| status.is_server_error()))
}

/// Unpacks `archive` inside `staging`, then moves the toolchain to `dest`.
fn unpack(archive: &Path, staging: &Path, dest: &Path) -> Result<()> {
    std::fs::create_dir_all(staging)?;
    let root = if archive_is_pkg(archive)? {
        unpack_pkg(archive, staging)?
    } else {
        unpack_tar_gz(archive, staging)?
    };
    match std::fs::rename(&root, dest) {
        // Another irisrun finished the same install first.
        Err(_) if dest.is_dir() => Ok(()),
        result => {
            result.with_context(|| format!("cannot move the toolchain to {}", dest.display()))
        }
    }
}

/// macOS installer packages are xar archives, which start with "xar!".
fn archive_is_pkg(archive: &Path) -> Result<bool> {
    use std::io::Read;
    let mut magic = [0; 4];
    std::fs::File::open(archive)?.read_exact(&mut magic)?;
    Ok(&magic == b"xar!")
}

/// Unpacks a `.tar.gz` holding one top-level directory and returns that
/// directory.
fn unpack_tar_gz(archive: &Path, into: &Path) -> Result<PathBuf> {
    let file = std::io::BufReader::new(std::fs::File::open(archive)?);
    tar::Archive::new(flate2::read::GzDecoder::new(file))
        .unpack(into)
        .with_context(|| format!("cannot unpack {}", archive.display()))?;

    let mut entries = std::fs::read_dir(into)?.collect::<std::io::Result<Vec<_>>>()?;
    ensure!(
        entries.len() == 1 && entries[0].file_type()?.is_dir(),
        "{} should hold a single top-level directory",
        archive.display()
    );
    Ok(entries.remove(0).path())
}

/// Unpacks an installer package without installing it, using `pkgutil`
/// (part of macOS), and returns its payload: the `usr/` tree.
fn unpack_pkg(archive: &Path, into: &Path) -> Result<PathBuf> {
    let expanded = into.join("expanded");
    let status = std::process::Command::new("pkgutil")
        .arg("--expand-full")
        .arg(archive)
        .arg(&expanded)
        .status()
        .context("cannot run pkgutil")?;
    ensure!(
        status.success(),
        "pkgutil cannot unpack {}",
        archive.display()
    );

    for entry in std::fs::read_dir(&expanded)? {
        let payload = entry?.path().join("Payload");
        if payload.join("usr").is_dir() {
            return Ok(payload);
        }
    }
    Err(anyhow!("{} has no toolchain payload", archive.display()))
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unpacks_the_top_level_directory_into_place() {
        let tmp = tempfile::tempdir().unwrap();
        let archive = tmp.path().join("jdk.tar.gz");
        let gz = flate2::write::GzEncoder::new(
            std::fs::File::create(&archive).unwrap(),
            flate2::Compression::fast(),
        );
        let mut tar = tar::Builder::new(gz);
        let mut header = tar::Header::new_gnu();
        header.set_size(4);
        header.set_mode(0o755);
        tar.append_data(&mut header, "jdk-21/bin/java", &b"java"[..])
            .unwrap();
        tar.into_inner().unwrap().finish().unwrap();

        let dest = tmp.path().join("toolchains/jdk");
        std::fs::create_dir(tmp.path().join("toolchains")).unwrap();
        unpack(&archive, &tmp.path().join("staging"), &dest).unwrap();

        assert_eq!(std::fs::read(dest.join("bin/java")).unwrap(), b"java");
    }
}
