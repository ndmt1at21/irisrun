//! Binary Doctor: finds the native binaries an Android or iOS project ships
//! and picks the first workable way to run each one, locally or in the cloud.
//!
//! The strategies follow the ordered lists in the plan's "Binary native"
//! section. For Android, rebuilding from NDK source comes first, but a binary
//! cannot tell whether its source is in the project, so callers offer it.

mod object;
mod scan;

use std::fmt;
use std::path::PathBuf;

pub use scan::scan;

/// What a scan found.
pub struct Report {
    pub binaries: Vec<Binary>,
    /// Files that look like binaries or containers but cannot be read.
    pub warnings: Vec<String>,
}

/// An ELF or Mach-O file, a fat file or a static archive.
#[derive(Debug, Default)]
pub struct Binary {
    /// Paths inside containers continue the container's path, such as
    /// `sdk.aar/jni/x86_64/libfoo.so`.
    pub path: PathBuf,
    /// What the file is, such as "ELF shared library".
    pub format: String,
    /// One per CPU architecture and platform; fat files have several.
    pub slices: Vec<Slice>,
    /// Libraries loaded at run time: `DT_NEEDED`, or `LC_LOAD_DYLIB` and kin.
    pub needed: Vec<String>,
    /// Exported JNI entry points: `JNI_OnLoad` and `Java_*` functions.
    pub jni_exports: Vec<String>,
    /// Holds Swift code (`__swift5_*` sections).
    pub swift: bool,
    /// Its framework or library directory ships a `.swiftinterface`.
    pub swiftinterface: bool,
    /// Its framework or library directory ships C or Objective-C headers.
    pub headers: bool,
    /// Android: the same library also ships for x86_64.
    pub x86_64_build: bool,
    /// iOS: an arm64 iOS-simulator build ships with it, in the same fat file
    /// or the same xcframework.
    pub arm64_simulator: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Slice {
    /// Android ABI names for ELF (`arm64-v8a`, `x86_64`…), Apple names for
    /// Mach-O (`arm64`, `x86_64`…).
    pub arch: &'static str,
    pub platform: Platform,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Platform {
    /// Bionic, with the minimum API level from `.note.android.ident`. Any ELF
    /// that does not link glibc counts as Android: the doctor scans mobile
    /// projects.
    Android {
        min_api: Option<u32>,
    },
    /// Desktop Linux (glibc), such as JNI libraries inside desktop JVM jars.
    Linux,
    Ios {
        simulator: bool,
        min_os: String,
    },
    /// macOS, Mac Catalyst, tvOS, watchOS, visionOS and their simulators.
    OtherApple {
        name: &'static str,
        min_os: String,
    },
    /// A Mach-O without a platform load command.
    UnknownApple,
}

/// How a binary can run, in the plan's order of preference.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Strategy {
    /// Android 2: load the x86_64 build through a bionic-to-glibc loader.
    BionicLoader,
    /// Android 3: only other CPUs, so run the whole runtime under CPU
    /// translation (FEX, box64, QEMU-user), or on the cloud emulator.
    CpuTranslation,
    /// Android 4: needs GPU, media or camera libraries that hosts lack, so
    /// stub its JNI functions, or use the cloud emulator.
    JniStub,
    /// iOS 1: a stub module generated from the vendor's `.swiftinterface`,
    /// plus compat registry adapters.
    SwiftStub,
    /// iOS 2: stubs generated from the vendor's Objective-C or C headers.
    HeaderStub,
    /// iOS 3: the cloud simulator.
    CloudSimulator,
    /// Built for a platform that Android and iOS apps never load, such as
    /// macOS or desktop Linux.
    Unused,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Tier {
    Local,
    Cloud,
}

/// NDK libraries backed by GPU, media, camera or audio hardware, which a
/// host-side loader cannot provide.
const HARDWARE_LIBRARIES: [&str; 13] = [
    "libEGL.so",
    "libGLESv1_CM.so",
    "libGLESv2.so",
    "libGLESv3.so",
    "libvulkan.so",
    "libnativewindow.so",
    "libmediandk.so",
    "libcamera2ndk.so",
    "libaaudio.so",
    "libOpenSLES.so",
    "libOpenMAXAL.so",
    "libneuralnetworks.so",
    "libamidi.so",
];

impl Binary {
    /// The first workable strategy from the plan's list for its platform.
    pub fn strategy(&self) -> Strategy {
        let platforms = || self.slices.iter().map(|slice| &slice.platform);
        if platforms().any(|platform| matches!(platform, Platform::Android { .. })) {
            if self
                .needed
                .iter()
                .any(|lib| HARDWARE_LIBRARIES.contains(&lib.as_str()))
            {
                Strategy::JniStub
            } else if self.x86_64_build {
                Strategy::BionicLoader
            } else {
                Strategy::CpuTranslation
            }
        } else if platforms()
            .any(|platform| matches!(platform, Platform::Ios { .. } | Platform::UnknownApple))
        {
            if self.swiftinterface {
                Strategy::SwiftStub
            } else if !self.swift && self.headers {
                Strategy::HeaderStub
            } else {
                Strategy::CloudSimulator
            }
        } else {
            Strategy::Unused
        }
    }
}

impl Strategy {
    /// Where the app runs with this binary; `None` for unused binaries.
    pub fn tier(self) -> Option<Tier> {
        match self {
            Strategy::BionicLoader
            | Strategy::JniStub
            | Strategy::SwiftStub
            | Strategy::HeaderStub => Some(Tier::Local),
            // Translating the whole runtime is slow, so suggest the cloud.
            Strategy::CpuTranslation | Strategy::CloudSimulator => Some(Tier::Cloud),
            Strategy::Unused => None,
        }
    }
}

impl fmt::Display for Platform {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Platform::Android { min_api: Some(api) } => write!(f, "Android API {api}"),
            Platform::Android { min_api: None } => f.write_str("Android"),
            Platform::Linux => f.write_str("Linux (glibc)"),
            Platform::Ios {
                simulator: false,
                min_os,
            } => write!(f, "iOS {min_os}"),
            Platform::Ios {
                simulator: true,
                min_os,
            } => write!(f, "iOS simulator {min_os}"),
            Platform::OtherApple { name, min_os } => write!(f, "{name} {min_os}"),
            Platform::UnknownApple => f.write_str("unknown Apple platform"),
        }
    }
}

