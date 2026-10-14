//! Finds binaries in directories and zip containers (.aar, .jar, .apk,
//! .zip), then looks at what ships around each one.

use std::collections::HashSet;
use std::ffi::OsStr;
use std::fs::File;
use std::io::{Cursor, Read};
use std::path::{Path, PathBuf};

use anyhow::{Context, Result};

use crate::{Binary, Platform, Report, object};

/// The directories AARs and APKs keep each ABI's libraries in; prefab
/// packages prefix them with `android.`.
const ABI_DIRS: [&str; 8] = [
    "arm64-v8a",
    "armeabi-v7a",
    "armeabi",
    "x86",
    "x86_64",
    "riscv64",
    "mips",
    "mips64",
];

/// Scans a file, or a directory and everything below it.
pub fn scan(path: &Path) -> Result<Report> {
    let mut scan = Scan::default();
    let metadata =
        std::fs::metadata(path).with_context(|| format!("cannot read {}", path.display()))?;
    if metadata.is_dir() {
        scan.dir(path);
    } else {
        let file = File::open(path).with_context(|| format!("cannot open {}", path.display()))?;
        scan.file(path.to_owned(), file);
    }
    Ok(scan.finish())
}

#[derive(Default)]
struct Scan {
    binaries: Vec<Binary>,
    /// `.swiftinterface` and header files, matched to binaries by directory.
    interfaces: Vec<PathBuf>,
    /// xcframeworks whose Info.plist lists an arm64 iOS-simulator library.
    arm64_simulator_xcframeworks: HashSet<PathBuf>,
    warnings: Vec<String>,
}

impl Scan {
    fn dir(&mut self, dir: &Path) {
        let mut entries = match std::fs::read_dir(dir) {
            Ok(entries) => entries.filter_map(Result::ok).collect::<Vec<_>>(),
            Err(error) => return self.warn(dir, error.into()),
        };
        entries.sort_by_key(|entry| entry.file_name());
        for entry in entries {
            let path = entry.path();
            // Symlinks are skipped: in frameworks they point at files that
            // are scanned anyway, such as `Versions/Current`.
            match entry.file_type() {
                Ok(kind) if kind.is_dir() => self.dir(&path),
                Ok(kind) if kind.is_file() => match File::open(&path) {
                    Ok(file) => self.file(path, file),
                    Err(error) => self.warn(&path, error.into()),
                },
                _ => {}
            }
        }
    }

    fn file(&mut self, path: PathBuf, reader: impl Read) {
        if let Err(error) = self.try_file(&path, reader) {
            self.warn(&path, error);
        }
    }

    fn try_file(&mut self, path: &Path, mut reader: impl Read) -> Result<()> {
        if has_extension(path, "swiftinterface") || has_extension(path, "h") {
            self.interfaces.push(path.to_owned());
            return Ok(());
        }
        let xcframework = path
            .parent()
            .filter(|dir| has_extension(dir, "xcframework"))
            .filter(|_| path.file_name() == Some(OsStr::new("Info.plist")));

        let mut bytes = Vec::new();
        reader.by_ref().take(16).read_to_end(&mut bytes)?;
        let zip = bytes.starts_with(b"PK\x03\x04");
        let binary = object::is_binary(&bytes);
        if !zip && !binary && xcframework.is_none() {
            return Ok(());
        }
        reader.read_to_end(&mut bytes)?;

        if zip {
            self.zip(path, bytes)?;
        } else if binary {
            self.binaries.extend(object::read(path.to_owned(), &bytes)?);
        } else if let Some(xcframework) = xcframework
            && lists_arm64_simulator(&String::from_utf8_lossy(&bytes))?
        {
            self.arm64_simulator_xcframeworks
                .insert(xcframework.to_owned());
        }
        Ok(())
    }

