//! Android: the SDK license AGP needs, and running an app's own Gradle build
//! on the irisrun Robolectric host (runtimes/android).

mod license;
mod project;

pub use license::{AndroidSdk, License};
pub use project::{AndroidProject, DEFAULT_QUALIFIERS, Launch, host_command};
