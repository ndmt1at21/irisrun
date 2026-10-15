import SwiftParser
import SwiftSyntax

/// Syntax facts from one Swift file. Attribution to SwiftUI or UIKit happens per app
/// (`Analysis.swift`), because it depends on the names the whole app declares.
struct FileFacts: Sendable {
    var imports: Set<String> = []
    /// Capitalized names in type or expression position (`VStack`, `UIView`, `Color`).
    var identifiers: [String: Int] = [:]
    /// Methods called on an instance (`x.padding()`) or on implicit self (`padding()`).
    var calls: [String: Int] = [:]
    /// "Type.member" where Type is a static base or the declared type of a variable.
    var typedMembers: [String: Int] = [:]
    /// "EnclosingType.member" through `self.` or `super.`.
    var selfMembers: [String: Int] = [:]
    /// "EnclosingType.member" through bare calls (`present(vc, animated: true)`).
    var implicitMembers: [String: Int] = [:]
    /// "EnclosingType.member" for `override` declarations.
    var overrides: [String: Int] = [:]
    var attributes: [String: Int] = [:]
    var macros: [String: Int] = [:]
    var environmentKeys: [String: Int] = [:]
    var objc: [String: Int] = [:]
    var sfSymbols: [String: Int] = [:]
    var entryPoints: Set<String> = []
    var superclasses: [String: String] = [:]
    var declaredTypes: Set<String> = []
    /// "Type.member" declared by the app, including members added to framework types in extensions.
    var declaredMembers: Set<String> = []
    /// Locals, parameters and global functions: never attributed to a framework type.
    var declaredLocals: Set<String> = []
    var lines = 0
}

func scan(source: String) -> FileFacts {
    let visitor = Scanner()
    visitor.facts.lines = source.utf8.count(where: { $0 == UInt8(ascii: "\n") })
    visitor.walk(Parser.parse(source: source))
    visitor.resolveVariableMembers()
    return visitor.facts
}

/// Conformance of a `@main` type -> kind of entry point.
private let entryKinds = [
    "App": "SwiftUI App", "UIApplicationDelegate": "UIApplicationDelegate", "WidgetBundle": "WidgetKit",
    "Widget": "WidgetKit", "NSApplicationDelegate": "AppKit",
]

private final class Scanner: SyntaxVisitor {
    var facts = FileFacts()
    private var typeStack: [String] = []
    private var variableTypes: [String: String] = [:]
    private var variableMembers: [String: [String: Int]] = [:]

    init() { super.init(viewMode: .sourceAccurate) }