    // ponytail: holds each container in memory; stream from disk if
    // multi-gigabyte IPAs show up.
    fn zip(&mut self, path: &Path, bytes: Vec<u8>) -> Result<()> {
        let mut zip = zip::ZipArchive::new(Cursor::new(bytes))?;
        for index in 0..zip.len() {
            match zip.by_index(index) {
                Ok(entry) if entry.is_file() => {
                    let entry_path = path.join(&*entry.name()?);
                    self.file(entry_path, entry);
                }
                Ok(_) => {}
                Err(error) => self.warn(path, error.into()),
            }
        }
        Ok(())
    }

    fn warn(&mut self, path: &Path, error: anyhow::Error) {
        self.warnings.push(format!("{}: {error:#}", path.display()));
    }

    /// Fills in what each binary's neighbours tell.
    fn finish(mut self) -> Report {
        let x86_64_libraries: HashSet<PathBuf> = self
            .binaries
            .iter()
            .filter(|binary| {
                binary.slices.iter().any(|slice| {
                    slice.arch == "x86_64" && matches!(slice.platform, Platform::Android { .. })
                })
            })
            .map(|binary| abi_neutral(&binary.path))
            .collect();
        for binary in &mut self.binaries {
            let bundle = bundle_dir(&binary.path).to_owned();
            let ships = |extension| {
                self.interfaces
                    .iter()
                    .any(|file| file.starts_with(&bundle) && has_extension(file, extension))
            };
            binary.swiftinterface = ships("swiftinterface");
            binary.headers = ships("h");
            binary.x86_64_build = x86_64_libraries.contains(&abi_neutral(&binary.path));
            binary.arm64_simulator = binary.slices.iter().any(|slice| {
                slice.arch == "arm64"
                    && matches!(
                        slice.platform,
                        Platform::Ios {
                            simulator: true,
                            ..
                        }
                    )
            }) || binary
                .path
                .ancestors()
                .find(|dir| has_extension(dir, "xcframework"))
                .is_some_and(|xcframework| self.arm64_simulator_xcframeworks.contains(xcframework));
        }
        Report {
            binaries: self.binaries,
            warnings: self.warnings,
        }
    }
}

/// Where a library sits whatever its ABI: `jni/x86_64/libfoo.so` and
/// `jni/arm64-v8a/libfoo.so` both give `jni/libfoo.so`.
fn abi_neutral(path: &Path) -> PathBuf {
    let abi_dir = path.parent().filter(|dir| {
        dir.file_name()
            .and_then(OsStr::to_str)
            .is_some_and(|name| ABI_DIRS.contains(&name.strip_prefix("android.").unwrap_or(name)))
    });
    match (abi_dir, path.file_name()) {
        (Some(dir), Some(name)) => dir.with_file_name(name),
        _ => path.to_owned(),
    }
}

/// The directory whose files ship with a binary: its innermost framework,
/// its library directory in an xcframework, or else its own directory.
fn bundle_dir(binary: &Path) -> &Path {
    let dirs = binary.ancestors().skip(1);
    dirs.clone()
        .find(|dir| has_extension(dir, "framework"))
        .or_else(|| {
            dirs.clone().find(|dir| {
                dir.parent()
                    .is_some_and(|up| has_extension(up, "xcframework"))
            })
        })
        .unwrap_or_else(|| binary.parent().unwrap_or(binary))
}

fn has_extension(path: &Path, extension: &str) -> bool {
    path.extension() == Some(OsStr::new(extension))
}

/// Whether an xcframework's Info.plist lists, among its AvailableLibraries,
/// one for the arm64 iOS simulator.
fn lists_arm64_simulator(plist: &str) -> Result<bool> {
    let options = roxmltree::ParsingOptions {
        allow_dtd: true,
        ..Default::default()
    };
    let doc = roxmltree::Document::parse_with_options(plist, options)
        .context("cannot parse the xcframework's Info.plist")?;
    Ok(doc
        .descendants()
        .filter(|node| node.has_tag_name("dict"))
        .any(|library| {
            let value = |key: &str| {
                library
                    .children()
                    .filter(roxmltree::Node::is_element)
                    .skip_while(|node| !(node.has_tag_name("key") && node.text() == Some(key)))
                    .nth(1)
            };
            let text = |key| value(key).and_then(|node| node.text());
            text("SupportedPlatform") == Some("ios")
                && text("SupportedPlatformVariant") == Some("simulator")
                && value("SupportedArchitectures")
                    .is_some_and(|archs| archs.children().any(|arch| arch.text() == Some("arm64")))
        }))
}

