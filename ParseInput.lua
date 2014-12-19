------------------------------------------------------------------------------
--   Parse Input Module
--
--   Utilitary module to parse formula input.
--
--   @authors: Vitor, Hermann, Jefferson
--
-------------------------------------------------------------------------------

require "Set"
require "logging" 
require "logging.file"

local lpeg = require "lpeg"
local atom_count = 0
local mimp_t = Set:new()
local logger = logging.file("aux/prover-SequentCalculus%s.log", "%Y-%m-%d")
logger:setLevel(logging.DEBUG)


local function table_atom(x)
   return (string.format("\"%s\"", x))
end

local function table_formula(f)
   if f.tag == "Atom" then 
      return("[ Atom "..table_atom(f[1]).." ]")
   elseif f.tag == "imp" then
      return("[ Imp"..table_formula(f[1])..","..table_formula(f[2]).."]")     
   elseif f.tag == "and" then
      return("[ And"..table_formula(f[1])..","..table_formula(f[2]).."]")     
   elseif f.tag == "or" then
      return("[ Or"..table_formula(f[1])..","..table_formula(f[2]).."]")     
   end 
end     

local function table_formulas(t)
   if #t > 0 then 
      local s = ""
      for i=1,#t do
	 p = p.." ( "..i..table_formula(t[i]).." ) "
      end    
   else 
      return(t.tag.."empty")
   end
end

print_Goal = function (t)
   io.write("[ Goal ")
   if #t > 0 then
      print_formulas(t[1])
      io.write(" SEQ ")
      print_formulas(t[2])
   end
   io.write("]")
end


local function print_ast(t)
   if t.tag == "Goal" then
      print_Goal(t)
   end
   print("nothing to print")
end

local function table_formula(t)
   if type(t) == "number" then 
      return(t)
   elseif type(t) == "string" then
      return(string.format("%s", t))     
   elseif type(t) == "table" then 
      local s = "{ "
      for k,v in pairs(t) do
	 s = s.."[ "..table_formula(k).."="..table_formula(v).." ]"
      end
      s = s.." }"
      return(s)
   else
      print("cannot convert table object")
   end 
end 

-- Lexical Elements
local Space = lpeg.S(" \n\t")
local skip = Space^0

local upper = lpeg.R("AZ")
local lower = lpeg.R("az")
local letter = upper + lower
local dig = lpeg.R("09")^0

local Atom = lpeg.C(letter * dig) * skip

local function getcontents(filename)
   file = assert(io.open(filename, "r"))
   contents = file:read("*a")
   file:close()
   return contents
end

local function token(pat)
   return pat * skip
end

local function kw(str)
   return token (lpeg.P(str))
end

local function symb(str)
   return token (lpeg.P(str))
end

local function taggedCap(tag, pat)
   return lpeg.Ct(lpeg.Cg(lpeg.Cc(tag), "tag") * pat)
end

function parse_input(contents)
   -- Grammar
   local formula = lpeg.V("formula")
   local form, factor, term = lpeg.V("form"), lpeg.V("factor"), lpeg.V("term")
   local term_imp, term_and, term_or = lpeg.V("term_imp"), lpeg.V("term_and"), lpeg.V("term_or")
   local Atomo = taggedCap("Atom", token(Atom))
   G = lpeg.P{ 
      formula,
      formula = skip * form * skip * -1;
      form = term + factor;
      factor = taggedCap("Atom", token(Atom)) + symb("(") * form * symb(")");
      term = term_imp + term_and + term_or;
      term_imp = taggedCap("imp", factor * kw("imp") * symb("(") * form * symb(")"));
      term_and = taggedCap("and", factor * kw("and") * symb("(") * form * symb(")")); 
      term_or = taggedCap("or", factor * kw("or") * symb("(") * form * symb(")"));       
   }

   local t = lpeg.match(G, contents)
   if not t then
      error({msg="falha no reconhecimento de "..contents})
   end

   ast = table_formula(t)
   return(ast)
end

local function fresh_atom()
   local ret = "p"..atom_count

   atom_count = atom_count + 1
   return ret
end

-- Recursivelly replace formulas by propositional letters
--
-- @param formula a formula, in table format which will have its
--               non-MIMP subformulas translated in new propostional letters
-- @return a propositonal representation of non-MIMP (sub)formulas as string
local function mimp(formula)
   local formula_s = tabletostring(formula)
   
   if mimp_t[formula_s] then
      return mimp_t[formula_s]
   else
      if formula["tag"] == "Atom" then
         return formula["1"]
      elseif formula["tag"] == "imp" then
         return "("..mimp(formula["1"]).." imp ("..mimp(formula["2"]).."))"
      elseif formula["tag"] == "and" then
         return fresh_atom()
      elseif formula["tag"] == "or" then
         return fresh_atom()
      end
   end
