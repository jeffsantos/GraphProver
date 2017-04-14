-------------------------------------------------------------------------------
--   Constants for sequent Module
--
--   Contains all the constants used by the Sequent Calculus Logic Module.
--
--   @authors: Vitor, Jefferson
--
-------------------------------------------------------------------------------

-- Operators definitions
opAnd = {}
opAnd.tex = '\\land'
opAnd.print = '&'  
opAnd.graph = "and"

opOr = {}
opOr.tex = '\\lor' 
opOr.print = '|'  
opOr.graph = "or"

opImp = {}
opImp.tex = '\\to'
opImp.print = '->'
opImp.graph = "imply"

opNot = {}
opNot.tex = '\\neg'
opNot.print = '~'
opNot.graph = "not"

opSeq = {}
opSeq.tex = '\\vdash'
opSeq.print = '=>'
opSeq.graph = "Seq"

operators = {} -- Tabela que contém todos os operadores
operators[1] = opAnd
operators[2] = opOr
operators[3] = opImp
operators[4] = opNot
operators[5] = opSeq

-- Labels for graph definitions
lblEdgeEsq = "esq"
lblEdgeDir = "dir"
lblEdgeDeducao = "DED"
lblEdgeGoal = "Goal"
lblEdgeCounterModel = "COUNTER"
lblEdgeAccessability = "Access"
lblEdgeSatisfy = "sat"
lblEdgeUnsatisfy = "unsat"
lblFormulaReference = "ref"

lblNodeGG = "GG"
lblNodeEsq = "e"
lblNodeDir = "d"
lblNodeBrackets = "[]"
lblNodeFocus = "{}"
lblNodeWorld = "w"

lblRuleFocus = "focus"
lblRuleImplyLeft = "left"
lblRuleImplyRight = "right"
lblRuleRestart = "restart"

-- Side definitions
leftSide = "Left"
rightSide = "Right"

-- Pretty Print
ppProof = "proof"
ppSeq = "seq"
ppFormula = "formula"

-- Tex Print Options
texOutputHtml = "html"
texOutputPDF = "pdf"
defaultOutput = texOutputPDF
printShortedFormulas = true
printCopiedId = false
--counterExampleColor = "red"
--axiomColor = "blue"
counterExampleColor = "black"
axiomColor = "black"
