//! The irisrun command line.

use std::io::{IsTerminal, Write};
use std::net::SocketAddr;
use std::path::{Path, PathBuf};
use std::time::Instant;

use anyhow::{Result, bail, ensure};
use clap::{Parser, Subcommand, ValueEnum};
use indicatif::{ProgressBar, ProgressStyle};
use irisrun_doctor::{Binary, Strategy, Tier};
use irisrun_engine::android::{self, AndroidProject, AndroidSdk, DEFAULT_QUALIFIERS, License};
use irisrun_engine::device;
use irisrun_engine::toolchain::{Host, Progress, Tool, Toolchains};

/// Run Android and iOS apps from source, without devices or SDK installs.
#[derive(Parser)]
#[command(name = "irisrun", version)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Build an app and run it, with its screen in the browser.
    Start {
        /// The project directory.
        #[arg(default_value = ".")]
        project: PathBuf,
        /// The port for the Device UI.
        #[arg(long, default_value_t = 7777)]
        port: u16,
    },
    /// Find the native binaries in projects, SDKs or archives, and how each can run.
    Doctor {
        /// Files or directories: .so, .a, .dylib, .aar, .jar, .zip, (xc)frameworks…
        #[arg(required = true)]
        paths: Vec<PathBuf>,
    },
    /// Manage the toolchains irisrun keeps in ~/.irisrun.
    #[command(subcommand)]
    Toolchain(ToolchainCommand),
}

#[derive(Subcommand)]
enum ToolchainCommand {
    /// Download toolchains: all of them, unless some are named.
    Install {
        components: Vec<Component>,
        /// Accept the Android SDK license without showing it.
        #[arg(long)]
        accept_android_sdk_license: bool,
    },
    /// Show where each toolchain is installed.
    List,
}

#[derive(Clone, Copy, PartialEq, Eq, ValueEnum)]
enum Component {
    Jdk,
    Swift,
    /// The Android SDK license, so that Gradle can download SDK packages.
    AndroidSdk,
}

#[tokio::main]
async fn main() -> Result<()> {
    match Cli::parse().command {
        Command::Start { project, port } => start(&project, port).await,
        Command::Doctor { paths } => doctor(&paths),
        Command::Toolchain(ToolchainCommand::Install {
            components,
            accept_android_sdk_license,
        }) => install(components, accept_android_sdk_license).await,
        Command::Toolchain(ToolchainCommand::List) => list(),
    }
}

async fn start(project: &Path, port: u16) -> Result<()> {
    let home = irisrun_engine::home_dir()?;
    let toolchains = Toolchains::new(&home, Host::detect()?);
    let project = AndroidProject::open(project)?;
    if !toolchains.is_installed(Tool::Jdk) {
        install_tool(&toolchains, Tool::Jdk).await?;
    }
    let sdk = AndroidSdk::new(&home);
    if !sdk.has_license() {
        accept_android_license(&sdk, false).await?;
    }
    let maven_repo = home.join("maven");
    ensure!(
        maven_repo.join("dev/irisrun/android/host").is_dir(),
        "the irisrun Android host is missing from {}; run `./gradlew publish` in runtimes/android",
        maven_repo.display()
    );

    let started = Instant::now();
    let java_home = toolchains.java_home();
    let launch = project.build(&java_home, &sdk, &maven_repo).await?;
    eprintln!("irisrun: built in {:.1}s", started.elapsed().as_secs_f64());

    let addr = SocketAddr::from(([127, 0, 0, 1], port));
    eprintln!("irisrun: open the Device UI at http://{addr}");
    device::serve(addr, move || {
        android::host_command(&java_home, &launch, DEFAULT_QUALIFIERS)
    })
    .await
}

async fn install(components: Vec<Component>, accept_license: bool) -> Result<()> {
    let home = irisrun_engine::home_dir()?;
    let toolchains = Toolchains::new(&home, Host::detect()?);
    let components = match components.is_empty() {
        true => Component::value_variants().to_vec(),
        false => components,
    };

    let mut failed = 0;
    for component in &components {
        let result = match component {
            Component::Jdk => install_tool(&toolchains, Tool::Jdk).await,
            Component::Swift => install_tool(&toolchains, Tool::Swift).await,
            Component::AndroidSdk => {
                accept_android_license(&AndroidSdk::new(&home), accept_license).await
            }
        };
        if let Err(error) = result {
            eprintln!("error: {error:#}");
            failed += 1;
        }
    }
    ensure!(
        failed == 0,
        "{failed} of {} components failed to install",
        components.len()
    );
    Ok(())
}

