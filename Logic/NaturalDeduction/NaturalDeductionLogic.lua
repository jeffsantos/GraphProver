-------------------------------------------------------------------------------
--	Natural Deduction Logic Module
--
--	This module defines the logic of proving utilizing Natural Deduction.
--
--	@authors: bpalkmim
--
-------------------------------------------------------------------------------
require "Logic/NaturalDeduction/NaturalDeductionHelper"
require "Logic/NaturalDeduction/NaturalDeductionPrint"

local logger = logging.file("aux/prover%s.log", "%Y-%m-%d")
logger:setLevel(logging.INFO)

LogicModule = {}

local goalsList = nil
local graph = nil
local counterModel = nil
local nstep = 0
local sufix = 0
local dischargeable = {}

-- Private functions

local function copyLeftExpandedFormulas(natDNode)
	local leftExpandedFormulas = natDNode:getInformation("leftExpandedFormulas")
	local newLeftExpandedFormulas = Set:new()
	for leftExpandedFormula, _ in pairs(leftExpandedFormulas) do
		newLeftExpandedFormulas:add(leftExpandedFormula)
	end

	return newLeftExpandedFormulas
end

local function copyRestartedFormulas(natDNode)
	local restartedFormulas = natDNode:getInformation("restartedFormulas")
	local newRestartedFormulas = Set:new()

	for restartedFormula, _ in pairs(restartedFormulas) do
		newRestartedFormulas:add(restartedFormula)
	end

	return newRestartedFormulas
end