#[cfg(test)]
mod tests {
    use std::io::Write;

    use goblin::elf::header::{EM_AARCH64, EM_X86_64};

    use super::*;
    use crate::{Slice, Strategy};

    /// A minimal Android shared library: API 21 in `.note.android.ident`,
    /// `DT_NEEDED liblog.so` and an exported `Java_Foo_bar`.
    fn android_library(machine: u16) -> Vec<u8> {
        let mut elf = b"\x7fELF\x02\x01\x01\0\0\0\0\0\0\0\0\0".to_vec();
        let mut put = |bytes: &[u8]| elf.extend_from_slice(bytes);
        // ET_DYN, version 1, no entry, program headers at 64, no sections.
        put(&3u16.to_le_bytes());
        put(&machine.to_le_bytes());
        put(&1u32.to_le_bytes());
        for value in [0u64, 64, 0] {
            put(&value.to_le_bytes());
        }
        put(&0u32.to_le_bytes());
        for value in [64u16, 56, 3, 64, 0, 0] {
            put(&value.to_le_bytes());
        }
        // PT_LOAD of the whole file at address 0, PT_DYNAMIC, PT_NOTE.
        for (kind, offset, size) in [(1u32, 0u64, 472u64), (2, 360, 112), (4, 232, 24)] {
            put(&kind.to_le_bytes());
            put(&4u32.to_le_bytes());
            for value in [offset, offset, offset, size, size, 4] {
                put(&value.to_le_bytes());
            }
        }
        // 232: the note. 256: the string table, padded to 288.
        for value in [8u32, 4, 1] {
            put(&value.to_le_bytes());
        }
        put(b"Android\0");
        put(&21u32.to_le_bytes());
        put(b"\0liblog.so\0Java_Foo_bar\0\0\0\0\0\0\0\0\0");
        // 288: the symbol table, a null symbol then a global function.
        put(&[0; 24]);
        put(&11u32.to_le_bytes());
        put(&[0x12, 0, 1, 0]);
        put(&0x100u64.to_le_bytes());
        put(&0u64.to_le_bytes());
        // 336: a hash table telling there are two symbols, padded to 360.
        for value in [1u32, 2, 1, 0, 0, 0] {
            put(&value.to_le_bytes());
        }
        // 360: the dynamic section, as tag and value pairs: NEEDED, HASH,
        // STRTAB, SYMTAB, STRSZ, SYMENT, NULL.
        for value in [1, 1, 4, 336, 5, 256, 6, 288, 10, 24, 11, 24, 0, 0] {
            put(&u64::to_le_bytes(value));
        }
        elf
    }

    /// A minimal arm64 dylib for iOS 15.5 that loads libz.
    fn ios_dylib() -> Vec<u8> {
        // Header: arm64, MH_DYLIB, two commands in 72 bytes.
        let header = [0xfeedfacf, 0x100000c, 0, 6, 2, 72, 0, 0];
        // LC_BUILD_VERSION: iOS 15.5, SDK 17.0, no tools.
        let build_version = [0x32, 24, 2, 0xf0500, 0x110000, 0];
        // LC_LOAD_DYLIB, with its name right after.
        let load_dylib = [0xc, 48, 24, 0, 0x10000, 0x10000];
        let words = header.into_iter().chain(build_version).chain(load_dylib);
        let mut bytes: Vec<u8> = words.flat_map(u32::to_le_bytes).collect();
        bytes.extend_from_slice(b"/usr/lib/libz.1.dylib\0\0\0");
        bytes
    }