end

-- Recursivelly builds a set of axioms to make the translation to MIMP Logic
-- 
-- @param alpha the initial formula to be translated, in table format.
-- @param formula subformulas of the initial formula to be examined recursivelly.
-- @return a set of axioms of MIMP Logic in table format.
local function axioms(alpha, formula)
   
   local set1
   local set2
   
   if formula["tag"] == "Atom" then
      return Set:new()
      
   elseif formula["tag"] == "imp" then
      set1 = axioms(alpha, formula["1"])
      set2 = axioms(alpha, formula["2"])
      return set1:union(set2)
      
   elseif formula["tag"] == "and" then
      local formula_s = tabletostring(formula)
      local formula_esq_s = tabletostring(formula["1"])
      local formula_dir_s = tabletostring(formula["2"])  
      
      local p = mimp_t[formula_s]

      local axiom1 = parse_input(mimp_t[formula_esq_s].." imp ("..mimp_t[formula_dir_s].." imp ("..p.."))")
      local axiom2 = parse_input(p.." imp ("..mimp_t[formula_esq_s]..")")
      local axiom3 = parse_input(p.." imp ("..mimp_t[formula_dir_s]..")")
      
      local axiom1_t = stringtotable(axiom1)
      local axiom2_t = stringtotable(axiom2)
      local axiom3_t = stringtotable(axiom3)
      
      local axioms_set = Set:new({axiom1_t, axiom2_t, axiom3_t})

      set1 = axioms_set:union(axioms(alpha, formula["1"]))
      set2 = set1:union(axioms(alpha, formula["2"]))
      
      return set2
      
   elseif formula["tag"] == "or" then
      local formula_s = tabletostring(formula)
      local formula_esq_s = tabletostring(formula["1"])
      local formula_dir_s = tabletostring(formula["2"])  
      
      local q = mimp_t[formula_s]

      local axiom1 = parse_input(mimp_t[formula_esq_s].." imp ("..q..")")   
      local axiom2 = parse_input(mimp_t[formula_dir_s].." imp ("..q..")")
      local axiom1_t = stringtotable(axiom1)
      local axiom2_t = stringtotable(axiom2)
      local axioms_set = Set:new({axiom1_t, axiom2_t})

      local axioms_sub = nil
      local axioms_sub_t = nil
      local axioms_sub_set = Set:new() 
      for k,_ in pairs(mimp_t) do
         axioms_sub = parse_input("("..mimp_t[formula_esq_s].." imp (".. mimp_t[k]..")) imp (("..mimp_t[formula_dir_s].." imp ("..mimp_t[k]..")) imp (("..
                                     q.." imp ("..mimp_t[k].."))))")
         axioms_sub_t = stringtotable(axioms_sub)
         axioms_sub_set:add(axioms_sub_t)
      end

      local set_or = axioms_set:union(axioms_sub_set)
      
      set1 = set_or:union(axioms(alpha, formula["1"]))
      set2 = set1:union(axioms(alpha, formula["2"]))

      return set2
   end
   
end

local function subformulas(formula)
   
   if formula["tag"] == "Atom" then
      return  Set:new({tabletostring(formula)})
   else
      local sub1_set = subformulas(formula["1"])
      local sub2_set = subformulas(formula["2"])
      local sub1_u_sub2 = sub1_set:union(sub2_set)
      
      local actual_formula = Set:new({tabletostring(formula)})
      local subformulas_set = sub1_u_sub2:union(actual_formula)

      return subformulas_set
   end
end


-- Translates formulas from Intuitionistic Logic to Minimal Implicational Logic
--
-- @param t_formula a formula parsed into table format
-- @return a translated formula in table format 
function implicational(t_formula)

   local subformulas_set = subformulas(t_formula)

   local l = {}
   for k,_ in pairs(subformulas_set) do 
      table.insert(l, k)
   end
   
   table.sort(l, function (a,b) return (string.len(a) < string.len(b)) end)
   
   for k,v in pairs(l) do
      local new_v = mimp(stringtotable(parse_input(v)))
      mimp_t[v] = new_v      
   end

   local axiom_set = axioms(t_formula, t_formula)

   local s = stringtotable(parse_input(mimp_t[tabletostring(t_formula)]))
   
   for k,_ in pairs(axiom_set) do
      s = {["1"] = k, ["2"] = s, ["tag"] = "imp"}
   end
   
   return s
end