    // MARK: Imports and type references

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        if let module = node.path.first?.name.text { facts.imports.insert(module) }
        return .skipChildren
    }

    /// `#if canImport(UIKit)` and `#if DEBUG` name build conditions, not APIs: skip the condition.
    override func visit(_ node: IfConfigClauseSyntax) -> SyntaxVisitorContinueKind {
        if let elements = node.elements { walk(elements) }
        return .skipChildren
    }

    override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        countIdentifier(node.name.text)
        return .visitChildren
    }

    override func visit(_ node: MemberTypeSyntax) -> SyntaxVisitorContinueKind {
        // `SwiftUI.Text` names a framework type; `Font.Weight` is counted through `Font`.
        if let base = node.baseType.as(IdentifierTypeSyntax.self), facts.imports.contains(base.name.text) {
            countIdentifier(node.name.text)
            return .skipChildren
        }
        return .visitChildren
    }

    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        if node.keyPathInParent != \MemberAccessExprSyntax.declName { countIdentifier(node.baseName.text) }
        return .visitChildren
    }

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        guard let base = node.base else { return .visitChildren }
        let member = node.declName.baseName.text
        if base.is(SuperExprSyntax.self) {
            addSelfMember(member)
        } else if let name = variableName(base) {
            if name == "self" {
                addSelfMember(member)
            } else if name.first?.isUppercase == true {
                if facts.imports.contains(name) {
                    countIdentifier(member)
                } else {
                    facts.typedMembers["\(name).\(member)", default: 0] += 1
                }
            } else {
                variableMembers[name, default: [:]][member, default: 0] += 1
            }
        }
        return .visitChildren
    }

    // MARK: Calls

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        if let callee = node.calledExpression.as(MemberAccessExprSyntax.self) {
            let name = callee.declName.baseName.text
            if let base = callee.base {
                if !isTypeName(base) { facts.calls[name, default: 0] += 1 }
            } else if isPostfixIfConfigHead(node) {
                facts.calls[name, default: 0] += 1
            }
            if name == "observe", node.arguments.first?.expression.is(KeyPathExprSyntax.self) == true {
                facts.objc["KVO", default: 0] += 1
            }
        } else if let callee = node.calledExpression.as(DeclReferenceExprSyntax.self) {
            let name = callee.baseName.text
            if name.first?.isLowercase == true {
                facts.calls[name, default: 0] += 1
                if let type = typeStack.last { facts.implicitMembers["\(type).\(name)", default: 0] += 1 }
            }
        }
        for argument in node.arguments {
            switch argument.label?.text {
            case "systemName", "systemImage":
                let literal = argument.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
                facts.sfSymbols[literal ?? "(dynamic)", default: 0] += 1
            case "forKeyPath":
                facts.objc["KVO", default: 0] += 1
            default:
                break
            }
        }
        return .visitChildren
    }

    // MARK: Attributes, macros, modifiers

    override func visit(_ node: AttributeSyntax) -> SyntaxVisitorContinueKind {
        let name = attributeName(node.attributeName)
        facts.attributes[name, default: 0] += 1
        if Catalog.attributes[name] == "ObjC" { facts.objc["@" + name, default: 0] += 1 }
        if name == "Environment", case .argumentList(let arguments) = node.arguments,
            let expression = arguments.first?.expression
        {
            let key =
                expression.as(KeyPathExprSyntax.self)?.components.last?.component
                .as(KeyPathPropertyComponentSyntax.self)?.declName.baseName.text
            facts.environmentKeys[key.map { "\\." + $0 } ?? "(object)", default: 0] += 1
        }
        return .skipChildren
    }

    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        addMacro(node.macroName.text)
        return .visitChildren
    }

    override func visit(_ node: MacroExpansionDeclSyntax) -> SyntaxVisitorContinueKind {
        addMacro(node.macroName.text)
        return .visitChildren
    }

    override func visit(_ node: DeclModifierSyntax) -> SyntaxVisitorContinueKind {
        if node.name.tokenKind == .keyword(.dynamic) { facts.objc["dynamic", default: 0] += 1 }
        return .skipChildren
    }

    // MARK: Declarations

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        declareType(name, attributes: node.attributes, inheritance: node.inheritanceClause)
        if let superclass = node.inheritanceClause?.inheritedTypes.first.flatMap({ typeName($0.type) }) {
            facts.superclasses[name] = superclass
            if superclass == "NSObject" { facts.objc["NSObject subclass", default: 0] += 1 }
        }
        typeStack.append(name)
        return .visitChildren
    }

    override func visitPost(_ node: ClassDeclSyntax) { typeStack.removeLast() }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        declareType(node.name.text, attributes: node.attributes, inheritance: node.inheritanceClause)
        typeStack.append(node.name.text)
        return .visitChildren
    }

    override func visitPost(_ node: StructDeclSyntax) { typeStack.removeLast() }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        declareType(node.name.text, attributes: node.attributes, inheritance: node.inheritanceClause)
        typeStack.append(node.name.text)
        return .visitChildren
    }

    override func visitPost(_ node: EnumDeclSyntax) { typeStack.removeLast() }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        declareType(node.name.text, attributes: node.attributes, inheritance: node.inheritanceClause)
        typeStack.append(node.name.text)
        return .visitChildren
    }

    override func visitPost(_ node: ActorDeclSyntax) { typeStack.removeLast() }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        declareType(node.name.text, attributes: node.attributes, inheritance: node.inheritanceClause)
        typeStack.append(node.name.text)
        return .visitChildren
    }

    override func visitPost(_ node: ProtocolDeclSyntax) { typeStack.removeLast() }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        typeStack.append(typeName(node.extendedType) ?? "?")
        return .visitChildren
    }

    override func visitPost(_ node: ExtensionDeclSyntax) { typeStack.removeLast() }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        facts.declaredTypes.insert(node.name.text)
        return .visitChildren
    }

    override func visit(_ node: AssociatedTypeDeclSyntax) -> SyntaxVisitorContinueKind {
        facts.declaredTypes.insert(node.name.text)
        return .visitChildren
    }

    override func visit(_ node: GenericParameterSyntax) -> SyntaxVisitorContinueKind {
        facts.declaredTypes.insert(node.name.text)
        return .visitChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        declareMember(node.name.text, modifiers: node.modifiers, isMember: node.parent?.is(MemberBlockItemSyntax.self) == true)
        return .visitChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        let isMember = node.parent?.is(MemberBlockItemSyntax.self) == true
        for binding in node.bindings {
            guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { continue }
            declareMember(name, modifiers: node.modifiers, isMember: isMember)
            if let type = binding.typeAnnotation.flatMap({ typeName($0.type) }) ?? binding.initializer.flatMap({ initializedType($0.value) }) {
                variableTypes[name] = type
            }
        }
        return .visitChildren
    }

    override func visit(_ node: OptionalBindingConditionSyntax) -> SyntaxVisitorContinueKind {
        if let name = node.pattern.as(IdentifierPatternSyntax.self)?.identifier.text {
            facts.declaredLocals.insert(name)
            if let type = node.initializer.flatMap({ initializedType($0.value) }) { variableTypes[name] = type }
        }
        return .visitChildren
    }

    override func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
        let name = (node.secondName ?? node.firstName).text
        facts.declaredLocals.insert(name)
        if let type = typeName(node.type) { variableTypes[name] = type }
        return .visitChildren
    }

    override func visit(_ node: ClosureShorthandParameterSyntax) -> SyntaxVisitorContinueKind {
        facts.declaredLocals.insert(node.name.text)
        return .visitChildren
    }

    override func visit(_ node: ClosureParameterSyntax) -> SyntaxVisitorContinueKind {
        facts.declaredLocals.insert((node.secondName ?? node.firstName).text)
        return .visitChildren
    }

    // MARK: Helpers

    /// Resolves `label.text` once every variable in the file is known.
    // ponytail: one type per variable name per file, scope-aware lookup if collisions matter.
    func resolveVariableMembers() {
        for (variable, members) in variableMembers {
            guard let type = variableTypes[variable] ?? inheritedType(variable) else { continue }
            for (member, count) in members { facts.typedMembers["\(type).\(member)", default: 0] += count }
        }
    }

    private func inheritedType(_ variable: String) -> String? {
        facts.imports.contains("UIKit") ? Catalog.uiKitInheritedProperties[variable] : nil
    }

    private func countIdentifier(_ name: String) {
        guard name.first?.isUppercase == true else { return }
        facts.identifiers[name, default: 0] += 1
        if name == "Selector" { facts.objc[name, default: 0] += 1 }
    }

    /// `@SwiftUI.State` -> `State`, `@FocusState<Field?>.Binding` -> `FocusState.Binding`.
    private func attributeName(_ type: TypeSyntax) -> String {
        if let member = type.as(MemberTypeSyntax.self) {
            let base = attributeName(member.baseType)
            return facts.imports.contains(base) ? member.name.text : "\(base).\(member.name.text)"
        }
        return type.as(IdentifierTypeSyntax.self)?.name.text ?? type.trimmedDescription
    }

    private func addSelfMember(_ member: String) {
        if let type = typeStack.last { facts.selfMembers["\(type).\(member)", default: 0] += 1 }
    }

    private func addMacro(_ name: String) {
        if name == "selector" || name == "keyPath" { facts.objc["#" + name, default: 0] += 1 }
        facts.macros[name, default: 0] += 1
    }

    private func declareType(_ name: String, attributes: AttributeListSyntax, inheritance: InheritanceClauseSyntax?) {
        facts.declaredTypes.insert(name)
        let attributeNames = Set(attributes.compactMap { $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription })
        let inherited = inheritance?.inheritedTypes.compactMap { typeName($0.type) } ?? []
        if attributeNames.contains("main") || attributeNames.contains("UIApplicationMain") {
            facts.entryPoints.insert(inherited.lazy.compactMap { entryKinds[$0] }.first ?? "other")
        }
        if inherited.contains("UIWindowSceneDelegate") { facts.entryPoints.insert("UIWindowSceneDelegate") }
    }

    private func declareMember(_ name: String, modifiers: DeclModifierListSyntax, isMember: Bool) {
        let type = typeStack.last ?? "?"
        if modifiers.contains(where: { $0.name.tokenKind == .keyword(.override) }) {
            facts.overrides["\(type).\(name)", default: 0] += 1
        } else if isMember {
            facts.declaredMembers.insert("\(type).\(name)")
        } else {
            facts.declaredLocals.insert(name)
        }
    }

    /// `x`, `x?`, `x!` and `self.x` all name the variable `x`; `self` names itself.
    private func variableName(_ expression: ExprSyntax) -> String? {
        var expression = expression
        while true {
            if let wrapped = expression.as(OptionalChainingExprSyntax.self) {
                expression = wrapped.expression
            } else if let wrapped = expression.as(ForceUnwrapExprSyntax.self) {
                expression = wrapped.expression
            } else {
                break
            }
        }
        if let reference = expression.as(DeclReferenceExprSyntax.self) { return reference.baseName.text }
        if let member = expression.as(MemberAccessExprSyntax.self),
            member.base?.as(DeclReferenceExprSyntax.self)?.baseName.tokenKind == .keyword(.self)
        {
            return member.declName.baseName.text
        }
        return nil
    }

    private func isTypeName(_ expression: ExprSyntax) -> Bool {
        expression.as(DeclReferenceExprSyntax.self)?.baseName.text.first?.isUppercase == true
    }

    /// `.padding()` without a base is a modifier at the head of a `#if os(iOS) … #endif` postfix chain.
    private func isPostfixIfConfigHead(_ node: FunctionCallExprSyntax) -> Bool {
        var current = Syntax(node)
        while let parent = current.parent {
            if parent.is(IfConfigClauseSyntax.self) {
                return parent.parent?.parent?.parent?.is(PostfixIfConfigExprSyntax.self) == true
            }
            guard parent.is(MemberAccessExprSyntax.self) || parent.is(FunctionCallExprSyntax.self) else { return false }
            current = parent
        }
        return false
    }

    private func typeName(_ type: TypeSyntax) -> String? {
        if let identifier = type.as(IdentifierTypeSyntax.self) { return identifier.name.text }
        if let member = type.as(MemberTypeSyntax.self) { return member.name.text }
        if let optional = type.as(OptionalTypeSyntax.self) { return typeName(optional.wrappedType) }
        if let optional = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) { return typeName(optional.wrappedType) }
        if let attributed = type.as(AttributedTypeSyntax.self) { return typeName(attributed.baseType) }
        if let opaque = type.as(SomeOrAnyTypeSyntax.self) { return typeName(opaque.constraint) }
        return nil
    }

    /// `UILabel()`, `UILabel.init(...)`, `x as? MyCell`.
    private func initializedType(_ expression: ExprSyntax) -> String? {
        if let cast = expression.as(AsExprSyntax.self) { return typeName(cast.type) }
        guard let call = expression.as(FunctionCallExprSyntax.self) else { return nil }
        var callee = call.calledExpression
        if let member = callee.as(MemberAccessExprSyntax.self), member.declName.baseName.text == "init", let base = member.base {
            callee = base
        }
        let name = callee.as(DeclReferenceExprSyntax.self)?.baseName.text
        return name?.first?.isUppercase == true ? name : nil
    }
}
