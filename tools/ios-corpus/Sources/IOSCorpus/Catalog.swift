// Names used to attribute syntax to SwiftUI, UIKit and Apple modules. Written by hand from
// public documentation knowledge, not from any Apple SDK file. The `unattributed` block of
// `tables.md` lists the most used names this catalog misses.

func words(_ text: String) -> Set<String> {
    Set(text.split(whereSeparator: \.isWhitespace).map(String.init))
}

enum Catalog {
    static let swiftUIViews = words("""
        AngularGradient AnyView AsyncImage Button Canvas Capsule Circle Color ColorPicker
        ContainerRelativeShape ContentUnavailableView ControlGroup DatePicker DisclosureGroup Divider
        EditButton Ellipse EllipticalGradient EmptyView EquatableView ForEach Form Gauge GeometryReader
        Grid GridRow Group GroupBox HStack HelpLink Image KeyframeAnimator Label LabeledContent LazyHGrid
        LazyHStack LazyVGrid LazyVStack LinearGradient Link List Menu MeshGradient MultiDatePicker
        NavigationLink NavigationSplitView NavigationStack NavigationView OutlineGroup PasteButton Path
        PhaseAnimator Picker ProgressView RadialGradient Rectangle RenameButton RoundedRectangle
        ScrollView ScrollViewReader SecureField Section ShareLink Slider Spacer Stepper Tab TabSection
        TabView Table TableColumn TableRow Text TextEditor TextField TextFieldLink TimelineView Toggle
        UnevenRoundedRectangle VStack ViewThatFits ZStack ConcentricRectangle GlassEffectContainer
        """)