impl fmt::Display for Strategy {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(match self {
            Strategy::BionicLoader => "load the x86_64 build through the bionic-to-glibc loader",
            Strategy::CpuTranslation => {
                "no x86_64 build: the cloud emulator, or CPU translation (FEX, box64, QEMU-user)"
            }
            Strategy::JniStub => {
                "needs GPU, media or camera libraries: a JNI stub without real behavior, or the cloud emulator"
            }
            Strategy::SwiftStub => {
                "a stub module from the vendor's .swiftinterface, plus compat registry adapters"
            }
            Strategy::HeaderStub => "stubs from the vendor's Objective-C/C headers",
            Strategy::CloudSimulator => "the cloud simulator",
            Strategy::Unused => "not loaded by Android or iOS apps",
        })
    }
}

impl fmt::Display for Tier {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(match self {
            Tier::Local => "local",
            Tier::Cloud => "cloud",
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strategies_follow_the_plan_order() {
        let android = |needed: &str, x86_64_build| Binary {
            slices: vec![Slice {
                arch: "arm64-v8a",
                platform: Platform::Android { min_api: Some(21) },
            }],
            needed: vec![needed.to_owned()],
            x86_64_build,
            ..Binary::default()
        };
        assert_eq!(
            android("liblog.so", true).strategy(),
            Strategy::BionicLoader
        );
        assert_eq!(
            android("liblog.so", false).strategy(),
            Strategy::CpuTranslation
        );
        assert_eq!(android("libGLESv3.so", true).strategy(), Strategy::JniStub);

        let ios = |swift, swiftinterface, headers| Binary {
            slices: vec![Slice {
                arch: "arm64",
                platform: Platform::Ios {
                    simulator: false,
                    min_os: "15.5".to_owned(),
                },
            }],
            swift,
            swiftinterface,
            headers,
            ..Binary::default()
        };
        assert_eq!(ios(true, true, true).strategy(), Strategy::SwiftStub);
        assert_eq!(ios(false, false, true).strategy(), Strategy::HeaderStub);
        assert_eq!(ios(true, false, true).strategy(), Strategy::CloudSimulator);
        assert_eq!(
            ios(false, false, false).strategy(),
            Strategy::CloudSimulator
        );

        let macos = Binary {
            slices: vec![Slice {
                arch: "arm64",
                platform: Platform::OtherApple {
                    name: "macOS",
                    min_os: "11.0".to_owned(),
                },
            }],
            swiftinterface: true,
            ..Binary::default()
        };
        assert_eq!(macos.strategy(), Strategy::Unused);
    }
}
