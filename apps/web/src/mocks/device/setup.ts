// View models of the first-run setup pages: the toolchain download, the first
// build and a failed build. The CLI will send these; sizes and times come formatted.

/** Where a download or a build step is. */
export type StepState = "done" | "active" | "queued";

/** One component of the toolchain download. */
export interface ToolchainPart {
  name: string;
  size: string;
  state: StepState;
  /** For the active part: percent and amount downloaded. */
  percent?: number;
  downloaded?: string;
}

/** The first-run download of the Android toolchain. */
export interface ToolchainDownload {
  downloaded: string;
  total: string;
  percent: number;
  speed: string;
  /** Shown as "About <timeLeft> left". */
  timeLeft: string;
  mirror: string;
  folder: string;
  parts: ToolchainPart[];
}

/** One step of the first build. */
export interface BuildStep {
  name: string;
  detail?: string;
  /** Time spent so far; none while queued. */
  time?: string;
  state: StepState;
  /** The active step's progress bar and its latest Gradle lines. */
  progress?: { label: string; percent: number; output: string[] };
}

/** The first build while it runs, and the device booting next to it. */
export interface BuildRun {
  /** Time since the build started, as mm:ss. */
  elapsed: string;
  steps: BuildStep[];
  device: { name: string; bootedIn: string };
  workers: number;
}

/** A compiler error with the source lines around it. */
export interface CompilerError {
  message: string;
  /** Path under the source root, e.g. `ui/cart/CartViewModel.kt`. */
  file: string;
  line: number;
  column: number;
  /** Source lines around the error; the first one is line `excerptStart`. */
  excerpt: string[];
  excerptStart: number;
  /** The underlined part of the error line, as [start, end) offsets into its text. */
  span: [number, number];
  /** Shown as "Did you mean <name>? <reason>". */
  suggestion?: { name: string; reason: string };
}

/** A build that stopped at a failed step. */
export interface BuildFailure {
  /** Steps that finished before the failure. */
  done: { name: string; time: string }[];
  failed: { name: string; time: string };
  /** The steps that never ran, in a few words. */
  skipped: string;
  /** Time until the failure. */
  duration: string;
  errors: CompilerError[];
  /** The last lines of the Gradle output. */
  output: string[];
}

/** The `irisrun start` session the setup pages belong to. */
export const setupSession = { project: "kedai-android", target: "app · debug", server: "localhost:7420" };

export const toolchainDownload: ToolchainDownload = {
  downloaded: "605 MB",
  total: "1.47 GB",
  percent: 41,
  speed: "18.4 MB/s",
  timeLeft: "47 s",
  mirror: "Singapore",
  folder: "~/.irisrun/toolchains",
  parts: [
    { name: "Android SDK Platform 34", size: "182 MB", state: "done" },
    { name: "Build tools 34.0.0", size: "64 MB", state: "done" },
    { name: "Iris Android runtime 14", size: "690 MB", state: "active", percent: 52, downloaded: "359 MB" },
    { name: "Gradle 8.7 · Kotlin compiler", size: "320 MB", state: "queued" },
    { name: "Native ABI support (arm64-v8a)", size: "214 MB", state: "queued" },
  ],
};

export const buildRun: BuildRun = {
  elapsed: "00:21",
  steps: [
    { name: "Resolve dependencies", detail: "84 artifacts from cache", time: "4.2 s", state: "done" },
    { name: "Compile Kotlin", detail: "214 files · K2", time: "9.8 s", state: "done" },
    {
      name: "Process resources & dex",
      detail: "R8 off in debug",
      time: "7.1 s",
      state: "active",
      progress: {
        label: "Dexing progress",
        percent: 62,
        output: [
          "> Task :app:mergeDebugResources UP-TO-DATE",
          "> Task :app:processDebugManifest",
          "> Task :app:dexBuilderDebug",
          "  Dexing 1,924 / 3,104 classes",
        ],
      },
    },
    { name: "Check native libraries", detail: "Binary Doctor", state: "queued" },
    { name: "Install on Pixel 8", detail: "kedai-debug.apk", state: "queued" },
    { name: "Launch MainActivity", state: "queued" },
  ],
  device: { name: "Pixel 8 · Android 14", bootedIn: "3.1 s" },
  workers: 4,
};

export const buildFailure: BuildFailure = {
  done: [{ name: "Resolve dependencies", time: "4.2 s" }],
  failed: { name: "Compile Kotlin", time: "9.8 s" },
  skipped: "Dex, native check, install and launch",
  duration: "14 s",
  errors: [
    {
      message: "Unresolved reference ‘applyCoupon’",
      file: "ui/cart/CartViewModel.kt",
      line: 41,
      column: 31,
      excerptStart: 39,
      excerpt: [
        "    fun addItem(sku: String, qty: Int = 1) = viewModelScope.launch {",
        "        val item = repo.add(sku, qty)",
        "        _state.update { it.applyCoupon(couponCode) + item }",
        "    }",
      ],
      span: [27, 38],
      suggestion: { name: "withCoupon", reason: "It was renamed in CartState.kt 3 minutes ago." },
    },
    {
      message: "Type mismatch: inferred type is Long but Int was expected",
      file: "ui/cart/CartViewModel.kt",
      line: 57,
      column: 22,
      excerptStart: 56,
      excerpt: ["    // total in VND", "    val total: Int = items.sumOf { it.priceVnd }", ""],
      span: [21, 48],
    },
  ],
  output: [
    "> Task :app:compileDebugKotlin FAILED",
    "e: file:///Users/minh/code/kedai-android/app/src/main/java/com/kedai/shop/ui/cart/CartViewModel.kt:41:31 Unresolved reference 'applyCoupon'.",
    "e: file:///Users/minh/code/kedai-android/app/src/main/java/com/kedai/shop/ui/cart/CartViewModel.kt:57:22 Type mismatch: inferred type is 'Long' but 'Int' was expected.",
    "",
    "FAILURE: Build failed with an exception.",
    "* What went wrong:",
    "Execution failed for task ':app:compileDebugKotlin'.",
    "",
    "BUILD FAILED in 14s",
  ],
};
