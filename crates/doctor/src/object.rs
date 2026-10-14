//! Reads one binary with goblin: its slices, the libraries it loads, and its
//! JNI and Swift symbols.

use std::path::PathBuf;

use anyhow::Result;
use goblin::elf::Elf;
use goblin::elf::header::{
    EM_386, EM_AARCH64, EM_ARM, EM_RISCV, EM_X86_64, ET_DYN, ET_EXEC, ET_REL,
};
use goblin::elf::section_header::SHN_UNDEF;
use goblin::mach::cputype::{
    CPU_SUBTYPE_MASK, CPU_TYPE_X86, CPU_TYPE_X86_64, get_arch_name_from_types,
};
use goblin::mach::header::{MH_BUNDLE, MH_DYLIB, MH_EXECUTE, MH_OBJECT};
use goblin::mach::load_command::{
    CommandVariant, PLATFORM_BRIDGEOS, PLATFORM_DRIVERKIT, PLATFORM_IOS, PLATFORM_IOSSIMULATOR,
    PLATFORM_MACCATALYST, PLATFORM_MACOS, PLATFORM_TVOS, PLATFORM_TVOSSIMULATOR, PLATFORM_VISIONOS,
    PLATFORM_VISIONOSSIMULATOR, PLATFORM_WATCHOS, PLATFORM_WATCHOSSIMULATOR,
};
use goblin::mach::{Mach, MachO};
use goblin::{Hint, Object};

use crate::{Binary, Platform, Slice};

/// Whether `bytes` start an ELF, Mach-O, fat or `ar` file.
pub(crate) fn is_binary(bytes: &[u8]) -> bool {
    let Some(head) = bytes.first_chunk::<16>() else {
        return false;
    };
    match goblin::peek_bytes(head) {
        Ok(Hint::Elf(_) | Hint::Mach(_) | Hint::Archive) => true,
        // Java class files share the fat magic, with their version number
        // where a fat file counts its architectures.
        Ok(Hint::MachFat(arches)) => arches < 20,
        _ => false,
    }
}

/// Reads the binary in `bytes`, or returns `None` when it holds no code,
/// like dSYM companions or archives without objects.
pub(crate) fn read(path: PathBuf, bytes: &[u8]) -> Result<Option<Binary>> {
    let mut binary = Binary {
        path,
        ..Binary::default()
    };
    Ok(binary.add(bytes)?.map(|format| Binary { format, ..binary }))
}

impl Binary {
    /// Adds what `bytes` holds and describes it, or returns `None` when it
    /// holds no code.
    fn add(&mut self, bytes: &[u8]) -> Result<Option<String>> {
        let format = match Object::parse(bytes)? {
            Object::Elf(elf) => {
                self.add_elf(&elf, bytes);
                format!("ELF {}", elf_kind(&elf))
            }
            Object::Mach(Mach::Binary(macho)) => match self.add_macho(&macho) {
                Some(kind) => format!("Mach-O {kind}"),
                None => return Ok(None),
            },
            Object::Mach(Mach::Fat(fat)) => {
                let mut first = None;
                for arch in fat.iter_arches() {
                    let format = self.add(arch?.slice(bytes))?;
                    first = first.or(format);
                }
                match first {
                    Some(format) => format!("universal {format}"),
                    None => return Ok(None),
                }
            }
            Object::Archive(archive) => {
                let (mut objects, mut first) = (0, None);
                for member in (0..archive.len()).filter_map(|index| archive.get_at(index)) {
                    let data = bytes
                        .get(member.offset as usize..)
                        .and_then(|rest| rest.get(..member.size()));
                    // Skips symbol tables, bitcode and other non-object members.
                    let Some(data) = data.filter(|data| is_binary(data)) else {
                        continue;
                    };
                    if let Some(format) = self.add(data)? {
                        objects += 1;
                        first.get_or_insert(format);
                    }
                }
                match first {
                    Some(format) => format!("static library of {objects} {format}s"),
                    None => return Ok(None),
                }
            }
            _ => return Ok(None),
        };
        Ok(Some(format))
    }

    fn add_elf(&mut self, elf: &Elf, bytes: &[u8]) {
        let arch = match elf.header.e_machine {
            EM_AARCH64 => "arm64-v8a",
            EM_ARM => "armeabi-v7a",
            EM_386 => "x86",
            EM_X86_64 => "x86_64",
            EM_RISCV => "riscv64",
            other => goblin::elf::header::machine_to_str(other),
        };
        // Bionic's libc is plain `libc.so`; glibc's is `libc.so.6`.
        let glibc = elf.libraries.iter().any(|lib| lib.starts_with("libc.so."))
            || elf
                .interpreter
                .is_some_and(|path| !path.starts_with("/system/bin/linker"));
        let platform = match glibc {
            true => Platform::Linux,
            false => Platform::Android {
                min_api: android_api(elf, bytes),
            },
        };
        self.add_slice(Slice { arch, platform });
        for lib in &elf.libraries {
            self.add_needed(lib);
        }
        let exports = elf
            .dynsyms
            .iter()
            .filter(|sym| sym.st_shndx != SHN_UNDEF as usize)
            .filter_map(|sym| elf.dynstrtab.get_at(sym.st_name));
        self.jni_exports.extend(
            exports
                .filter(|name| *name == "JNI_OnLoad" || name.starts_with("Java_"))
                .map(str::to_owned),
        );
    }

