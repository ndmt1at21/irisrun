# Sourced by the scripts next to it: where the OpenSwiftUI checkouts live and the OpenSwiftUI
# configuration Iris builds. The OpenSwiftUIProject manifests read these at resolution time.
export IRISRUN_IOS_WORK="${IRISRUN_IOS_WORK:-$HOME/.cache/irisrun/p0-05}"

export OPENSWIFTUI_USE_LOCAL_DEPS=1
# Compute is the only AttributeGraph backend that runs on Linux; OpenAttributeGraph's own is unfinished.
export OPENSWIFTUI_OPENATTRIBUTESHIMS_COMPUTE=1
export OPENSWIFTUI_OPENATTRIBUTESHIMS_ATTRIBUTEGRAPH=0
# Iris has no use for the GTK target, which needs gtk4 through pkg-config.
export OPENSWIFTUI_RENDER_GTK=0
# The Swift package of Iris's render core, which OpenSwiftUI measures and draws text with on Linux.
OPENSWIFTUI_IRIS_RENDER_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../crates/render/swift" && pwd)"
export OPENSWIFTUI_IRIS_RENDER_PATH
# Toolchain headers (CoreFoundation, SwiftShims) for the C targets.
if [ -z "${OPENSWIFTUI_LIB_SWIFT_PATH:-}" ] && command -v swift > /dev/null; then
    OPENSWIFTUI_LIB_SWIFT_PATH="$(dirname "$(dirname "$(readlink -f "$(command -v swift)")")")/lib/swift"
    export OPENSWIFTUI_LIB_SWIFT_PATH
fi