    static let swiftUITypes = words("""
        App Scene WindowGroup Window Settings DocumentGroup MenuBarExtra ImmersiveSpace UtilityWindow
        Commands CommandMenu CommandGroup CommandGroupPlacement
        View ViewModifier ModifiedContent EmptyModifier ViewBuilder SceneBuilder ToolbarContentBuilder
        CommandsBuilder TableColumnBuilder TableRowBuilder
        State Binding StateObject ObservedObject EnvironmentObject Environment EnvironmentValues
        EnvironmentKey AppStorage SceneStorage FocusState FocusedValue FocusedBinding FocusedObject
        FocusedValueKey FocusedValues Namespace GestureState ScaledMetric Bindable FetchRequest
        FetchedResults SectionedFetchRequest SectionedFetchResults UIApplicationDelegateAdaptor
        NSApplicationDelegateAdaptor WKApplicationDelegateAdaptor AccessibilityFocusState DynamicProperty
        PreferenceKey ObservableObject GridItem TupleView
        Font Alignment HorizontalAlignment VerticalAlignment AlignmentID Edge EdgeInsets Axis Angle
        Anchor UnitPoint ContentMode Layout LayoutSubviews LayoutSubview Subviews ProposedViewSize ViewDimensions
        LayoutValueKey AnyLayout HStackLayout VStackLayout ZStackLayout SafeAreaRegions CoordinateSpace
        NamedCoordinateSpace CoordinateSpaceProtocol GeometryProxy ScrollViewProxy ScrollPosition
        ScrollTargetBehavior ViewAlignedScrollTargetBehavior PagingScrollTargetBehavior ScrollGeometry
        ScrollPhase ScrollIndicatorVisibility ScrollDismissesKeyboardMode ScrollBounceBehavior
        ScrollTransitionPhase ScrollTransitionConfiguration ScrollAnchorRole
        Gradient AnyGradient ShapeStyle AnyShapeStyle HierarchicalShapeStyle Material ImagePaint
        ForegroundStyle BackgroundStyle TintShapeStyle SeparatorShapeStyle SelectionShapeStyle Shape
        InsettableShape AnyShape OffsetShape RotatedShape ScaledShape TransformedShape StrokeStyle
        FillStyle RoundedCornerStyle RectangleCornerRadii Glass
        Animation AnyTransition Transition Transaction Spring UnitCurve Animatable AnimatablePair
        EmptyAnimatableData VectorArithmetic ContentTransition CustomAnimation AnimationContext
        KeyframeTrack LinearKeyframe SpringKeyframe CubicKeyframe MoveKeyframe KeyframeTimeline
        MatchedGeometryProperties GeometryEffect AnimatableModifier ProjectionTransform
        Gesture TapGesture SpatialTapGesture LongPressGesture DragGesture MagnificationGesture
        MagnifyGesture RotationGesture RotateGesture SimultaneousGesture SequenceGesture ExclusiveGesture
        GestureMask AnyGesture
        ScenePhase ColorScheme ColorSchemeContrast ColorRenderingMode BlendMode DynamicTypeSize
        LegibilityWeight LayoutDirection UserInterfaceSizeClass RedactionReasons Visibility Prominence
        ControlSize ButtonRole ButtonBorderShape KeyboardShortcut KeyEquivalent EventModifiers
        SubmitLabel SubmitTriggers TextInputAutocapitalization TextAlignment LocalizedStringKey
        SymbolRenderingMode SymbolVariants AccessibilityTraits AccessibilityActionKind
        AccessibilityChildBehavior AccessibilityAdjustmentDirection HorizontalEdge VerticalEdge
        ContentShapeKinds MenuOrder SearchFieldPlacement ToolbarItem ToolbarItemGroup ToolbarTitleMenu
        ToolbarItemPlacement ToolbarContent ToolbarRole ToolbarPlacement ToolbarSpacer ContentSizeCategory
        ToolbarTitleDisplayMode NavigationPath NavigationSplitViewVisibility NavigationSplitViewColumn
        NavigationBarItem PresentationDetent PresentationMode PresentationAdaptation
        PresentationBackgroundInteraction PresentationContentInteraction PresentationSizing EditMode
        OpenURLAction DismissAction RefreshAction OpenWindowAction DismissWindowAction
        OpenImmersiveSpaceAction DismissSearchAction NewDocumentAction ImageRenderer GraphicsContext
        FileDocument ReferenceFileDocument FileDocumentConfiguration ReadConfiguration
        WriteConfiguration SharePreview
        TimelineSchedule PeriodicTimelineSchedule EveryMinuteTimelineSchedule AnimationTimelineSchedule
        ExplicitTimelineSchedule
        ButtonStyle PrimitiveButtonStyle ButtonStyleConfiguration PrimitiveButtonStyleConfiguration
        ToggleStyle ToggleStyleConfiguration SwitchToggleStyle ButtonToggleStyle CheckboxToggleStyle
        DefaultToggleStyle LabelStyle LabelStyleConfiguration ListStyle PlainListStyle
        InsetGroupedListStyle GroupedListStyle SidebarListStyle InsetListStyle DefaultListStyle
        CarouselListStyle PickerStyle SegmentedPickerStyle WheelPickerStyle MenuPickerStyle
        InlinePickerStyle DefaultPickerStyle NavigationLinkPickerStyle PalettePickerStyle TextFieldStyle
        RoundedBorderTextFieldStyle PlainTextFieldStyle DefaultTextFieldStyle ProgressViewStyle
        CircularProgressViewStyle LinearProgressViewStyle DefaultProgressViewStyle DatePickerStyle
        GraphicalDatePickerStyle CompactDatePickerStyle WheelDatePickerStyle DefaultDatePickerStyle
        TabViewStyle PageTabViewStyle DefaultTabViewStyle IndexViewStyle PageIndexViewStyle
        NavigationViewStyle StackNavigationViewStyle DoubleColumnNavigationViewStyle
        DefaultNavigationViewStyle PlainButtonStyle BorderlessButtonStyle BorderedButtonStyle
        BorderedProminentButtonStyle DefaultButtonStyle GaugeStyle MenuStyle LabeledContentStyle
        FormStyle GroupedFormStyle ColumnsFormStyle GroupBoxStyle DisclosureGroupStyle ControlGroupStyle
        NavigationSplitViewStyle TableStyle
        UIViewRepresentable UIViewControllerRepresentable NSViewRepresentable
        NSViewControllerRepresentable UIHostingController UIHostingConfiguration NSHostingController
        NSHostingView UIViewRepresentableContext UIViewControllerRepresentableContext
        PreviewProvider PreviewDevice PreviewLayout PreviewPlatform
        Alert ActionSheet ContextMenu DropDelegate DropInfo DropProposal DropOperation
        """)

