//
//  IULIAInitializer.swift
//  MoveGen
//
//  Created by Franklin Schrans on 4/27/18.
//

import AST
import MoveIR

/// Generates code for a contract initializer.
struct MoveContractInitializer {
  var initializerDeclaration: SpecialDeclaration
  var typeIdentifier: AST.Identifier

  /// The properties defined in the enclosing type. The default values of each property will be set in the initializer.
  var propertiesInEnclosingType: [AST.VariableDeclaration]

  var callerBinding: AST.Identifier?
  var callerProtections: [CallerProtection]

  var environment: Environment

  var isContractFunction = false

  var contract: MoveContract

  var parameterNames: [String] {
    let fc = FunctionContext(environment: environment,
                             scopeContext: scopeContext,
                             enclosingTypeName: typeIdentifier.name,
                             isInStructFunction: !isContractFunction)
    return initializerDeclaration.explicitParameters.map {
      MoveIdentifier(identifier: $0.identifier, position: .left).rendered(functionContext: fc).description
    }
  }

  var parameterValues: [String] {
    let fc = FunctionContext(environment: environment,
                             scopeContext: scopeContext,
                             enclosingTypeName: typeIdentifier.name,
                             isInStructFunction: !isContractFunction)
    return initializerDeclaration.explicitParameters.map {
      MoveIdentifier(identifier: $0.identifier).rendered(functionContext: fc, forceMove: true).description
    }
  }

  var parameterIRTypes: [MoveIR.`Type`] {
    let fc = FunctionContext(environment: environment,
                             scopeContext: scopeContext,
                             enclosingTypeName: typeIdentifier.name,
                             isInStructFunction: !isContractFunction)
    return initializerDeclaration.explicitParameters.map {
      CanonicalType(from: $0.type.rawType,
                    environment: environment)!.render(functionContext: fc)
    }
  }

  /// The function's parameters and caller binding, as variable declarations in a `ScopeContext`.
  var scopeContext: ScopeContext {
    var localVariables = [AST.VariableDeclaration]()
    if let callerBinding = callerBinding {
      let variableDeclaration = VariableDeclaration(modifiers: [],
                                                    declarationToken: nil,
                                                    identifier: callerBinding,
                                                    type: Type(inferredType: .basicType(.address),
                                                               identifier: callerBinding))
      localVariables.append(variableDeclaration)
    }
    return ScopeContext(parameters: initializerDeclaration.signature.parameters, localVariables: localVariables)
  }

  func rendered() -> String {
    let parameters = zip(parameterNames, parameterIRTypes).map { param in
      let (name, type): (String, MoveIR.`Type`) = param
      return "\(name): \(type)"
    }.joined(separator: ", ")

    let body = MoveInitializerBody(
        declaration: initializerDeclaration,
        typeIdentifier: typeIdentifier,
        callerBinding: callerBinding,
        callerProtections: callerProtections,
        environment: environment,
        properties: contract.contractDeclaration.variableDeclarations
    ).rendered()

    return """
           new(\(parameters)): Self.T {
             \(body.indented(by: 2))
           }

           public publish(\(parameters)) {
             move_to_sender<T>(Self.new(\(parameterValues.joined(separator: ", "))));
             return;
           }

           public get(addr: address): &mut Self.T {
             return borrow_global<T>(move(addr));
           }
           """
  }
}

struct MoveInitializerBody {
  var declaration: SpecialDeclaration
  var typeIdentifier: AST.Identifier

  var callerBinding: AST.Identifier?
  var callerProtections: [CallerProtection]

  var environment: Environment
  let properties: [AST.VariableDeclaration]

  /// The function's parameters and caller caller binding, as variable declarations in a `ScopeContext`.
  var scopeContext: ScopeContext {
    return declaration.scopeContext
  }

  init(declaration: SpecialDeclaration,
       typeIdentifier: AST.Identifier,
       callerBinding: AST.Identifier?,
       callerProtections: [CallerProtection],
       environment: Environment,
       properties: [AST.VariableDeclaration]) {
    self.declaration = declaration
    self.typeIdentifier = typeIdentifier
    self.callerProtections = callerProtections
    self.callerBinding = callerBinding
    self.environment = environment
    self.properties = properties
  }

