//
//  Compiler.swift
//  etherlangPackageDescription
//
//  Created by Franklin Schrans on 12/19/17.
//

import Foundation

public class Parser {
   var tokens: [Token]

   public init(tokens: [Token]) {
      self.tokens = tokens
   }

   public func parse() throws -> TopLevelModule {
      return try parseTopLevelModule()
   }

   func parseTopLevelModule() throws -> TopLevelModule {
      let contractDeclaration = try parseContractDeclaration()
      let contractBehaviourDeclarations = try parseContractBehaviorDeclarations()
      return TopLevelModule(contractDeclaration: contractDeclaration, contractBehaviorDeclarations: contractBehaviourDeclarations)
   }

   func parseIdentifier() throws -> Identifier {
      guard let first = tokens.first, case .identifier(let name) = first else {
         throw ParserError.expectedToken(.identifier(""))
      }
      tokens.removeFirst()
      return Identifier(name: name)
   }

   func parseTypeAnnotation() throws -> TypeAnnotation {
      try consume(.punctuation(.colon))
      let type = try parseType()
      return TypeAnnotation(type: type)
   }

   func parseType() throws -> Type {
      guard let first = tokens.first, case .identifier(let name) = first else {
         throw ParserError.expectedToken(.identifier(""))
      }

      tokens.removeFirst()

      return Type(name: name)
   }

   func consume(_ token: Token) throws {
      guard let first = tokens.first, first == token else {
         throw ParserError.expectedToken(token)
      }
      tokens.removeFirst()
   }
}

extension Parser {
   func parseContractDeclaration() throws -> ContractDeclaration {
      try consume(.contract)
      let identifier = try parseIdentifier()
      try consume(.punctuation(.openBrace))
      let variableDeclarations = try parseVariableDeclarations()
      try consume(.punctuation(.closeBrace))

      return ContractDeclaration(identifier: identifier, variableDeclarations: variableDeclarations)
   }

   func parseVariableDeclarations() throws -> [VariableDeclaration] {
      var variableDeclarations = [VariableDeclaration]()

      while true {
         guard (try? consume(.var)) != nil else { break }
         let name = try parseIdentifier()
         let typeAnnotation = try parseTypeAnnotation()
         variableDeclarations.append(VariableDeclaration(name: name, type: typeAnnotation.type))
      }

      return variableDeclarations
   }
}

extension Parser {
   func parseContractBehaviorDeclarations() throws -> [ContractBehaviorDeclaration] {
      var contractBehaviorDeclarations = [ContractBehaviorDeclaration]()

      while let contractIdentifier = try? parseIdentifier() {
         try consume(.punctuation(.doubleColon))
         let callerCapabilities = try parseCallerCapabilityGroup()
         try consume(.punctuation(.openBrace))
         let functionDeclarations = try parseFunctionDeclarations()
         try consume(.punctuation(.closeBrace))
         let contractBehaviorDeclaration = ContractBehaviorDeclaration(contractIdentifier: contractIdentifier, callerCapabilities: callerCapabilities, functionDeclarations: functionDeclarations)
         contractBehaviorDeclarations.append(contractBehaviorDeclaration)
      }

      return contractBehaviorDeclarations
   }

   func parseCallerCapabilityGroup() throws -> [CallerCapability] {
      try consume(.punctuation(.openBracket))
      let callerCapabilities = try parseCallerCapabilityList()
      try consume(.punctuation(.closeBracket))

      return callerCapabilities
   }

   func parseCallerCapabilityList() throws -> [CallerCapability] {
      var callerCapabilities = [CallerCapability]()
      repeat {
         let identifier = try parseIdentifier()
         callerCapabilities.append(CallerCapability(name: identifier.name))
      } while (try? consume(.punctuation(.comma))) != nil

      return callerCapabilities
   }

   func parseFunctionDeclarations() throws -> [FunctionDeclaration] {
      var functionDeclarations = [FunctionDeclaration]()

      while true {
         guard let modifiers = try? parseFunctionHead() else { break }
         let identifier = try parseIdentifier()
         let parameters = try parseParameters()
         let resultType = try? parseResult()
         let body = try parseFunctionBody()

         let functionDeclaration = FunctionDeclaration(modifiers: modifiers, identifier: identifier, parameters: parameters, resultType: resultType, body: body)
         functionDeclarations.append(functionDeclaration)
      }

      return functionDeclarations
   }

