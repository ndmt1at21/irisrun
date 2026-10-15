//! The local engine behind the irisrun CLI: it fetches toolchains, builds
//! projects, runs them on a device runtime and serves the Device UI.

pub mod android;
pub mod device;
pub mod ios;
pub mod toolchain;

use std::path::PathBuf;

use anyhow::{Context, Result};

/// Where irisrun keeps toolchains and caches: `$IRISRUN_HOME`, or
/// `~/.irisrun` by default.
pub fn home_dir() -> Result<PathBuf> {
    if let Some(dir) = std::env::var_os("IRISRUN_HOME") {
        return Ok(dir.into());
    }
    let home = std::env::home_dir().context("cannot find the home directory; set IRISRUN_HOME")?;
    Ok(home.join(".irisrun"))
}

/// An HTTP client for downloads. It trusts the system's certificates, plus
/// Mozilla's root certificates for minimal systems that have none.
pub(crate) fn http_client() -> Result<reqwest::Client> {
    let mozilla_roots = webpki_root_certs::TLS_SERVER_ROOT_CERTS
        .iter()
        .map(|der| reqwest::Certificate::from_der(der))
        .collect::<reqwest::Result<Vec<_>>>()?;
    Ok(reqwest::Client::builder()
        .tls_certs_merge(mozilla_roots)
        .build()?)
}