    // Instance methods on View, Text, Image, Shape, Path, Font, Animation, AnyTransition, Gesture,
    // ScrollViewProxy and layout subviews; free functions (`swiftUIFunctions`).
    static let swiftUIModifiers = words("""
        padding frame fixedSize layoutPriority offset position alignmentGuide aspectRatio scaledToFit
        scaledToFill ignoresSafeArea edgesIgnoringSafeArea safeAreaInset safeAreaPadding coordinateSpace
        zIndex containerRelativeFrame layoutValue geometryGroup contentMargins scenePadding
        foregroundColor foregroundStyle background backgroundStyle overlay border cornerRadius clipShape
        clipped mask shadow opacity blur brightness contrast saturation grayscale hueRotation colorInvert
        colorMultiply luminanceToAlpha blendMode compositingGroup drawingGroup tint accentColor
        preferredColorScheme colorScheme glassEffect glassEffectID backgroundExtensionEffect visualEffect
        containerShape contentShape hoverEffect
        font fontWeight fontWidth fontDesign bold italic underline strikethrough kerning tracking
        baselineOffset monospaced monospacedDigit lineLimit lineSpacing multilineTextAlignment
        truncationMode minimumScaleFactor allowsTightening textCase textSelection dynamicTypeSize
        privacySensitive redacted unredacted textScale typesettingLanguage
        resizable renderingMode interpolation antialiased symbolRenderingMode symbolVariant symbolEffect
        imageScale
        fill stroke strokeBorder trim inset rotation scale
        rotationEffect rotation3DEffect scaleEffect transformEffect projectionEffect
        animation transition matchedGeometryEffect contentTransition phaseAnimator keyframeAnimator
        transaction
        onTapGesture onLongPressGesture gesture simultaneousGesture highPriorityGesture allowsHitTesting
        disabled onHover focusable focused focusedValue focusSection onDrag onDrop draggable
        dropDestination onMove onDelete onInsert deleteDisabled moveDisabled contextMenu swipeActions
        refreshable searchable searchSuggestions searchScopes onSubmit submitLabel submitScope
        keyboardShortcut onKeyPress sensoryFeedback digitalCrownRotation defersSystemGestures
        persistentSystemOverlays scrollDismissesKeyboard onScrollGeometryChange onScrollPhaseChange
        onScrollVisibilityChange scrollPosition scrollTargetBehavior scrollTargetLayout scrollIndicators
        scrollDisabled scrollContentBackground scrollClipDisabled scrollBounceBehavior scrollTransition
        scrollEdgeEffectStyle defaultScrollAnchor
        onAppear onDisappear task onChange onReceive onOpenURL onContinueUserActivity userActivity
        handlesExternalEvents onPreferenceChange preference transformPreference anchorPreference
        backgroundPreferenceValue overlayPreferenceValue onGeometryChange
        sheet fullScreenCover popover alert confirmationDialog actionSheet fileImporter fileExporter
        fileMover inspector inspectorColumnWidth presentationDetents presentationDragIndicator
        presentationBackground presentationCornerRadius presentationBackgroundInteraction
        presentationCompactAdaptation presentationContentInteraction presentationSizing
        interactiveDismissDisabled dialogIcon
        navigationTitle navigationBarTitle navigationBarTitleDisplayMode navigationBarHidden
        navigationBarBackButtonHidden navigationBarItems navigationDestination navigationViewStyle
        navigationSplitViewStyle navigationSplitViewColumnWidth navigationSubtitle navigationTransition
        toolbar toolbarBackground toolbarColorScheme toolbarRole toolbarTitleMenu toolbarVisibility
        toolbarBackgroundVisibility toolbarTitleDisplayMode statusBar statusBarHidden tabItem tabViewStyle
        tabBarMinimizeBehavior tabViewBottomAccessory badge indexViewStyle
        listStyle listRowBackground listRowInsets listRowSeparator listRowSeparatorTint
        listSectionSeparator listRowSpacing listSectionSpacing listItemTint headerProminence formStyle
        labelsHidden labelStyle buttonStyle buttonBorderShape toggleStyle pickerStyle datePickerStyle
        textFieldStyle progressViewStyle gaugeStyle menuStyle groupBoxStyle disclosureGroupStyle
        controlGroupStyle labeledContentStyle tableStyle controlSize menuIndicator menuOrder
        buttonRepeatBehavior
        keyboardType textContentType textInputAutocapitalization autocapitalization
        autocorrectionDisabled disableAutocorrection
        environment environmentObject transformEnvironment id tag equatable hidden help
        accessibilityLabel accessibilityHint accessibilityValue accessibilityHidden
        accessibilityIdentifier accessibilityElement accessibilityAddTraits accessibilityRemoveTraits
        accessibilityAction accessibilityAdjustableAction accessibilitySortPriority
        accessibilityShowsLargeContentViewer accessibility accessibilityRepresentation
        accessibilityInputLabels accessibilityFocused
        flipsForRightToLeftLayoutDirection widgetURL containerBackground invalidatableContent
        commands windowStyle windowResizability defaultSize backgroundTask windowToolbarStyle
        immersionStyle previewLayout previewDevice previewDisplayName previewInterfaceOrientation
        modifier matchedTransitionSource safeAreaBar focusEffectDisabled menuBarExtraStyle
        focusedSceneValue gridColumnAlignment gridCellColumns gridCellAnchor gridCellUnsizedAxes
        onChanged onEnded updating sequenced simultaneously exclusively
        combined repeatForever repeatCount delay speed weight leading smallCaps interactive
        move addLine addLines addArc addCurve addQuadCurve addRect addRoundedRect addEllipse addPath
        closeSubpath trimmedPath scrollTo place replacingUnspecifiedDimensions
        """)

