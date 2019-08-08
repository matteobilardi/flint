//
//  MoveAssignment.swift
//  MoveGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST
import MoveIR

/// Generates code for an assignment.
struct MoveAssignment {
  var lhs: AST.Expression
  var rhs: AST.Expression

  func rendered(functionContext: FunctionContext, asTypeProperty: Bool = false) -> MoveIR.Expression {
    let rhsIr = MoveExpression(expression: rhs).rendered(functionContext: functionContext)
    let rhsCode = rhsIr.description

    switch lhs {
    case .variableDeclaration(let variableDeclaration):
      let mangledName = Mangler.mangleName(variableDeclaration.identifier.name)
      // Shadowed variables shouldn't be redeclared
      if mangledName == rhsCode {
        return .noop
      }
      let typeIR: MoveIR.`Type` = CanonicalType(from: variableDeclaration.type.rawType,
                                                environment: functionContext.environment)!.irType
      // FIXME any cannot be handled by MoveIR, please change
      return .variableDeclaration(MoveIR.VariableDeclaration((mangledName, typeIR), rhsIr))
    case .identifier(let identifier) where identifier.enclosingType == nil:
      return .assignment(Assignment(identifier.name.mangled, rhsIr))
    default:
      // LHS refers to a property in storage or memory.
      let lhsIr = MoveExpression(expression: lhs, asLValue: true).rendered(functionContext: functionContext)

      if functionContext.isInStructFunction {
        let enclosingName: String
        if let enclosingParameter = functionContext.scopeContext.enclosingParameter(
            expression: lhs,
            enclosingTypeName: functionContext.enclosingTypeName) {
          enclosingName = enclosingParameter
        } else {
          enclosingName = "flintSelf"
        }
//        return MoveRuntimeFunction.store(address: lhsIr, d)
        return .assignment(Assignment(lhsIr.description, rhsIr))
      } else if let enclosingIdentifier = lhs.enclosingIdentifier,
        functionContext.scopeContext.containsVariableDeclaration(for: enclosingIdentifier.name) {
        //return MoveRuntimeFunction.store(address: lhsIr, value: rhsIr, inMemory: true)
        return .assignment(Assignment(enclosingIdentifier.name, rhsIr))
      } else {
        return .assignment(Assignment(lhsIr.description, rhsIr))
      }
    }
  }
}