public class JSVariableAssignment : CustomStringConvertible {
    private let lhs : String
    private let isConstant: Bool
    private let rhs : JSNode
    private let isInstantiation: Bool
    
    public init(lhs: String, rhs: JSNode, isConstant: Bool, isInstantiation : Bool = false) {
        self.lhs = lhs
        self.rhs = rhs
        self.isConstant = isConstant
        self.isInstantiation = isInstantiation
    }
    
    public var description: String {
        
        var desc : String = ""
        
        if (isInstantiation)
        {
            desc += "//"
        }

        let varModifier = isConstant ? "let" : "var"
        desc += varModifier
        desc += " " + lhs.description + " = " + rhs.description
        return desc
    }
}