    static let swiftUIFunctions = words("withAnimation withTransaction")

    // Attribute name -> owning module. Unlisted attributes are reported as third-party or app code.
    static let attributes: [String: String] = {
        var map: [String: String] = [:]
        let groups = [
            "SwiftUI": """
                State Binding StateObject ObservedObject EnvironmentObject Environment AppStorage
                SceneStorage FocusState FocusedValue FocusedBinding FocusedObject Namespace GestureState
                ScaledMetric Bindable FetchRequest SectionedFetchRequest UIApplicationDelegateAdaptor
                NSApplicationDelegateAdaptor WKApplicationDelegateAdaptor AccessibilityFocusState Entry
                Previewable ViewBuilder SceneBuilder ToolbarContentBuilder CommandsBuilder
                TableColumnBuilder TableRowBuilder FocusState.Binding AccessibilityFocusState.Binding
                Animatable AnimatableIgnored
                """,
            "Observation": "Observable ObservationIgnored ObservationTracked",
            "SwiftData": "Model Query Attribute Relationship Transient ModelActor",
            "Combine": "Published",
            "AppIntents": "Parameter Property IntentParameterDependency AppShortcutsBuilder",
            "WidgetKit": "WidgetBundleBuilder",
            "Charts": "ChartContentBuilder AxisContentBuilder",
            "FoundationModels": "Generable Guide",
            "ObjC": """
                objc objcMembers IBOutlet IBAction IBInspectable IBDesignable IBSegueAction NSManaged
                NSCopying
                """,
            "Swift": """
                main MainActor available escaping autoclosure discardableResult inlinable usableFromInline
                frozen propertyWrapper resultBuilder dynamicMemberLookup dynamicCallable globalActor
                preconcurrency unchecked retroactive testable Sendable unknown convention _exported
                _implementationOnly _spi backDeployed nonobjc UIApplicationMain NSApplicationMain
                warn_unqualified_access isolated concurrent inline attached freestanding TaskLocal
                _disfavoredOverload _transparent _silgen_name
                """,
        ]
        for (module, names) in groups {
            for name in words(names) { map[name] = module }
        }
        return map
    }()