local function copyMarkedFormula(natDNode, formulaNode)

	local newNode = NatDNode:new(formulaNode:getInformation("type"))
	newNode:setInformation("originalFormula", formulaNode)
	graph:addNode(newNode)

	local leftEdgesOut = natDNode:getEdgeOut(lblEdgeEsq):getDestino():getEdgesOut()	
	local newEdge = NatDEdge:new(""..#leftEdgesOut, natDNode:getEdgeOut(lblEdgeEsq):getDestino(), newNode)
	graph:addEdge(newEdge)

	for _, leftEdge in ipairs(leftEdgesOut) do
		if leftEdge:getDestino() == formulaNode then 
			for k,info in pairs(leftEdge:getInformationTable()) do
				if k ~= "reference" then
					newEdge:setInformation(k, info)
				end
			end
		end		
	end	

	return newNode
end

-- TODO remover/modificar
local function createNewSequent(natDNode)
	local listNewNodes = {}
	local listNewEdges = {}
	
	nodeSeqNew = NatDNode:new(natDNode:getInformation("type"))
	listNewNodes[#listNewNodes+1] = nodeSeqNew
	
	local newNodeLeft = NatDNode:new(lblNodeEsq)
	local newNodeDir = NatDNode:new(lblNodeDir)
	listNewNodes[#listNewNodes+1] = newNodeLeft
	listNewNodes[#listNewNodes+1] = newNodeDir

	local newEdgeLeft = NatDEdge:new(lblEdgeEsq, nodeSeqNew, newNodeLeft)				 
	local newEdgeRight = NatDEdge:new(lblEdgeDir, nodeSeqNew, newNodeDir)
	listNewEdges[#listNewEdges+1] = newEdgeLeft
	listNewEdges[#listNewEdges+1] = newEdgeRight
	
	local nodeEsq = natDNode:getEdgeOut(lblEdgeEsq):getDestino()
	local nodeDir = natDNode:getEdgeOut(lblEdgeDir):getDestino()
	
	esqEdgesOut = nodeEsq:getEdgesOut()
	for i=1, #esqEdgesOut do
		local newEdge = NatDEdge:new(esqEdgesOut[i]:getLabel(), newNodeLeft, esqEdgesOut[i]:getDestino())
		if esqEdgesOut[i]:getInformation("reference") ~= nil then
			newEdge:setInformation("reference", esqEdgesOut[i]:getInformation("reference"))
		end
		listNewEdges[#listNewEdges+1] = newEdge
	end

	dirEdgesOut = nodeDir:getEdgesOut()
	for i=1, #dirEdgesOut do
		local newEdge = NatDEdge:new(dirEdgesOut[i]:getLabel(), newNodeDir, dirEdgesOut[i]:getDestino())
		listNewEdges[#listNewEdges+1] = newEdge
	end

	local leftExpandedFormulas = copyLeftExpandedFormulas(natDNode)
	nodeSeqNew:setInformation("leftExpandedFormulas", leftExpandedFormulas)

	local restartedFormulas = copyRestartedFormulas(natDNode)
	nodeSeqNew:setInformation("restartedFormulas", restartedFormulas)	  

	return nodeSeqNew,listNewNodes,listNewEdges
end

local function generateNewGoal(natDNode)

	if goalsList == nil then
		goalsList = {}
	end

	local edgesOut = natDNode:getEdgesOut()
	local newGoal = nil
	local j = 1

	-- TODO assim, há apenas uma lista com os goals possíveis.
	-- Verificar se não é necessário uma lista de subgoals
	if edgesOut ~= nil then
		for k, _ in ipairs(edgesOut) do
			for i = 1, #edgesOut[k] do
				local currentNode = edgesOut[k][i]:getDestino()
				local typeOfNode = currentNode:getInformation("type")

				-- TODO ver para mais tipos de nós
				if typeOfNode == opImp.graph then
					goalsList[j] = currentNode
					j = j + 1
				end
			end
		end
	end
	
	newGoal = Goal:new(natDNode, goalsList)
					 
	return newGoal
end

local function createGraphEmpty()

	local NatDGraph = Graph:new()
	NatDNode:resetCounters()
	
	local NodeGG = NatDNode:new(lblNodeGG)
	local nodes = {NodeGG}
	local edges = {}

	NatDGraph:addNodes(nodes)
	NatDGraph:addEdges(edges)
	NatDGraph:setRoot(NodeGG)
	return NatDGraph
end

---
--- @param letters Stores all atoms.  
local function createGraphFormula(formula_tabela, letters)

	local S1
	local S2
	local nodes
	local edges
	local NodeLetter = nil	
	local FormulaGraph = Graph:new()

	if formula_tabela.tag == "Atom" then 
		local prop_letter = formula_tabela["1"]
		for k,v in pairs(letters) do 
			if k == prop_letter then 
				NodeLetter = v
			end
		end
		if not NodeLetter then	
			NodeLetter = NatDNode:new(prop_letter)
			letters[prop_letter] = NodeLetter
		end
	
		nodes = {NodeLetter}
		edges = {}
		
		FormulaGraph:addNodes(nodes)
		FormulaGraph:addEdges(edges)
		FormulaGraph:setRoot(NodeLetter)
		
	elseif formula_tabela.tag == "imp" then

		S1, letters = createGraphFormula(formula_tabela["1"],letters)
		S2, letters = createGraphFormula(formula_tabela["2"],letters)

		local NodeImp = NatDNode:new(opImp.graph)
		local EdgeEsq = NatDEdge:new(lblEdgeEsq, NodeImp, S1.root)
		local EdgeDir = NatDEdge:new(lblEdgeDir, NodeImp, S2.root)

		nodes = {NodeImp}
		edges = {EdgeEsq, EdgeDir}

		FormulaGraph:addNodes(S1.nodes)
		FormulaGraph:addNodes(S2.nodes)
		FormulaGraph:addNodes(nodes)
		FormulaGraph:addEdges(S1.edges)
		FormulaGraph:addEdges(S2.edges)
		FormulaGraph:addEdges(edges)
		FormulaGraph:setRoot(NodeImp)

	-- TODO criar demais casos que não só implicação
	end

	return FormulaGraph, letters
end	

local function createGraphNatD(form_table, letters)

	local NatDGraph = Graph:new()
	local S,L
	local NodeGG = NatDNode:new(lblNodeGG)
	S,L = createGraphFormula(form_table, letters)

	local newEdge = NatDEdge:new(lblRootEdge, NodeGG, S.root)

	local nodes = {NodeGG}
	NatDGraph:addNodes(nodes)
	NatDGraph:addNodes(S.nodes)
	local edges = {newEdge}
	NatDGraph:addEdges(edges)
	NatDGraph:addEdges(S.edges)

	goalsList = {}
	goalsList[NodeGG:getLabel()] = {goal = generateNewGoal(NodeGG), weight = 1}

	return NatDGraph
end

local function verifySideOfSequent(natDNode, formulaNode)
	edgesOut = natDNode:getEdgesOut()

	if edgesOut == nil then
		return false
	end

	local retValues = {}

	for i=1, #edgesOut do
		if edgesOut[i]:getDestino():getLabel() == formulaNode:getLabel() then
			return true
		end
	end

	return false
end

--- Verifies operator side in a sequent
local function verifySideOfOperator(natDNode, formulaNode)
	edgesOutList = natDNode:getEdgesOut()
	if edgesOutList == nil then
		return nil
	end

	for i=1, #edgesOutList do
		if edgesOutList[i]:getLabel() == lblEdgeEsq then
			if verifySideOfSequent(edgesOutList[i]:getDestino(), formulaNode) then
				return "Left"
			end
		end

		if edgesOutList[i]:getLabel() == lblEdgeDir then
			if verifySideOfSequent(edgesOutList[i]:getDestino(), formulaNode) then
				return "Right"
			end
		end					
	end
	
	return nil 
end

local function markProvedPath(natDNode) 
	local node = natDNode

	while node ~= nil do
		node:setInformation("isProved", true)
		if node:getEdgeIn(lblEdgeDeducao) then 
			node = node:getEdgeIn(lblEdgeDeducao):getOrigem()
		else
			node = nil
		end
	end
end

local function markCounterExamplePath(natDNode) 
	local node = natDNode

	while node ~= nil do
		node:setInformation("isProved", false)
		if node:getEdgeIn(lblEdgeDeducao) then 
			node = node:getEdgeIn(lblEdgeDeducao):getOrigem()
		else
			node = nil
		end
	end
end

local function countGraphElements() 
	local countNodeElements = {}
	local countEdgesElements = {}  

	nodes = graph:getNodes()

	for i=1, #nodes do	
		if countNodeElements[nodes[i]:getInformation("type")] == nil then
			countNodeElements[nodes[i]:getInformation("type")] = 1
		else
			countNodeElements[nodes[i]:getInformation("type")] = countNodeElements[nodes[i]:getInformation("type")] + 1
		end
	end

	edges = graph:getEdges()

	for i=1, #edges do	
		if countEdgesElements[edges[i]:getLabel()] == nil then
			countEdgesElements[edges[i]:getLabel()] = 1
		else
			countEdgesElements[edges[i]:getLabel()] = countEdgesElements[edges[i]:getLabel()] + 1
		end
	end  

	for k,count in pairs(countNodeElements) do
		logger:info("statistics -- Total nodes of type "..krgrep.." is "..count)
	end

	for k,count in pairs(countEdgesElements) do
		logger:info("statistics -- Total nodes of type "..k.." is "..count)
	end

end

local function logGoalsList()
	logger:info("GoalsList:")	
	for k,v in pairs(goalsList) do
		if not goalsList[k].goal:getSequent():getInformation("isExpanded") then
			logger:info("seq: "..k.."; weight: "..goalsList[k].weight)
		end		
	end
end

local function resetGoalsWeight(pweight)

	local k, goalEntry
	
	for k,goalEntry in pairs(goalsList) do
		goalEntry.weight = pweight
	end	
end

local function degreeOfFormula(formulaNode)
	if formulaNode:getInformation("type") ~= opImp.graph then
		return 0
	else
		local degree = 1 + degreeOfFormula(formulaNode:getEdgeOut(lblEdgeDir):getDestino()) + degreeOfFormula(formulaNode:getEdgeOut(lblEdgeEsq):getDestino())
		return degree 
	end
end

local function compareFormulasDegree(formulaA, formulaB)
	local countFormulaA = degreeOfFormula(formulaA)
	local countFormulaB = degreeOfFormula(formulaB)

	return countFormulaB > countFormulaA
end

local function compareEdgesInBracket(edgeA, edgeB)
	local posA = tonumber(edgeA:getLabel())
	local posB = tonumber(edgeB:getLabel())

	return posA > posB
end

local function compareSequentsFormulas(sideSeq, sideSeqParent)
  
	local edgeSeqParent
	local formulaSeq
	local formulasSeqParent = {}
	local ret = true
	local i = 0	

	if sideSeqParent:getEdgesOut() == nil then
		formulasSeqParent = {}
	else		
		for _, edgeSeqParent in ipairs(sideSeqParent:getEdgesOut()) do
			local formulaNode = nil
			local ref = ""
			
			if edgeSeqParent:getDestino():getInformation("originalFormula") ~= nil then
				formulaNode = edgeSeqParent:getDestino():getInformation("originalFormula")
				local leftNodeParent = sideSeqParent:getEdgeIn("0"):getDestino()
				for _, edgeLeftParent in ipairs(leftNodeParent:getEdgesOut()) do
					if edgeLeftParent:getDestino() == formulaNode then
						ref = edgeLeftParent:getInformation("reference"):getLabel()
					end
				end
			else
				formulaNode = edgeSeqParent:getDestino()
				if edgeSeqParent:getInformation("reference") ~= nil then
					ref = edgeSeqParent:getInformation("reference"):getLabel()
				end						
			end					
			
			i = i + 1			
			formulasSeqParent[i] = formulaNode:getLabel()..ref		
		end
	end
	
	if sideSeq:getEdgesOut() == nil then
		if formulasSeqParent == nil then
			ret = true
		else
			ret = false
		end		
	else
		local setOfFormulas = Set:new(formulasSeqParent)
		
		for _, edgeSeq in ipairs(sideSeq:getEdgesOut()) do
			local formulaNode = nil
			local ref = ""
					
			if edgeSeq:getDestino():getInformation("originalFormula") ~= nil then
				formulaNode = edgeSeq:getDestino():getInformation("originalFormula")
				local leftNode = sideSeq:getEdgeIn("0"):getDestino()
				for _, edgeLeft in ipairs(leftNode:getEdgesOut()) do
					if edgeLeft:getDestino() == formulaNode then
						ref = edgeLeft:getInformation("reference"):getLabel()
					end
				end
			else
				formulaNode = edgeSeq:getDestino()
				if edgeSeq:getInformation("reference") ~= nil then
					ref = edgeSeq:getInformation("reference"):getLabel()
				end						
			end					 
				
			formulaSeq = formulaNode:getLabel()..ref
			if not setOfFormulas:contains(formulaSeq) then
				ret = false
				break
			end			
		end
	end
	
	return ret
end

local function isExpandable(natDNode)
	local ret = false
	local rule = ""
	local formulaNode = nil

	local rightFormulaNode = natDNode:getEdgeOut(lblEdgeDir):getDestino():getEdgeOut("0"):getDestino()
	local typeOfNode = rightFormulaNode:getInformation("type")
	formulaNode = rightFormulaNode
	if typeOfNode == opImp.graph then
		ret = true
		rule = lblRuleImplyRight
		logger:info("isExpandable - "..natDNode:getLabel().." ainda tem implicação `a direita.")
	end	

	if not ret then
		local leftFormulasEdges = natDNode:getEdgeOut(lblEdgeEsq):getDestino():getEdgesOut()

		for i=1, #leftFormulasEdges do
			formulaNode = leftFormulasEdges[i]:getDestino()
			local typeOfNode = formulaNode:getInformation("type")
			
			if leftFormulasEdges[i]:getLabel() ~= "0" then
				if (leftFormulasEdges[i]:getInformation("reference") == nil or leftFormulasEdges[i]:getInformation("reference") == rightFormulaNode) and
				not focusedFormulas[formulaNode] then
					ret = true
					rule = lblRuleFocus
					logger:info("isExpandable - "..natDNode:getLabel().." ainda tem fórmulas para focar.")
					break
				end
			end
		end
	end
	
	if not ret then
		local leftExpandedFormulas = natDNode:getInformation("leftExpandedFormulas")

		logger:info("isExpandable - Left Expanded Formulas - "..natDNode:getLabel())
		for k,v in pairs(leftExpandedFormulas) do
			logger:info(k:getLabel())
		end

		local edgesInOriginal = nil
		local referenceFormula = nil
		local hasReference = false
		for _,edgesInFocus in ipairs(natDNode:getEdgeOut(lblEdgeEsq):getDestino():getEdgeOut("0"):getDestino():getEdgesOut()) do
			formulaNode = edgesInFocus:getDestino()
			if not leftExpandedFormulas[formulaNode:getInformation("originalFormula")] and formulaNode:getInformation("type") == opImp.graph then

				-- for _,edgesInOriginal in ipairs(formulaNode:getInformation("originalFormula"):getEdgesIn()) do
				--	 if edgesInOriginal:getInformation("reference") ~= nil then
				--		 referenceFormula = edgesInOriginal:getInformation("reference")
				--		 hasReference = true
				--		 if referenceFormula == rightFormulaNode then
				--			 ret = true
				--			 rule = lblRuleImplyLeft
				--			 logger:info("isExpandable - "..natDNode:getLabel().." ainda tem fórmulas focada não expandida com imply-left.")
				--			 break
				--		 end				
				--	 end
				-- end
				
				-- if hasReference then
				--	 break
				-- end

				ret = true
				rule = lblRuleImplyLeft
				logger:info("isExpandable - "..natDNode:getLabel().." ainda tem fórmulas focada não expandida com imply-left.")
				break
			end
		end		
	end

	if not ret then
		local restartedFormulas = natDNode:getInformation("restartedFormulas")

		if restartedFormulas == nil then
			ret = true
		else
			local edgesFormulasInsideBracket = natDNode:getEdgeOut(lblEdgeDir):getDestino():getEdgeOut("1"):getDestino():getEdgesOut()

			logger:info("Restarted Formulas - "..natDNode:getLabel())
			for k,v in pairs(restartedFormulas) do
				logger:info(k:getLabel())
			end			

			local i = #edgesFormulasInsideBracket
			while i >= 1 do 
				logger:info("isExpandable - "..natDNode:getLabel().." Inside Bracket: "..edgesFormulasInsideBracket[i]:getDestino():getLabel())
				if not restartedFormulas:contains(edgesFormulasInsideBracket[i]:getDestino()) then
					logger:info("isExpandable - "..natDNode:getLabel().." Restarted Formulas não contém "..edgesFormulasInsideBracket[i]:getDestino():getLabel())
					logger:info("isExpandable - "..natDNode:getLabel().." ainda tem fórmulas para restartar.")
					ret = true
					rule = lblRuleRestart
					formulaNode = edgesFormulasInsideBracket[i]:getDestino()
					break
				end
				i = i - 1
			end
		end
		
	end
	
	return ret, rule, formulaNode
end

local function checkLoop(natDNode)
  
	local esqNode, dirNode, dedSeq, esqNodeAnt, dirNodeAnt
	local ret = false
	local equalLeft, equalRight

	esqNode = natDNode:getEdgeOut(lblEdgeEsq):getDestino()
	dirNode = natDNode:getEdgeOut(lblEdgeDir):getDestino()

	if natDNode:getEdgeIn(lblEdgeDeducao) == nil then
		dedSeq = nil
	else
		dedSeq = natDNode:getEdgeIn(lblEdgeDeducao):getOrigem()
	end

	while dedSeq ~= nil do	  
		esqNodeAnt = dedSeq:getEdgeOut(lblEdgeEsq):getDestino()
		dirNodeAnt = dedSeq:getEdgeOut(lblEdgeDir):getDestino()

		equalLeft = compareSequentsFormulas(esqNode, esqNodeAnt)		
		equalRight = compareSequentsFormulas(dirNode, dirNodeAnt)
		
		if equalLeft and equalRight then
			ret = true
			natDNode:setInformation("repetition", true)
			dedSeq:setInformation("repetition", true)
			markCounterExamplePath(dedSeq)
			break
		else
			if dedSeq:getEdgeIn(lblEdgeDeducao) == nil then
				dedSeq = nil
			else
				dedSeq = dedSeq:getEdgeIn(lblEdgeDeducao):getOrigem()
			end
		end
	end

	
	return ret
end

local function generateCounterModel(natDNode, counterModel)

  local ret = nil

	if counterModel == nil then

		-- Cria nós dos mundos
		local world0 = Node:new(lblNodeWorld.."0")
		world0:setInformation("type", lblNodeWorld)
		
		local world1 = Node:new(lblNodeWorld.."1")
		world1:setInformation("type", lblNodeWorld)

		-- Criar aresta do sequente para o mundo 0
		local edgeCounter = Edge:new(lblEdgeCounterModel, natDNode, world0)
		
		-- Criar aresta do mundo 0 para o mundo 1
		local edgeAccess = Edge:new(lblEdgeAccessability, world0, world1)

		-- Adicionar nós e arestas no grafo
		graph:addNode(world0)
		graph:addNode(world1)
		graph:addEdge(edgeCounter)
		graph:addEdge(edgeAccess)
		
		local seqSideRight = natDNode:getEdgeOut(lblEdgeDir):getDestino()
		local seqSideLeft = natDNode:getEdgeOut(lblEdgeEsq):getDestino()
		local formula = nil
		local edgeSat = nil

		-- Para cada formula à esq do sequente, criar aresta SAT ligando ao mundo 1
		local leftFormulasEdges = seqSideLeft:getEdgesOut()
		for i=1,#leftFormulasEdges do
			formula = leftFormulasEdges[i]:getDestino()
			edgeSat = Edge:new(lblEdgeSatisfy, world1, formula)
			graph:addEdge(edgeSat)
		end

		-- Para cada formula à direita:
		-- Se estiver fora do bracket criar aresta NOT SAT ligando ao mundo 1
		local formulaOutsideBracket = seqSideRight:getEdgeOut("0"):getDestino()
		edgeSat = Edge:new(lblEdgeSatisfy, world1, formula)
		graph:addEdge(edgeSat)

		-- Se estiver no bracket criar aresta NOT SAT ligando ao mundo 0		
		local formulasInsideBracketEdges = seqSideRight:getEdgeOut("1"):getDestino():getEdgesOut()		
		for i=1,#formulasInsideBracketEdges do
			formula = formulasInsideBracketEdges[i]:getDestino()
			edgeSat = Edge:new(lblEdgeUnsatisfy, world0, formula)
			graph:addEdge(edgeSat)
		end
		
		ret = world0		
		
	end
	
	return ret3

end

local function getInitialNatDNode()
	if graph then  
		local goalEdge = graph:getNode(lblNodeGG):getEdgeOut(lblEdgeGoal)
		
		if goalEdge then
		  return goalEdge:getDestino()
		end
	end
end

local function verifyAxiom(natDNode)
	--local edgesLeft = natDNode:getEdgeOut(lblEdgeEsq):getDestino():getEdgesOut()
	local rightFormulaNode = natDNode:getEdgeOut(lblEdgeDir):getDestino():getEdgeOut("0"):getDestino()
	local isAxiom = false
	
	if isAxiom then
		natDNode:setInformation("isAxiom", true)
		natDNode:setInformation("isExpanded", true)
		markProvedPath(natDNode)	  
		return true 
	else	
		return false
	end
end

local function findFormulaInBracket(nodeBrackets, formulaNode)
	local formulasInsideBracketEdges = nodeBrackets:getEdgesOut()
	local posFormulaInBracket = ""
	local formulaInBracketEdge = nil

	for i=1,#formulasInsideBracketEdges do
		if formulasInsideBracketEdges[i]:getDestino() == formulaNode then
			formulaInBracketEdge = formulasInsideBracketEdges[i]
			posFormulaInBracket = formulasInsideBracketEdges[i]:getLabel()
			break
		end
	end

	return formulaInBracketEdge
end

local function applyImplyLeftRule(natDNode, formulaNode)
	logger:debug("ImplyLeft: Expanding sequent "..natDNode:getLabel().. " and formula "..formulaNode:getLabel())
	
	local NewNatDNode1, seqListNodes1, seqListEdges1=createNewSequent(natDNode)
	local NewNatDNode2, seqListNodes2, seqListEdges2=createNewSequent(natDNode)

	graph:addNodes(seqListNodes1)
	graph:addNodes(seqListNodes2)
	graph:addEdges(seqListEdges1)
	graph:addEdges(seqListEdges2)
	local nodeRight1 = NewNatDNode1:getEdgeOut(lblEdgeDir):getDestino()
	local nodeLeft1 = NewNatDNode1:getEdgeOut(lblEdgeEsq):getDestino()
	local nodeRight2 = NewNatDNode2:getEdgeOut(lblEdgeDir):getDestino()
	local nodeLeft2 = NewNatDNode2:getEdgeOut(lblEdgeEsq):getDestino()

	local newEdge1 = NatDEdge:new(lblEdgeDeducao, natDNode, NewNatDNode1)
	local newEdge2 = NatDEdge:new(lblEdgeDeducao, natDNode, NewNatDNode2)

	local printFormula = nil
	if formulaNode:getInformation("originalFormula") then
		printFormula = formulaNode:getInformation("originalFormula")
	else
		printFormula = formulaNode
	end
	newEdge1:setInformation("rule", opImp.tex.."\\mbox{left}-"..opImp.tex.."_{"..printFormula:getLabel():sub(6,formulaNode:getLabel():len()).."}")		
	newEdge2:setInformation("rule", opImp.tex.."\\mbox{left}-"..opImp.tex.."_{"..printFormula:getLabel():sub(6,formulaNode:getLabel():len()).."}")		
		
	graph:addEdge(newEdge1)
	graph:addEdge(newEdge2)

	local nodeFormulaOutsideBrackets = nodeRight1:getEdgeOut("0"):getDestino()
	graph:removeEdge(nodeRight1:getEdgeOut("0"))
	
	local formulasInsideBracketEdges = newNodeBrackets:getEdgesOut()
	local formulaInBracketEdge = findFormulaInBracket(newNodeBrackets, nodeFormulaOutsideBrackets)

	-- 1. Create left premiss sequent:

	-- 1.0. Put label in non-marked formulas on the left
	local listEdgesOut = nodeLeft1:getEdgesOut()
	local numberOfFormulasOnLeft =  #listEdgesOut
	for i=1, #listEdgesOut do
		if listEdgesOut[i]:getLabel() ~= "0" then
			if listEdgesOut[i]:getInformation("reference") == nil then
				--listEdgesOut[i]:setInformation("reference", nodeFormulaOutsideBrackets)
			--else
				local formulaNode = listEdgesOut[i]:getDestino()
				local newFormulaNode = NatDNode:new(formulaNode:getInformation("type"))
				newFormulaNode:setInformation("originalFormula", formulaNode)
				if formulaNode:getEdgeOut(lblEdgeEsq) ~= nil then
					local newEdgeEsq = NatDEdge:new(lblEdgeEsq, newFormulaNode, formulaNode:getEdgeOut(lblEdgeEsq):getDestino()) 
					local newEdgeDir = NatDEdge:new(lblEdgeDir, newFormulaNode, formulaNode:getEdgeOut(lblEdgeDir):getDestino())

					graph:addEdge(newEdgeEsq)
					graph:addEdge(newEdgeDir)					
				end				
				graph:addNode(newFormulaNode)

				local newEdgeFormula = NatDEdge:new(""..numberOfFormulasOnLeft, nodeLeft1, newFormulaNode)
				numberOfFormulasOnLeft = numberOfFormulasOnLeft + 1
				graph:addEdge(newEdgeFormula)
				
				newEdgeFormula:setInformation("reference", nodeFormulaOutsideBrackets)
			end
		end
	end
	
	-- 1.1. Put C inside bracket.
	if formulaInBracketEdge == nil then
		local newEdgeInsideBrackets = NatDEdge:new(""..contBracketFormulas, newNodeBrackets, nodeFormulaOutsideBrackets)
		contBracketFormulas = contBracketFormulas + 1
		graph:addEdge(newEdgeInsideBrackets)
	end
	
	local newBracketsEdge = NatDEdge:new("1", nodeRight1, newNodeBrackets)
	graph:addEdge(newBracketsEdge)

	-- 1.2. Put A (from A → B) on the right.
	local newEdgeDir = NatDEdge:new("0", nodeRight1, formulaNode:getEdgeOut(lblEdgeEsq):getDestino())	
	graph:addEdge(newEdgeDir)
	
	-- 2. Create right premiss sequent:
	
	-- 2.1. Leave A → B on the left
	local listEdgesOut = nodeLeft2:getEdgesOut()

	-- 2.2. Add B (from A → B) on the left outside focus
	local newFocusNode = createBracketOrFocus(lblNodeFocus, NewNatDNode2)

	local newEdgeSequent = NatDEdge:new("0", nodeLeft2, newFocusNode)
	graph:addEdge(newEdgeSequent)
	
	local newEdgeLeft = NatDEdge:new(""..(#nodeLeft2:getEdgesOut()+1), nodeLeft2, formulaNode:getEdgeOut(lblEdgeDir):getDestino()) 
	graph:addEdge(newEdgeLeft)

	local leftExpandedFormulas = NewNatDNode1:getInformation("leftExpandedFormulas")
	leftExpandedFormulas:add(formulaNode:getInformation("originalFormula"))

	leftExpandedFormulas = NewNatDNode2:getInformation("leftExpandedFormulas")
	leftExpandedFormulas:add(formulaNode:getInformation("originalFormula"))	
	
	local lweight = goalsList[natDNode:getLabel()].weight
	goalsList[NewNatDNode1:getLabel()] = {goal = generateNewGoal(NewNatDNode1), weight = lweight}	
	goalsList[NewNatDNode2:getLabel()] = {goal = generateNewGoal(NewNatDNode2), weight = lweight}
	natDNode:setInformation("isExpanded", true)
	logger:info("applyImplyLeftRule - "..natDNode:getLabel().." was expanded")

	return graph		
end

local function applyImplyRightRule(natDNode, formulaNode)
	logger:debug("ImplyRight: Expanding "..natDNode:getLabel().. " and formula "..formulaNode:getLabel())
	
	local NewNatDNode, seqListNodes, seqListEdges = createNewSequent(natDNode)

	graph:addNodes(seqListNodes)
	graph:addEdges(seqListEdges)
	local nodeRight = NewNatDNode:getEdgeOut(lblEdgeDir):getDestino()
	local nodeLeft = NewNatDNode:getEdgeOut(lblEdgeEsq):getDestino()
	local newEdge1 = NatDEdge:new(lblEdgeDeducao, natDNode, NewNatDNode)

	newEdge1:setInformation("rule", opImp.tex.."\\mbox{right}-"..opImp.tex.."_{"..formulaNode:getLabel():sub(6,formulaNode:getLabel():len()).."}")		
	
	graph:addEdge(newEdge1)		

	local listEdgesOut = nodeRight:getEdgesOut()
	for i=1, #listEdgesOut do
		if listEdgesOut[i]:getDestino():getLabel() == formulaNode:getLabel() then
			labelEdgeRemoved = listEdgesOut[i]:getLabel()
			graph:removeEdge(listEdgesOut[i])
			break
		end
	end
	local newEdge2 = NatDEdge:new(labelEdgeRemoved, nodeRight, formulaNode:getEdgeOut(lblEdgeDir):getDestino())

	local numberEdgesLeft = #nodeLeft:getEdgesOut()
	local newEdge3 = NatDEdge:new(""..numberEdgesLeft, nodeLeft, formulaNode:getEdgeOut(lblEdgeEsq):getDestino())

	graph:addEdge(newEdge2)
	graph:addEdge(newEdge3)

	local lweight = goalsList[natDNode:getLabel()].weight
	goalsList[NewNatDNode:getLabel()] = {goal = generateNewGoal(NewNatDNode), weight = lweight}
	natDNode:setInformation("isExpanded", true)
	logger:info("applyImplyRightRule - "..natDNode:getLabel().." was expanded")			 

	return graph	  
end

local function applyImplyIntroRule(formulaNode)
	-- TODO
end

local function applyImplyElimRule(natDNode, formulaNode)
	logger:debug("ImplyElim: Expanding "..natDNode:getLabel().. " and formula "..formulaNode:getLabel())

	local NewNatDNode, natDListNodes, natDListEdges = createNewSequent(natDNode)

	graph:addNodes(seqListNodes)
	graph:addEdges(seqListEdges)

	local nodeRight = NewNatDNode:getEdgeOut(lblEdgeDir):getDestino()
	local nodeLeft = NewNatDNode:getEdgeOut(lblEdgeEsq):getDestino()
	local newEdge1 = NatDEdge:new(lblEdgeDeducao, natDNode, NewNatDNode)

	newEdge1:setInformation("rule", opImp.tex.."\\mbox{right}-"..opImp.tex.."_{"..formulaNode:getLabel():sub(6,formulaNode:getLabel():len()).."}")		
	

end

local function applyImplyRule(natDNode, formulaNode)

	local sideOfOperator = verifySideOfOperator(natDNode, formulaNode)		

	if sideOfOperator == leftSide then
		return applyImplyLeftRule(natDNode, formulaNode)
	elseif sideOfOperator == rightSide then
		return applyImplyRightRule(natDNode, formulaNode)
	elseif sideOfOperator == nil then
		return nil
	end			 

	return graph
end

-- Public functions

--- Create a graph from a formula in table form.
--- Returns a graph that represents the given formula.
--- @param form_table - Formula in table form.
function LogicModule.createGraphFromTable(form_table)
	local letters = {}
	sufix = 0
	--local graph = nil
	
	if form_table =="empty" then 
		graph = createGraphEmpty()
	else
		graph = createGraphNatD(form_table, letters)
	end

	return graph
end

--- Expand a operator in a sequent.
--- For a specific graph and a node of that graph, it expands the node if that node is an operator.
--- The operator node is only expanded if a sequent node were previusly selected.
--- @param agraph 
--- @param natDNode  
--- @param formulaNode 
function LogicModule.expandNode(agraph, natDNode, formulaNode)
	local typeOfNode = formulaNode:getInformation("type")
	
	graph = agraph

	if not natDNode:getInformation("isExpanded") then
		if typeOfNode == opImp.graph then					  
			graph = applyImplyRule(natDNode, formulaNode)  
		end
	end

	return true, graph		
end

function LogicModule.expandAll(agraph, pstep, natDNode)

	local isAllExpanded = true
	local k, goalEntry

	if natDNode then
		resetGoalsWeight(0)
		goalsList[natDNode:getLabel()].weight = 1
	end

	graph = agraph					
	
	for k,goalEntry in pairs(goalsList) do

		if goalEntry.weight == 1 then
		
			local seq = goalEntry.goal:getSequent()

			if not seq:getInformation("isExpanded") then
				logger:info("expandAll - Expanding seq "..k)
				
				isAllExpanded = false

				local formulaNode = nil
				local restartedFormulas = nil
				local leftExpandedFormula = nil
				local newSeq = nil
				local leftSide = goalEntry.goal:getLeftSide()
				local rightSide = goalEntry.goal:getRightSide()
				local expanded = false
				local restarted = false
				local edgesInLeft, restartedAtom

				table.sort(leftSide, compareFormulasDegree)

				if pstep == nil then
					nstep = 1
				else
					if tonumber(pstep) <= nstep then
						nstep = 0
						break
					else
						nstep = nstep + 1
					end
				end
				
				if tonumber(k:sub(4)) == 36 then
					local x = 10
				end			 

				if not verifyAxiom(seq) then
					local ret, rule, formulaNode = isExpandable(seq)

					if ret then
						if rule == lblRuleImplyRight then
							applyImplyRightRule(seq, formulaNode)
						elseif rule == lblRuleImplyLeft then
							applyImplyLeftRule(seq, formulaNode)
						elseif rule == lblRuleRestart then
							applyRestartRule(seq, formulaNode)
						end												
					else
						goalsList = {}
						nstep = 0
						logger:info("expandAll - "..seq:getLabel().." não pode mais ser expandido.")
						break							
					end						
				end		  
			end
		end		
	end

	local ret
	if not isAllExpanded and nstep ~= 0 then
		graph = LogicModule.expandAll(graph, pstep)
		ret = false
	else
		nstep = 0
		sufix = sufix + 1
		LogicModule.printProof(graph, tostring(sufix))
		os.showProofOnBrowser(tostring(sufix))
		logGoalsList()
		logger:info("expandAll - All sequents expanded!")
		ret = true
	end

	return graph, ret 
end

function LogicModule.getGraph()
	return graph
end

return LogicModule