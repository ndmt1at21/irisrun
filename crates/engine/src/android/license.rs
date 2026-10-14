//! Android SDK setup. irisrun does not install SDK packages itself: the
//! Android Gradle plugin downloads the platforms and build tools a project
//! needs, once the SDK license is accepted. Accepting it here writes the same
//! file that `sdkmanager --licenses` writes.

use std::io::Write;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use sha1::{Digest, Sha1};

/// The repository AGP downloads SDK packages from. It holds the license text.
const REPOSITORY_URL: &str = "https://dl.google.com/android/repository/repository2-3.xml";

/// The license covering SDK platforms and build tools.
const LICENSE_ID: &str = "android-sdk-license";

pub struct License {
    pub text: String,
}

impl License {
    pub async fn fetch() -> Result<License> {
        let xml = crate::http_client()?
            .get(REPOSITORY_URL)
            .send()
            .await
            .and_then(reqwest::Response::error_for_status)
            .context("cannot download the Android SDK repository")?
            .text()
            .await?;
        License::from_repository(&xml)
    }

    fn from_repository(xml: &str) -> Result<License> {
        let doc =
            roxmltree::Document::parse(xml).context("cannot parse the Android SDK repository")?;
        let text = doc
            .descendants()
            .find(|node| node.has_tag_name("license") && node.attribute("id") == Some(LICENSE_ID))
            .and_then(|node| node.text())
            .with_context(|| format!("the Android SDK repository has no {LICENSE_ID}"))?;
        Ok(License {
            text: text.to_owned(),
        })
    }

    /// What the SDK tools record for an accepted license: the SHA-1 of its
    /// text as they read it (`com.android.repository.api.License#getLicenseHash`).
    fn hash(&self) -> String {
        Sha1::digest(sdk_whitespace(&self.text).as_bytes())
            .iter()
            .map(|b| format!("{b:02x}"))
            .collect()
    }
}

/// Reflows text the way the SDK tools' `TrimStringAdapter` does when they
/// parse the repository: drop spaces and tabs that follow whitespace, join
/// lines within a paragraph, squeeze spaces, trim.
fn sdk_whitespace(text: &str) -> String {
    // Java's `\s`.
    let is_space = |c: char| matches!(c, ' ' | '\t' | '\n' | '\x0b' | '\x0c' | '\r');

    let mut dropped = String::with_capacity(text.len());
    let mut after_space = false;
    for c in text.chars() {
        if !(after_space && matches!(c, ' ' | '\t')) {
            dropped.push(c);
        }
        after_space = is_space(c);
    }

    let chars: Vec<char> = dropped.chars().collect();
    let mut joined = String::with_capacity(dropped.len());
    for (i, &c) in chars.iter().enumerate() {
        let lone_newline = c == '\n'
            && i.checked_sub(1).is_none_or(|prev| chars[prev] != '\n')
            && chars.get(i + 1) != Some(&'\n');
        joined.push(if lone_newline { ' ' } else { c });
    }

    let mut squeezed = String::with_capacity(joined.len());
    for c in joined.chars() {
        if !(c == ' ' && squeezed.ends_with(' ')) {
            squeezed.push(c);
        }
    }
    // Java's `String#trim`.
    squeezed.trim_matches(|c: char| c <= ' ').to_owned()
}

/// The SDK directory irisrun points `ANDROID_HOME` at.
pub struct AndroidSdk {
    root: PathBuf,
}

impl AndroidSdk {
    pub fn new(irisrun_home: &Path) -> AndroidSdk {
        AndroidSdk {
            root: irisrun_home.join("android-sdk"),
        }
    }

    pub fn root(&self) -> &Path {
        &self.root
    }

    /// Whether some version of the license was accepted. Checking the exact
    /// version needs the network; AGP names the license if it wants a newer one.
    pub fn has_license(&self) -> bool {
        self.license_file().is_file()
    }

    pub fn has_accepted(&self, license: &License) -> bool {
        let hash = license.hash();
        std::fs::read_to_string(self.license_file())
            .is_ok_and(|accepted| accepted.lines().any(|line| line.trim() == hash))
    }

    /// Records that the user accepted `license`, keeping earlier versions.
    pub fn accept(&self, license: &License) -> Result<()> {
        let file = self.license_file();
        std::fs::create_dir_all(file.parent().unwrap_or(&self.root))?;
        std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&file)
            .and_then(|mut f| write!(f, "\n{}", license.hash()))
            .with_context(|| format!("cannot write {}", file.display()))
    }

    fn license_file(&self) -> PathBuf {
        self.root.join("licenses").join(LICENSE_ID)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const REPOSITORY: &str = r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<sdk:sdk-repository xmlns:sdk="http://schemas.android.com/sdk/android/repo/repository2/03">
  <license id="android-sdk-preview-license" type="text">Preview terms</license>
  <license id="android-sdk-license" type="text">Terms &amp; Conditions
</license>
</sdk:sdk-repository>"#;

    #[test]
    fn accepts_the_sdk_license_from_the_repository() {
        let license = License::from_repository(REPOSITORY).unwrap();
        assert_eq!(license.text, "Terms & Conditions\n");
        // SHA-1 of "Terms & Conditions", the text after sdk_whitespace.
        assert_eq!(license.hash(), "d35f2b98edf8da0fba5fece022307f35916c5a8f");

        let home = tempfile::tempdir().unwrap();
        let sdk = AndroidSdk::new(home.path());
        assert!(!sdk.has_accepted(&license));
        sdk.accept(&license).unwrap();
        assert!(sdk.has_accepted(&license));
    }

    #[test]
    fn reflows_whitespace_like_the_sdk_tools() {
        // Expected output from the same rules in Java regex form:
        // replaceAll("(?<=\\s)[ \t]*", "").replaceAll("(?<!\n)\n(?!\n)", " ").replaceAll(" +", " ").trim()
        let text = "  Terms  and\n   Conditions\n\n1. Intro\tgoes\n here.\n";
        assert_eq!(
            sdk_whitespace(text),
            "Terms and Conditions\n\n1. Intro\tgoes here."
        );
    }
}