   func parseFunctionHead() throws -> [Token] {
      var modifiers = [Token]()

      while true {
         if (try? consume(.public)) != nil {
            modifiers.append(.public)
         } else if (try? consume(.mutating)) != nil {
            modifiers.append(.mutating)
         } else {
            break
         }
      }

      try consume(.func)
      return modifiers
   }

   func parseParameters() throws -> [Parameter] {
      try consume(.punctuation(.openBracket))
      var parameters = [Parameter]()

      if (try? consume(.punctuation(.closeBracket))) != nil {
         return []
      }

      repeat {
         let identifier = try parseIdentifier()
         let typeAnnotation = try parseTypeAnnotation()
         parameters.append(Parameter(identifier: identifier, type: typeAnnotation.type))
      } while (try? consume(.punctuation(.comma))) != nil

      try consume(.punctuation(.closeBracket))
      return parameters
   }

   func parseResult() throws -> Type {
      try consume(.punctuation(.arrow))
      let identifier = try parseIdentifier()
      return Type(name: identifier.name)
   }

   func parseFunctionBody() throws -> [Statement] {
      try consume(.punctuation(.openBrace))
      let statements = try parseStatements()
      try consume(.punctuation(.closeBrace))
      return statements
   }

   func parseStatements() throws -> [Statement] {
      var statements = [Statement]()

      while true {
         if let expression = try? parseExpression() {
            statements.append(expression)
         } else if let returnStatement = try? parseReturnStatement() {
            statements.append(returnStatement)
         } else {
            break
         }
      }

      return statements
   }

   func parseExpression(upTo limitToken: Token = .punctuation(.closeBrace)) throws -> Expression {
      var expressionTokens = tokens.prefix { $0 != limitToken }

      var binaryExpression: BinaryExpression? = nil
      for op in Token.BinaryOperator.allByIncreasingPrecedence where expressionTokens.contains(.binaryOperator(op)) {
         let lhs = try parseExpression(upTo: .binaryOperator(op))
         try consume(.binaryOperator(op))
         expressionTokens = tokens.prefix { $0 != limitToken }
         let rhs = try parseExpression(upTo: tokens[tokens.index(of: expressionTokens.last!)!.advanced(by: 1)])
         binaryExpression = BinaryExpression(lhs: lhs, op: op, rhs: rhs)
         break
      }

      guard let binExp = binaryExpression else {
         return try parseIdentifier()
      }

      return binExp
   }

   func parseReturnStatement() throws -> ReturnStatement {
      try consume(.return)
      let expression = try parseExpression()
      return ReturnStatement(expression: expression)
   }
}

enum ParserError: Error {
   case expectedToken(Token)
   case expectedOneOfTokens([Token])
}

public struct TopLevelModule {
   var contractDeclaration: ContractDeclaration
   var contractBehaviorDeclarations: [ContractBehaviorDeclaration]
}

struct ContractDeclaration {
   var identifier: Identifier
   var variableDeclarations: [VariableDeclaration]
}

struct ContractBehaviorDeclaration {
   var contractIdentifier: Identifier
   var callerCapabilities: [CallerCapability]
   var functionDeclarations: [FunctionDeclaration]
}

struct VariableDeclaration {
   var name: Identifier
   var type: Type
}

struct FunctionDeclaration {
   var modifiers: [Token]
   var identifier: Identifier
   var parameters: [Parameter]
   var resultType: Type?

   var body: [Statement]
}

struct Parameter {
   var identifier: Identifier
   var type: Type
}

struct TypeAnnotation {
   var type: Type
}

struct Identifier: Expression {
   var name: String
}

struct Type {
   var name: String
}

struct CallerCapability {
   var name: String
}

protocol Statement {

}

protocol Expression: Statement {
}

struct BinaryExpression: Expression {
   var lhs: Expression
   var op: Token.BinaryOperator
   var rhs: Expression
}

struct ReturnStatement: Statement {
   var expression: Expression
}