async fn install_tool(toolchains: &Toolchains, tool: Tool) -> Result<()> {
    let label = format!("{} {}", tool.name(), tool.version());
    if toolchains.is_installed(tool) {
        println!(
            "{label} is already installed in {}",
            toolchains.path(tool).display()
        );
        return Ok(());
    }

    let style =
        ProgressStyle::with_template("{msg} {wide_bar} {bytes}/{total_bytes} {bytes_per_sec}")?;
    let bar = ProgressBar::no_length()
        .with_style(style)
        .with_message(format!("Downloading {label}"));
    let installed = toolchains
        .install(tool, |progress| match progress {
            Progress::Downloading { done, total } => {
                bar.set_length(total.unwrap_or(done));
                bar.set_position(done);
            }
            Progress::Unpacking => bar.set_message(format!("Unpacking {label}")),
        })
        .await;
    bar.finish_and_clear();

    let installed = installed?;
    println!(
        "Installed {label} in {:.1}s ({:.0} MB downloaded) to {}",
        installed.elapsed.as_secs_f64(),
        installed.downloaded_bytes as f64 / 1e6,
        installed.path.display()
    );
    Ok(())
}

async fn accept_android_license(sdk: &AndroidSdk, accept: bool) -> Result<()> {
    let license = License::fetch().await?;
    if !sdk.has_accepted(&license) {
        if !accept {
            ensure!(
                std::io::stdin().is_terminal(),
                "the Android SDK license needs your consent; rerun with --accept-android-sdk-license"
            );
            println!("{}\n", license.text.trim());
            print!("Do you accept the Android SDK license above? [y/N] ");
            std::io::stdout().flush()?;
            let mut answer = String::new();
            std::io::stdin().read_line(&mut answer)?;
            if !matches!(answer.trim(), "y" | "Y" | "yes") {
                bail!("the Android SDK license was not accepted");
            }
        }
        sdk.accept(&license)?;
    }
    println!(
        "Android SDK license accepted; Gradle downloads SDK packages into {}",
        sdk.root().display()
    );
    Ok(())
}

fn list() -> Result<()> {
    let home = irisrun_engine::home_dir()?;
    let toolchains = Toolchains::new(&home, Host::detect()?);
    for tool in Tool::ALL {
        let place = match toolchains.is_installed(tool) {
            true => toolchains.path(tool).display().to_string(),
            false => "not installed".to_owned(),
        };
        println!("{:<6} {:<12} {place}", tool.name(), tool.version());
    }
    println!(
        "{:<19} {}",
        "android-sdk",
        AndroidSdk::new(&home).root().display()
    );
    Ok(())
}

fn doctor(paths: &[PathBuf]) -> Result<()> {
    for path in paths {
        let report = irisrun_doctor::scan(path)?;
        for warning in &report.warnings {
            eprintln!("warning: {warning}");
        }
        let (mut local, mut cloud, mut android) = (0, 0, false);
        for binary in &report.binaries {
            let strategy = binary.strategy();
            print_binary(binary, strategy);
            match strategy.tier() {
                Some(Tier::Local) => local += 1,
                Some(Tier::Cloud) => cloud += 1,
                None => {}
            }
            android |= matches!(
                strategy,
                Strategy::BionicLoader | Strategy::CpuTranslation | Strategy::JniStub
            );
        }
        let total = report.binaries.len();
        println!(
            "{}: {total} binaries, {local} local, {cloud} cloud, {} skipped",
            path.display(),
            total - local - cloud
        );
        if android {
            println!("Android libraries whose NDK source is in the project: rebuild them instead.");
        }
    }
    Ok(())
}

fn print_binary(binary: &Binary, strategy: Strategy) {
    let slices: Vec<_> = binary
        .slices
        .iter()
        .map(|slice| format!("{} {}", slice.arch, slice.platform))
        .collect();
    println!("{}", binary.path.display());
    println!("  {}: {}", binary.format, slices.join(", "));
    let Some(tier) = strategy.tier() else {
        println!("  skip: {strategy}");
        return;
    };
    if !binary.needed.is_empty() {
        // Install names are long paths; the last part says enough.
        let names: Vec<_> = binary
            .needed
            .iter()
            .map(|lib| lib.rsplit('/').next().unwrap_or(lib))
            .collect();
        println!("  needs {}", names.join(", "));
    }
    let onload = binary.jni_exports.iter().any(|name| name == "JNI_OnLoad");
    match (onload, binary.jni_exports.len() - usize::from(onload)) {
        (false, 0) => {}
        (true, 0) => println!("  JNI: JNI_OnLoad"),
        (false, java) => println!("  JNI: {java} Java_* functions"),
        (true, java) => println!("  JNI: JNI_OnLoad, {java} Java_* functions"),
    }
    if matches!(
        strategy,
        Strategy::SwiftStub | Strategy::HeaderStub | Strategy::CloudSimulator
    ) {
        let yes = |flag| if flag { "yes" } else { "no" };
        println!(
            "  Swift: {}, .swiftinterface: {}, headers: {}, arm64 simulator build: {}",
            yes(binary.swift),
            yes(binary.swiftinterface),
            yes(binary.headers),
            yes(binary.arm64_simulator)
        );
    }
    println!("  {tier}: {strategy}");
}
