// What `import QuartzCore` loads in an app (-module-alias QuartzCore=IrisQuartzCore): OpenUIKit,
// which has the QuartzCore types. One module can't stand for two aliases.
@_exported import OpenUIKit
