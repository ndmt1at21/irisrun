//! The machine irisrun runs on, as far as picking a toolchain build goes.

use std::fmt;

use anyhow::{Result, bail};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Os {
    Linux,
    MacOs,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Arch {
    X86_64,
    Aarch64,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Host {
    pub os: Os,
    pub arch: Arch,
    /// Read from os-release on Linux; Swift ships one build per distribution.
    pub distro: Option<Distro>,
}

/// A Linux distribution, by its os-release `ID` and `VERSION_ID`, such as
/// `ubuntu` and `24.04`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Distro {
    pub id: String,
    pub version_id: String,
}

impl Host {
    pub fn detect() -> Result<Host> {
        let os = match std::env::consts::OS {
            "linux" => Os::Linux,
            "macos" => Os::MacOs,
            other => bail!("irisrun does not run on {other}; use macOS, Linux or WSL2"),
        };
        let arch = match std::env::consts::ARCH {
            "x86_64" => Arch::X86_64,
            "aarch64" => Arch::Aarch64,
            other => bail!("irisrun does not run on {other} CPUs"),
        };
        let distro = match os {
            Os::Linux => ["/etc/os-release", "/usr/lib/os-release"]
                .iter()
                .find_map(|path| std::fs::read_to_string(path).ok())
                .and_then(|text| Distro::from_os_release(&text)),
            Os::MacOs => None,
        };
        Ok(Host { os, arch, distro })
    }
}

impl Distro {
    fn from_os_release(text: &str) -> Option<Distro> {
        let field = |key: &str| {
            text.lines()
                .find_map(|line| line.strip_prefix(key)?.strip_prefix('='))
                .map(|value| value.trim().trim_matches('"').to_owned())
        };
        Some(Distro {
            id: field("ID")?,
            version_id: field("VERSION_ID")?,
        })
    }
}

impl fmt::Display for Distro {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{} {}", self.id, self.version_id)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_id_and_version_from_os_release() {
        let text = "NAME=\"Ubuntu\"\nVERSION_ID=\"24.04\"\nVERSION=\"24.04.5 LTS\"\nID=ubuntu\nID_LIKE=debian\n";

        assert_eq!(
            Distro::from_os_release(text),
            Some(Distro {
                id: "ubuntu".into(),
                version_id: "24.04".into()
            })
        );
    }
}
