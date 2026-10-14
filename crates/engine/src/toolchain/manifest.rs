//! The toolchain builds irisrun downloads, pinned by URL and SHA-256.
//!
//! Change a version by updating its URLs and hashes together. Temurin
//! publishes its hashes at https://api.adoptium.net/v3/assets/latest/21/hotspot;
//! for Swift, compute them with `curl -fsSL <url> | sha256sum`.

use super::host::{Arch, Host, Os};

pub(crate) struct Artifact {
    pub url: &'static str,
    pub sha256: &'static str,
}

/// Eclipse Temurin, which runs Gradle and the Android runtime.
pub(crate) const JDK_VERSION: &str = "21.0.12.1+1";

const JDK: [(Os, Arch, Artifact); 4] = [
    (
        Os::Linux,
        Arch::X86_64,
        Artifact {
            url: "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_x64_linux_hotspot_21.0.12.1_1.tar.gz",
            sha256: "ce79869e1307ed8ee1e2baa86a412b1eb5b75d10a01006d788a6f968bcfaee94",
        },
    ),
    (
        Os::Linux,
        Arch::Aarch64,
        Artifact {
            url: "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_aarch64_linux_hotspot_21.0.12.1_1.tar.gz",
            sha256: "23e37e026f12f3e706f18938ff611db3032d075b09d0879a25d06718c773e223",
        },
    ),
    (
        Os::MacOs,
        Arch::X86_64,
        Artifact {
            url: "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_x64_mac_hotspot_21.0.12.1_1.tar.gz",
            sha256: "44db0f08196daf19a47f90d13388b0c943b67663cb537f998fe29e836fa842ce",
        },
    ),
    (
        Os::MacOs,
        Arch::Aarch64,
        Artifact {
            url: "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_aarch64_mac_hotspot_21.0.12.1_1.tar.gz",
            sha256: "3623232f33a9c3baadf304480b2535f9a3cba8a58d42ecbb438ba267315d9998",
        },
    ),
];

/// Swift from swift.org, which builds iOS apps against OpenKit. Linux builds
/// are per distribution; only those listed here are supported so far.
pub(crate) const SWIFT_VERSION: &str = "6.4.1";

/// Supported Linux distributions, as (os-release ID, VERSION_ID).
pub(crate) const SWIFT_DISTROS: [(&str, &str); 2] = [("ubuntu", "22.04"), ("ubuntu", "24.04")];

const SWIFT_LINUX: [(Arch, (&str, &str), Artifact); 4] = [
    (
        Arch::X86_64,
        SWIFT_DISTROS[0],
        Artifact {
            url: "https://download.swift.org/swift-6.4.1-release/ubuntu2204/swift-6.4.1-RELEASE/swift-6.4.1-RELEASE-ubuntu22.04.tar.gz",
            sha256: "e9ec2ff05ac0fc89bf2e7cecdee5da4d398898a768d7ee2b86a59d2a7f01c44b",
        },
    ),
    (
        Arch::X86_64,
        SWIFT_DISTROS[1],
        Artifact {
            url: "https://download.swift.org/swift-6.4.1-release/ubuntu2404/swift-6.4.1-RELEASE/swift-6.4.1-RELEASE-ubuntu24.04.tar.gz",
            sha256: "7d246c7114077ad01dba4ad897628446ada4c489d6c7dbcf39ae3f25cbe17e8b",
        },
    ),
    (
        Arch::Aarch64,
        SWIFT_DISTROS[0],
        Artifact {
            url: "https://download.swift.org/swift-6.4.1-release/ubuntu2204-aarch64/swift-6.4.1-RELEASE/swift-6.4.1-RELEASE-ubuntu22.04-aarch64.tar.gz",
            sha256: "5d50538c0500ff1b253e799f3e48f04db0547856aef76905c85e5bdfe01e6901",
        },
    ),
    (
        Arch::Aarch64,
        SWIFT_DISTROS[1],
        Artifact {
            url: "https://download.swift.org/swift-6.4.1-release/ubuntu2404-aarch64/swift-6.4.1-RELEASE/swift-6.4.1-RELEASE-ubuntu24.04-aarch64.tar.gz",
            sha256: "b85dd70e204bc363ce62f1e35bd1887810d0e04487d13de8fd9d042635972f45",
        },
    ),
];

/// A universal installer package for Intel and Apple silicon Macs.
const SWIFT_MACOS: Artifact = Artifact {
    url: "https://download.swift.org/swift-6.4.1-release/xcode/swift-6.4.1-RELEASE/swift-6.4.1-RELEASE-osx.pkg",
    sha256: "c34e7e5fb0be4bcd61decfd40db1766434d8952d68e37aed90bcff4e8547951c",
};

pub(crate) fn jdk(host: &Host) -> Option<&'static Artifact> {
    JDK.iter()
        .find(|(os, arch, _)| *os == host.os && *arch == host.arch)
        .map(|(_, _, artifact)| artifact)
}

pub(crate) fn swift(host: &Host) -> Option<&'static Artifact> {
    match host.os {
        Os::MacOs => Some(&SWIFT_MACOS),
        Os::Linux => {
            let distro = host.distro.as_ref()?;
            SWIFT_LINUX
                .iter()
                .find(|(arch, (id, version), _)| {
                    *arch == host.arch && *id == distro.id && *version == distro.version_id
                })
                .map(|(_, _, artifact)| artifact)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::super::host::Distro;
    use super::*;

    fn linux(arch: Arch, id: &str, version_id: &str) -> Host {
        Host {
            os: Os::Linux,
            arch,
            distro: Some(Distro {
                id: id.into(),
                version_id: version_id.into(),
            }),
        }
    }

    #[test]
    fn picks_the_swift_build_for_the_distribution() {
        let artifact = swift(&linux(Arch::Aarch64, "ubuntu", "24.04")).unwrap();
        assert!(artifact.url.ends_with("ubuntu24.04-aarch64.tar.gz"));

        assert!(swift(&linux(Arch::X86_64, "ubuntu", "20.04")).is_none());
    }

    #[test]
    fn every_hash_is_a_sha256() {
        let artifacts = JDK.iter().map(|(_, _, a)| a);
        let artifacts = artifacts.chain(SWIFT_LINUX.iter().map(|(_, _, a)| a));
        for artifact in artifacts.chain([&SWIFT_MACOS]) {
            assert!(
                artifact.sha256.len() == 64
                    && artifact.sha256.bytes().all(|b| b.is_ascii_hexdigit()),
                "bad sha256 for {}",
                artifact.url
            );
        }
    }
}
