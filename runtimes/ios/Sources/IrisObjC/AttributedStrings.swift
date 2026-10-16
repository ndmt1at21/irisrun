import Foundation

extension NSMutableAttributedString {
    /// Iris: `addAttribute(_:value:range:)`, which irisrun-ios-build calls instead. Foundation
    /// on Linux stops the app when it merges attributes whose values are objects, such as
    /// fonts and colors, so this sets each run's attributes whole.
    public func _irisAddAttribute(_ name: NSAttributedString.Key, value: Any, range: NSRange) {
        _irisAddAttributes([name: value], range: range)
    }

    /// Iris: `addAttributes(_:range:)`, as `_irisAddAttribute` replaces its sibling.
    public func _irisAddAttributes(_ attrs: [NSAttributedString.Key: Any], range: NSRange) {
        var runs: [(NSRange, [NSAttributedString.Key: Any])] = []
        enumerateAttributes(in: range, options: []) { attributes, run, _ in
            runs.append((run, attributes.merging(attrs) { $1 }))
        }
        for (run, attributes) in runs {
            setAttributes(attributes, range: run)
        }
    }
}