    const XCFRAMEWORK_PLIST: &str = r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>AvailableLibraries</key>
  <array>
    <dict>
      <key>LibraryIdentifier</key><string>ios-arm64</string>
      <key>SupportedArchitectures</key><array><string>arm64</string></array>
      <key>SupportedPlatform</key><string>ios</string>
    </dict>
    <dict>
      <key>LibraryIdentifier</key><string>ios-arm64_x86_64-simulator</string>
      <key>SupportedArchitectures</key><array><string>arm64</string><string>x86_64</string></array>
      <key>SupportedPlatform</key><string>ios</string>
      <key>SupportedPlatformVariant</key><string>simulator</string>
    </dict>
  </array>
</dict>
</plist>"#;

    fn zip(entries: &[(&str, &[u8])]) -> Vec<u8> {
        let mut zip = zip::ZipWriter::new(Cursor::new(Vec::new()));
        for (name, data) in entries {
            zip.start_file(*name, zip::write::SimpleFileOptions::default())
                .unwrap();
            zip.write_all(data).unwrap();
        }
        zip.finish().unwrap().into_inner()
    }

    #[test]
    fn scans_libraries_and_frameworks_inside_nested_zips() {
        let framework = "Foo.xcframework/ios-arm64/Foo.framework";
        let xcframework = zip(&[
            (&format!("{framework}/Foo"), &ios_dylib()),
            (
                &format!("{framework}/Modules/Foo.swiftmodule/arm64-apple-ios.swiftinterface"),
                b"// swift-interface-format-version: 1.0",
            ),
            ("Foo.xcframework/Info.plist", XCFRAMEWORK_PLIST.as_bytes()),
        ]);
        let sdk = zip(&[
            ("jni/arm64-v8a/libfoo.so", &android_library(EM_AARCH64)),
            ("jni/x86_64/libfoo.so", &android_library(EM_X86_64)),
            ("Foo.xcframework.zip", &xcframework),
        ]);

        let mut scan = Scan::default();
        scan.file(PathBuf::from("sdk.zip"), Cursor::new(sdk));
        let report = scan.finish();

        assert_eq!(report.warnings, Vec::<String>::new());
        let [arm64, x86_64, ios] = &report.binaries[..] else {
            panic!("expected three binaries, got {:?}", report.binaries);
        };
        assert_eq!(arm64.path, Path::new("sdk.zip/jni/arm64-v8a/libfoo.so"));
        assert_eq!(arm64.format, "ELF shared library");
        assert_eq!(
            arm64.slices,
            [Slice {
                arch: "arm64-v8a",
                platform: Platform::Android { min_api: Some(21) },
            }]
        );
        assert_eq!(arm64.needed, ["liblog.so"]);
        assert_eq!(arm64.jni_exports, ["Java_Foo_bar"]);
        // The arm64 build counts the x86_64 build next to it.
        assert_eq!(arm64.strategy(), Strategy::BionicLoader);
        assert_eq!(x86_64.strategy(), Strategy::BionicLoader);

        assert_eq!(
            ios.path,
            Path::new(&format!("sdk.zip/Foo.xcframework.zip/{framework}/Foo"))
        );
        assert_eq!(ios.format, "Mach-O dynamic library");
        assert_eq!(
            ios.slices,
            [Slice {
                arch: "arm64",
                platform: Platform::Ios {
                    simulator: false,
                    min_os: "15.5".to_owned(),
                },
            }]
        );
        assert_eq!(ios.needed, ["/usr/lib/libz.1.dylib"]);
        assert!(ios.swiftinterface && !ios.headers && !ios.swift);
        // Only the Info.plist tells of the simulator library.
        assert!(ios.arm64_simulator);
        assert_eq!(ios.strategy(), Strategy::SwiftStub);
    }
}