    // Built-in literal macros that say nothing about framework use.
    static let builtinMacros = words("""
        file fileID filePath line column function dsohandle warning error selector keyPath
        colorLiteral imageLiteral fileLiteral externalMacro
        """)

    // Freestanding macros of Apple modules; other macros are third-party or app code.
    static let macros = [
        "Preview": "SwiftUI", "Predicate": "Foundation", "Expression": "Foundation", "Rule": "TipKit",
        "Index": "SwiftData", "Unique": "SwiftData",
    ]

    // How each Objective-C construct fares with Swift 6.4.1 on Linux, measured with swiftc
    // (P0-08 report). "ok" means it compiles and links.
    static let objcOnLinux = [
        "@objc": "error", "@objcMembers": "error", "#selector": "error", "#keyPath": "error",
        "Selector": "error", "@IBOutlet": "error", "KVO": "error", "@NSManaged": "link",
        "@IBAction": "ok", "@IBInspectable": "ok", "@IBDesignable": "ok", "@IBSegueAction": "ok",
        "@NSCopying": "ok", "dynamic": "ok", "NSObject subclass": "ok",
    ]

    // Failing constructs a SwiftSyntax source rewrite can remove (plan, direction 6, short term).
    static let objcRewritable = words("@objc @objcMembers #selector #keyPath Selector @IBOutlet")

    // Package identities that only run at build or test time, not in the app.
    static let devPackages = words("""
        swiftlint swiftlintplugins swiftlintplugin swiftformat swiftgen licenseplist
        swift-snapshot-testing viewinspector quick nimble ohhttpstubs mocker rxblocking
        swift-docc-plugin
        """)

    // NS-prefixed names that belong to UIKit on iOS; any other UI-prefixed name counts as UIKit too.
    static let uiKitNSTypes = words("""
        NSLayoutConstraint NSLayoutAnchor NSLayoutXAxisAnchor NSLayoutYAxisAnchor NSLayoutDimension
        NSDirectionalEdgeInsets NSDirectionalRectEdge NSTextAttachment NSParagraphStyle
        NSMutableParagraphStyle NSShadow NSTextContainer NSLayoutManager NSTextStorage NSUnderlineStyle
        NSDiffableDataSourceSnapshot NSDiffableDataSourceSectionSnapshot NSCollectionLayoutSection
        NSCollectionLayoutItem NSCollectionLayoutGroup NSCollectionLayoutSize NSCollectionLayoutDimension
        NSCollectionLayoutBoundarySupplementaryItem NSCollectionLayoutEdgeSpacing
        NSCollectionLayoutSpacing NSCollectionLayoutDecorationItem NSCollectionLayoutAnchor
        NSCollectionLayoutEnvironment NSCollectionLayoutSupplementaryItem NSTextAlignment
        NSLineBreakMode NSDataAsset
        """)

    // Free functions that a bare call inside a UIKit subclass must not be mistaken for.
    static let swiftGlobals = words("""
        print debugPrint dump min max abs zip stride sequence repeatElement swap type fatalError
        precondition preconditionFailure assert assertionFailure withAnimation withTransaction
        withCheckedContinuation withCheckedThrowingContinuation withUnsafeContinuation
        withUnsafeThrowingContinuation withTaskGroup withThrowingTaskGroup withDiscardingTaskGroup
        withUnsafePointer withUnsafeMutablePointer withUnsafeBytes withExtendedLifetime
        withObservationTracking numericCast unsafeBitCast isKnownUniquelyReferenced autoreleasepool
        round floor ceil sqrt pow sin cos tan atan atan2 exp log log2 log10 fabs fmod arc4random
        arc4random_uniform
        """)

