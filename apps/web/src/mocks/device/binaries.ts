/** How a native binary runs on this computer's CPU. */
export type BinaryStatus = "ok" | "slow" | "wont-run";

/** An Android `.so` or an iOS `.xcframework`, as Binary Doctor reports it after a build. */
export interface NativeBinary {
  name: string;
  /** Where an Android library comes from: a vendored AAR or a Maven coordinate. */
  source?: string;
  /** The CPU architectures it ships: Android ABIs or xcframework slices. */
  abis: string;
  /** How it runs on this computer. */
  how: string;
  status: BinaryStatus;
  size: string;
  /** Why it won't run, for the alert above the table. */
  reason?: string;
}

export interface BinaryReport {
  project: string;
  target: string;
  /** This computer's CPU architecture and OS. */
  host: { arch: string; os: string };
  libraries: NativeBinary[];
  /** The iOS project's frameworks, from its last check. */
  ios: { project: string; checked: string; frameworks: NativeBinary[] };
}

export const binaryReport: BinaryReport = {
  project: "kedai-android",
  target: "app · debug",
  host: { arch: "x86_64", os: "Linux" },
  libraries: [
    {
      name: "libekyc_face.so",
      source: "libs/ekyc-sdk-2.3.aar · vendored",
      abis: "arm64-v8a",
      how: "Needs ARM camera hardware",
      status: "wont-run",
      size: "6.8 MB",
      reason:
        "only ships an ARM build that talks to camera hardware. The ID-verification flow will stop locally — the rest of the app runs fine.",
    },
    {
      name: "libpaygate_vn.so",
      source: "libs/paygate-4.1.aar · vendored",
      abis: "arm64-v8a",
      how: "Translated ARM → x86_64",
      status: "slow",
      size: "2.2 MB",
    },
    {
      name: "libsocial_login.so",
      source: "com.example.social:login:5.0.2",
      abis: "arm64-v8a, armeabi-v7a",
      how: "Translated ARM → x86_64",
      status: "slow",
      size: "1.4 MB",
    },
    {
      name: "libsqlcipher.so",
      source: "net.zetetic:sqlcipher-android:4.6.0",
      abis: "arm64-v8a, x86_64",
      how: "Native x86_64",
      status: "ok",
      size: "3.9 MB",
    },
    {
      name: "libtensorflowlite_jni.so",
      source: "org.tensorflow:tensorflow-lite:2.16.1",
      abis: "arm64-v8a, x86_64",
      how: "Native x86_64",
      status: "ok",
      size: "4.6 MB",
    },
    {
      name: "libimagepipeline.so",
      source: "com.facebook.fresco:imagepipeline:3.2.0",
      abis: "arm64-v8a, x86_64",
      how: "Native x86_64",
      status: "ok",
      size: "0.9 MB",
    },
    {
      name: "libmmkv.so",
      source: "com.tencent:mmkv:1.3.9",
      abis: "arm64-v8a, x86_64",
      how: "Native x86_64",
      status: "ok",
      size: "0.7 MB",
    },
    { name: "libc++_shared.so", source: "NDK r26", abis: "all 4 ABIs", how: "Native x86_64", status: "ok", size: "1.1 MB" },
  ],
  ios: {
    project: "kedai-ios",
    checked: "2h ago",
    frameworks: [
      { name: "FaceKit.xcframework", abis: "ios-arm64, simulator", how: "Simulator slice (arm64)", status: "ok", size: "8.4 MB" },
      { name: "PayGateVN.xcframework", abis: "ios-arm64 only", how: "No simulator slice", status: "wont-run", size: "3.1 MB" },
      {
        name: "KedaiAnalytics.xcframework",
        abis: "ios-arm64, simulator",
        how: "Simulator slice (arm64)",
        status: "ok",
        size: "1.2 MB",
      },
    ],
  },
};