  func rendered() -> String {
    let functionContext: FunctionContext = FunctionContext(environment: environment,
                                                           scopeContext: scopeContext,
                                                           enclosingTypeName: typeIdentifier.name,
                                                           isConstructor: true)
    return renderBody(declaration.body, functionContext: functionContext)
  }

  func renderMoveType(functionContext: FunctionContext) -> MoveIR.`Type` {
    return CanonicalType(
        from: AST.Type(identifier: typeIdentifier).rawType,
        environment: environment
    )!.render(functionContext: functionContext)
  }

  func renderBody<S: RandomAccessCollection & RangeReplaceableCollection>(_ statements: S,
                                                                          functionContext: FunctionContext) -> String
      where S.Element == AST.Statement, S.Index == Int {
    guard !statements.isEmpty else { return "" }
    var declarations = self.properties
    var statements = statements

    while !declarations.isEmpty {
      let property: AST.VariableDeclaration = declarations.removeFirst()
      let propertyType = CanonicalType(
          from: property.type.rawType,
          environment: environment
      )!.render(functionContext: functionContext)
      functionContext.emit(.expression(.variableDeclaration(
          MoveIR.VariableDeclaration((MoveSelf.prefix + property.identifier.name, propertyType))
      )))
    }

    var unassigned: [AST.Identifier] = properties.map { $0.identifier }

    while !(statements.isEmpty || unassigned.isEmpty) {
      let statement = statements.removeFirst()
      if case .expression(let expression) = statement,
         case .binaryExpression(let binary) = expression,
         case .punctuation(let op) = binary.op.kind,
         case .equal = op {
        switch binary.lhs {
        case .identifier(let identifier):
          if let type = identifier.enclosingType,
             type == typeIdentifier.name {
            unassigned = unassigned.filter { $0.name != identifier.name }
          }
        case .binaryExpression(let lhs):
          if case .punctuation(let op) = lhs.op.kind,
             case .dot = op,
             case .`self` = lhs.lhs,
             case .identifier(let field) = lhs.rhs {
            unassigned = unassigned.filter { $0.name != field.name }
          }
        default: break
        }
      }
      functionContext.emit(MoveStatement(statement: statement).rendered(functionContext: functionContext))
    }

    let constructor = Expression.structConstructor(MoveIR.StructConstructor(
        "T",
        Dictionary(uniqueKeysWithValues: properties.map {
          ($0.identifier.name, .transfer(.move(.identifier(MoveSelf.prefix + $0.identifier.name))))
        })
    ))

    guard !statements.isEmpty else {
      functionContext.emitReleaseReferences()
      functionContext.emit(.return(constructor))
      return functionContext.finalise()
    }

    functionContext.isConstructor = false

    let selfType = renderMoveType(functionContext: functionContext)
    functionContext.emit(
        .expression(.variableDeclaration(MoveIR.VariableDeclaration((MoveSelf.name, selfType)))),
        at: 0
    )
    let selfIdentifier = MoveSelf.generate(sourceLocation: declaration.sourceLocation).identifier
    functionContext.scopeContext.localVariables.append(AST.VariableDeclaration(
        modifiers: [],
        declarationToken: nil,
        identifier: selfIdentifier,
        type: AST.Type(inferredType: .userDefinedType(functionContext.enclosingTypeName),
                       identifier: selfIdentifier)
    ))
    functionContext.emit(.expression(.assignment(Assignment(MoveSelf.name, constructor))))

    while !statements.isEmpty {
      let statement: AST.Statement = statements.removeFirst()
      functionContext.emit(MoveStatement(statement: statement).rendered(functionContext: functionContext))
    }

    functionContext.emitReleaseReferences()
    let selfExpression: MoveIR.Expression = MoveSelf
        .generate(sourceLocation: declaration.closeBraceToken.sourceLocation)
        .rendered(functionContext: functionContext, forceMove: true)
    functionContext.emit(.return(selfExpression))
    return functionContext.finalise()
  }

}