    // Inherited UIKit properties used without a local declaration (`view.addSubview`).
    // ponytail: fixed map, per-class lookup if member attribution needs to be exact.
    static let uiKitInheritedProperties: [String: String] = [
        "view": "UIView", "navigationController": "UINavigationController",
        "navigationItem": "UINavigationItem", "tabBarController": "UITabBarController",
        "contentView": "UIView", "traitCollection": "UITraitCollection",
    ]

    // Apple SDK and toolchain modules, grouped by where the plan covers them on Linux.
    // "other-platform" modules belong to macOS, watchOS or tvOS targets and are not built for iOS.
    static let appleModules: [String: String] = {
        var map: [String: String] = [:]
        let groups = [
            "toolchain": """
                Foundation FoundationNetworking Dispatch Observation RegexBuilder Synchronization
                Distributed Swift _Concurrency XCTest Testing
                """,
            "OpenKit": "SwiftUI SwiftUICore UIKit CoreGraphics QuartzCore",
            "shim": "os OSLog Darwin CryptoKit UniformTypeIdentifiers MobileCoreServices SQLite3",
            "other-platform": """
                AppKit Cocoa Carbon IOKit ServiceManagement WatchKit ClockKit ApplicationServices OpenGL
                ScreenCaptureKit SystemExtensions TVServices TVUIKit
                """,
            "P1-17": """
                Combine StoreKit PhotosUI CoreLocation UserNotifications LocalAuthentication Security
                """,
            "E2-05": "SwiftData CoreData",
            "E2-10": "MapKit WebKit AVKit AVFoundation SafariServices",
            "Charts": "Charts",
            "none": """
                WidgetKit ActivityKit AppIntents CloudKit HealthKit HealthKitUI EventKit EventKitUI
                Contacts ContactsUI CoreMotion CoreBluetooth CoreNFC CoreHaptics CoreImage CoreML Vision
                VisionKit NaturalLanguage Speech ARKit RealityKit RealityFoundation SceneKit SpriteKit
                GameKit GameplayKit GameController Metal MetalKit MetalPerformanceShaders MessageUI
                Messages AuthenticationServices Network NetworkExtension SystemConfiguration
                CoreTransferable CoreSpotlight Intents IntentsUI QuickLook
                QuickLookThumbnailing PDFKit PencilKit TipKit FamilyControls ManagedSettings
                ManagedSettingsUI DeviceActivity MediaPlayer MusicKit ShazamKit AudioToolbox CoreAudio
                CoreAudioKit CoreMedia CoreVideo ImageIO Accelerate CoreText CoreServices
                BackgroundTasks WatchConnectivity
                Social Accounts AdSupport AppTrackingTransparency StoreKitTest
                LinkPresentation FoundationModels Translation CarPlay CallKit PushKit
                MultipeerConnectivity GroupActivities SharedWithYou ExtensionKit CommonCrypto Compression
                Photos AVRouting AVFAudio SoundAnalysis CoreMIDI AppClip Symbols CryptoTokenKit
                DeveloperToolsSupport ExposureNotification DeviceCheck MetricKit NearbyInteraction
                SensorKit HomeKit Matter ScreenTime CoreAudioTypes ImagePlayground JavaScriptCore
                ColorSync OpenGLES GLKit CoreTelephony SafetyKit WeatherKit MLCompute CreateML
                Spatial RealityKitContent VideoToolbox simd NotificationCenter ObjectiveC PassKit
                _PassKit_SwiftUI Playgrounds UserNotificationsUI MachO MediaAccessibility dnssd
                """,
        ]
        for (group, names) in groups {
            for name in words(names) { map[name] = group }
        }
        return map
    }()

    static func isUIKitType(_ name: String) -> Bool {
        guard !swiftUITypes.contains(name) else { return false }
        if uiKitNSTypes.contains(name) { return true }
        return hasPrefix("UI", name)
    }

    static func isQuartzCoreType(_ name: String) -> Bool { hasPrefix("CA", name) }

    // `UI` followed by an uppercase letter: UIView yes, UInt8 no.
    private static func hasPrefix(_ prefix: String, _ name: String) -> Bool {
        name.hasPrefix(prefix) && name.dropFirst(prefix.count).first?.isUppercase == true
    }
}