    fn add_macho(&mut self, macho: &MachO) -> Option<&'static str> {
        let kind = match macho.header.filetype {
            MH_OBJECT => "object",
            MH_EXECUTE => "executable",
            MH_DYLIB => "dynamic library",
            MH_BUNDLE => "bundle",
            // dSYM companions and the like hold no code that runs.
            _ => return None,
        };
        let (cputype, cpusubtype) = (macho.header.cputype, macho.header.cpusubtype);
        let arch =
            get_arch_name_from_types(cputype, cpusubtype & !CPU_SUBTYPE_MASK).unwrap_or("unknown");
        let x86 = matches!(cputype, CPU_TYPE_X86 | CPU_TYPE_X86_64);
        let platform = macho
            .load_commands
            .iter()
            .find_map(|command| apple_platform(&command.command, x86))
            .unwrap_or(Platform::UnknownApple);
        self.add_slice(Slice { arch, platform });
        // The first entry is the library's own install name.
        for lib in macho.libs.iter().skip(1) {
            self.add_needed(lib);
        }
        self.swift |= macho
            .segments
            .sections()
            .flatten()
            .flatten()
            .any(|(section, _)| {
                section
                    .name()
                    .is_ok_and(|name| name.starts_with("__swift5"))
            });
        Some(kind)
    }

    fn add_slice(&mut self, slice: Slice) {
        if !self.slices.contains(&slice) {
            self.slices.push(slice);
        }
    }

    fn add_needed(&mut self, lib: &str) {
        if !self.needed.iter().any(|needed| needed == lib) {
            self.needed.push(lib.to_owned());
        }
    }
}

fn elf_kind(elf: &Elf) -> &'static str {
    match elf.header.e_type {
        ET_REL => "object",
        ET_DYN if elf.interpreter.is_none() => "shared library",
        ET_DYN | ET_EXEC => "executable",
        _ => "file",
    }
}

/// The minimum API level that the NDK records in `.note.android.ident`.
fn android_api(elf: &Elf, bytes: &[u8]) -> Option<u32> {
    let note = elf
        .iter_note_headers(bytes)?
        .flatten()
        .find(|note| note.name == "Android" && note.n_type == 1)?;
    Some(u32::from_le_bytes(*note.desc.first_chunk()?))
}

/// The platform in `LC_BUILD_VERSION` or the older `LC_VERSION_MIN_*`, which
/// name no simulator: x86 builds for iOS, tvOS and watchOS were simulator
/// builds.
fn apple_platform(command: &CommandVariant, x86: bool) -> Option<Platform> {
    let pick = |device, simulator| if x86 { simulator } else { device };
    let (platform, version) = match command {
        CommandVariant::BuildVersion(build) => (build.platform, build.minos),
        CommandVariant::VersionMinIphoneos(min) => {
            (pick(PLATFORM_IOS, PLATFORM_IOSSIMULATOR), min.version)
        }
        CommandVariant::VersionMinTvos(min) => {
            (pick(PLATFORM_TVOS, PLATFORM_TVOSSIMULATOR), min.version)
        }
        CommandVariant::VersionMinWatchos(min) => (
            pick(PLATFORM_WATCHOS, PLATFORM_WATCHOSSIMULATOR),
            min.version,
        ),
        CommandVariant::VersionMinMacosx(min) => (PLATFORM_MACOS, min.version),
        _ => return None,
    };
    // X.Y.Z packed into 16, 8 and 8 bits.
    let (major, minor, patch) = (version >> 16, (version >> 8) & 0xff, version & 0xff);
    let min_os = match patch {
        0 => format!("{major}.{minor}"),
        _ => format!("{major}.{minor}.{patch}"),
    };
    if let PLATFORM_IOS | PLATFORM_IOSSIMULATOR = platform {
        let simulator = platform == PLATFORM_IOSSIMULATOR;
        return Some(Platform::Ios { simulator, min_os });
    }
    let name = match platform {
        PLATFORM_MACOS => "macOS",
        PLATFORM_MACCATALYST => "Mac Catalyst",
        PLATFORM_TVOS => "tvOS",
        PLATFORM_TVOSSIMULATOR => "tvOS simulator",
        PLATFORM_WATCHOS => "watchOS",
        PLATFORM_WATCHOSSIMULATOR => "watchOS simulator",
        PLATFORM_VISIONOS => "visionOS",
        PLATFORM_VISIONOSSIMULATOR => "visionOS simulator",
        PLATFORM_DRIVERKIT => "DriverKit",
        PLATFORM_BRIDGEOS => "bridgeOS",
        _ => "unknown Apple platform",
    };
    Some(Platform::OtherApple { name, min_os })
}
