import Diagnostic

public struct TopLevelModule {
  public var declarations: [TopLevelDeclaration]

  public init(declarations: [TopLevelDeclaration]) {
    self.declarations = declarations
  }
}

public enum TopLevelDeclaration {
  case contractDeclaration(ContractDeclaration)
  case contractBehaviorDeclaration(ContractBehaviorDeclaration)
}

public struct ContractDeclaration {
  public var identifier: Identifier
  public var variableDeclarations: [VariableDeclaration]
  public var sourceLocation: SourceLocation

  public init(identifier: Identifier, variableDeclarations: [VariableDeclaration], sourceLocation: SourceLocation) {
    self.identifier = identifier
    self.variableDeclarations = variableDeclarations
    self.sourceLocation = sourceLocation
  }
}

public struct ContractBehaviorDeclaration {
  public var contractIdentifier: Identifier
  public var callerCapabilities: [CallerCapability]
  public var functionDeclarations: [FunctionDeclaration]
  public var sourceLocation: SourceLocation

  public init(contractIdentifier: Identifier, callerCapabilities: [CallerCapability], functionDeclarations: [FunctionDeclaration], sourceLocation: SourceLocation) {
    self.contractIdentifier = contractIdentifier
    self.callerCapabilities = callerCapabilities
    self.functionDeclarations = functionDeclarations
    self.sourceLocation = sourceLocation
  }
}

public struct VariableDeclaration {
  public var identifier: Identifier
  public var type: Type
  public var sourceLocation: SourceLocation

  public init(identifier: Identifier, type: Type, sourceLocation: SourceLocation) {
    self.identifier = identifier
    self.type = type
    self.sourceLocation = sourceLocation
  }
}

public struct FunctionDeclaration {
  public var modifiers: [Token]
  public var identifier: Identifier
  public var parameters: [Parameter]
  public var resultType: Type?
  public var body: [Statement]
  public var sourceLocation: SourceLocation

  public init(modifiers: [Token], identifier: Identifier, parameters: [Parameter], resultType: Type?, body: [Statement], sourceLocation: SourceLocation) {
    self.modifiers = modifiers
    self.identifier = identifier
    self.parameters = parameters
    self.resultType = resultType
    self.body = body
    self.sourceLocation = sourceLocation
  }

  public func mangled(inContract contract: Identifier, withCallerCapabilities callerCapabilities: [CallerCapability]) -> MangledFunction {
    return MangledFunction(contractIdentifier: contract, callerCapabilities: callerCapabilities, functionDeclaration: self)
  }

  public func hasModifier(kind: Token.Kind) -> Bool {
    return modifiers.contains { $0.kind == kind } 
  }
}

public struct Parameter {
  public var identifier: Identifier
  public var type: Type
  public var sourceLocation: SourceLocation

  public init(identifier: Identifier, type: Type, sourceLocation: SourceLocation) {
    self.identifier = identifier
    self.type = type
    self.sourceLocation = sourceLocation
  }
}

public struct TypeAnnotation {
  public var type: Type
  public var sourceLocation: SourceLocation

  public init(type: Type, sourceLocation: SourceLocation) {
    self.type = type
    self.sourceLocation = sourceLocation
  }
}

public struct Identifier: Hashable {
  public var name: String
  public var sourceLocation: SourceLocation
  public var isImplicitPropertyAccess = false

  public init(name: String, sourceLocation: SourceLocation) {
    self.name = name
    self.sourceLocation = sourceLocation
  }

  public var hashValue: Int {
    return "\(name)_\(sourceLocation)".hashValue
  }
}

public struct Type {
  public enum Kind: Equatable {
    case builtInType(BuiltInType)
    case userDefinedType(String)

    public static func ==(lhs: Type.Kind, rhs: Type.Kind) -> Bool {
      switch (lhs, rhs) {
      case (.builtInType(let lhsType), .builtInType(let rhsType)): return lhsType == rhsType
      case (.userDefinedType(let lhsType), .userDefinedType(let rhsType)): return lhsType == rhsType
      default: return false
      }
    }
  }

  public enum BuiltInType: String {
    case address = "Address"

    var canBeUsedAsCallerCapability: Bool {
      switch self {
      case .address: return true
      }
    }
  }

  public var kind: Kind
  public var sourceLocation: SourceLocation

  public init(name: String, sourceLocation: SourceLocation) {
    if let builtInType = BuiltInType(rawValue: name) {
      kind = .builtInType(builtInType)
    } else {
      kind = .userDefinedType(name)
    }
    self.sourceLocation = sourceLocation
  }
}

public struct CallerCapability {
  public var name: String
  public var sourceLocation: SourceLocation

  public init(name: String, sourceLocation: SourceLocation) {
    self.name = name
    self.sourceLocation = sourceLocation
  }

  public func isSubcapability(callerCapability: CallerCapability) -> Bool {
    return name == callerCapability.name || callerCapability.name == "any"
  }
}

public indirect enum Expression {
  case identifier(Identifier)
  case binaryExpression(BinaryExpression)
  case functionCall(FunctionCall)
  case literal(Token)
  case `self`(Token)
  case variableDeclaration(VariableDeclaration)
  case bracketedExpression(Expression)

  public var sourceLocation: SourceLocation {
    switch self {
    case .identifier(let identifier): return identifier.sourceLocation
    case .binaryExpression(let binaryExpression): return binaryExpression.sourceLocation
    case .functionCall(let functionCall): return functionCall.sourceLocation
    case .literal(let literal): return literal.sourceLocation
    case .self(let `self`): return self.sourceLocation
    case .variableDeclaration(let variableDeclaration): return variableDeclaration.sourceLocation
    case .bracketedExpression(let bracketedExpression): return bracketedExpression.sourceLocation
    }
  }
}

public indirect enum Statement {
  case expression(Expression)
  case returnStatement(ReturnStatement)
  case ifStatement(IfStatement)
}

public struct BinaryExpression {
  public var lhs: Expression

  public var op: Token
  public var opToken: Token.Kind.BinaryOperator

  public var rhs: Expression

  public var sourceLocation: SourceLocation

  public init(lhs: Expression, op: Token, rhs: Expression, sourceLocation: SourceLocation) {
    self.lhs = lhs

    guard case .binaryOperator(let opToken) = op.kind else {
      fatalError("Unexpected token kind \(op.kind) when trying to form a binary expression.")
    }

    self.op = op
    self.opToken = opToken
    self.rhs = rhs
    self.sourceLocation = sourceLocation
  }
}

public struct FunctionCall {
  public var identifier: Identifier
  public var arguments: [Expression]
  public var sourceLocation: SourceLocation

  public init(identifier: Identifier, arguments: [Expression], sourceLocation: SourceLocation) {
    self.identifier = identifier
    self.arguments = arguments
    self.sourceLocation = sourceLocation
  }
}

public struct ReturnStatement {
  public var expression: Expression?
  public var sourceLocation: SourceLocation

  public init(expression: Expression?, sourceLocation: SourceLocation) {
    self.expression = expression
    self.sourceLocation = sourceLocation
  }
}

public struct IfStatement {
  public var condition: Expression
  public var statements: [Statement]
  public var elseClauseStatements: [Statement]
  public var sourceLocation: SourceLocation

  public init(condition: Expression, statements: [Statement], elseClauseStatements: [Statement], sourceLocation: SourceLocation) {
    self.condition = condition
    self.statements = statements
    self.elseClauseStatements = elseClauseStatements
    self.sourceLocation = sourceLocation
  }
}