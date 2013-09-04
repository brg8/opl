require "rglpk"

#TODO
#1.0

#2.0
#summing of variables
	#e.g. x1 + x1 <= 3
#need to be able to handle arithmetic operations
	#within a constraint or index
		#e.g. sum(i in (1..3), x[i-1])
#a matrix representation of the solution if using
	#sub notation

#3.0
#will have to figure out "<" and ">"
#make sure extreme cases of foralls and sums
	#are handled
#multiple level sub notation e.g. x[1][[3]]

#write as module

def sides(equation)
	if equation.include?("<=")
		char = "<="
	elsif equation.include?(">=")
		char = ">="
	elsif equation.include?("<")
		char = "<"
	elsif equation.include?(">")
		char = ">"
	elsif equation.include?("=")
		char = "="
	end
	sides = equation.split(char)
	{:lhs => sides[0], :rhs => sides[1]}
end

def add_ones(equation)
	equation = "#"+equation
	equation.scan(/[#+-][a-z]/).each do |p|
		if p.include?("+")
			q = p.gsub("+", "+1*")
		elsif p.include?("-")
			q = p.gsub("-","-1*")
		elsif p.include?("#")
			q = p.gsub("#","#1*")
		end
		equation = equation.gsub(p,q)
	end
	equation.gsub("#","")
end

def paren_to_array(text)
	#in: "(2..5)"
	#out: "[2,3,4,5]"
	start = text[1].to_i
	stop = text[-2].to_i
	(start..stop).map{|i|i}.to_s
end

def sub_paren_with_array(text)
	targets = text.scan(/\([\d]+\.\.[\d]+\)/)
	targets.each do |target|
		text = text.gsub(target, paren_to_array(target))
	end
	return(text)
end

def mass_product(array_of_arrays, base=[])
	return(base) if array_of_arrays.empty?
	array = array_of_arrays[0]
	new_array_of_arrays = array_of_arrays[1..-1]
	if base==[]
		mass_product(new_array_of_arrays, array)
	else
		mass_product(new_array_of_arrays, base.product(array).map{|e|e.flatten})
	end
end

def forall(text)
	#need to be able to handle sums inside here
	#in: "i in (0..2), x[i] <= 5"
	#out: ["x[0] <= 5", "x[1] <= 5", "x[2] <= 5"]
	text = sub_paren_with_array(text)
	final_constraints = []
	indices = text.scan(/[a-z] in/).map{|sc|sc[0]}
	values = text.scan(/\s\[[\-\s\d+,]+\]/).map{|e|e.gsub(" ", "").scan(/[\-\d]+/)}
	index_value_pairs = indices.zip(values)
	variable = text.scan(/[a-z]\[/)[0].gsub("[","")
	#will need to make this multiple variables??
		#or is this even used at all????
	value_combinations = mass_product(values)
	value_combinations.each_index do |vc_index|
		value_combination = value_combinations[vc_index]
		value_combination = [value_combination] unless value_combination.is_a?(Array)
		if text.include?("sum")
			constraint = "sum"+text.split("sum")[1..-1].join("sum")
		else
			constraint = text.split(",")[-1].gsub(" ","")
		end
		e = constraint
		value_combination.each_index do |i|
			index = indices[i]
			value = value_combination[i]
			e = e.gsub("("+index, "("+value)
			e = e.gsub(index+")", value+")")
			e = e.gsub("["+index, "["+value)
			e = e.gsub(index+"]", value+"]")
			e = e.gsub("=>"+index, "=>"+value)
			e = e.gsub("<="+index, "<="+value)
			e = e.gsub(">"+index, ">"+value)
			e = e.gsub("<"+index, "<"+value)
			e = e.gsub("="+index, "="+value)
			e = e.gsub("=> "+index, "=> "+value)
			e = e.gsub("<= "+index, "<= "+value)
			e = e.gsub("> "+index, "> "+value)
			e = e.gsub("< "+index, "< "+value)
			e = e.gsub("= "+index, "= "+value)
		end
		final_constraints += [e]
	end
	final_constraints
end

def sub_forall(equation, indexvalues={:indices => [], :values => []})
	#in: "forall(i in (0..2), x[i] <= 5)"
	#out: ["x[0] <= 5", "x[1] <= 5", "x[2] <= 5"]
	return equation unless equation.include?("forall")
	foralls = (equation+"#").split("forall(").map{|ee|ee.split(")")[0..-2].join(")")}.find_all{|eee|eee!=""}
	constraints = []
	if foralls.empty?
		return(equation)
	else
		foralls.each do |text|
			constraints << forall(text)
		end
		return(constraints.flatten)
	end
end

def sum(text, indexvalues={:indices => [], :values => []})
	#in: "i in [0,1], j in [4,-5], 3x[i][j]"
	#out: "3x[0][4] + 3x[0][-5] + 3x[1][4] + 3x[1][-5]"
	text = sub_paren_with_array(text)
	final_text = ""
	element = text.split(",")[-1].gsub(" ","")
	indices = text.scan(/[a-z] in/).map{|sc|sc[0]}
	input_indices = indexvalues[:indices] - indices
	if not input_indices.empty?
		input_values = input_indices.map{|ii|indexvalues[:values][indexvalues[:indices].index(ii)]}
	else
		input_values = []
	end
	values = text.scan(/\s\[[\-\s\d+,]+\]/).map{|e|e.gsub(" ", "").scan(/[\-\d]+/)}
	indices += input_indices
	values += input_values
	index_value_pairs = indices.zip(values)
	variable = text.scan(/[a-z]\[/)[0].gsub("[","")
	coefficient_a = text.split(",")[-1].split("[")[0].scan(/\-?[\d\*]+[a-z]/)
	if coefficient_a.empty?
		if text.split(",")[-1].split("[")[0].include?("-")
			coefficient = "-1"
		else
			coefficient = "1"
		end
	else
		coefficient = coefficient_a[0].scan(/[\d\-]+/)
	end
	value_combinations = mass_product(values)
	value_combinations.each_index do |vc_index|
		value_combination = value_combinations[vc_index]
		e = element
		value_combination = [value_combination] unless value_combination.is_a?(Array)
		value_combination.each_index do |i|
			index = indices[i]
			value = value_combination[i]
			e = e.gsub("("+index, "("+value)
			e = e.gsub(index+")", value+")")
			e = e.gsub("["+index, "["+value)
			e = e.gsub(index+"]", value+"]")
			e = e.gsub("=>"+index, "=>"+value)
			e = e.gsub("<="+index, "<="+value)
			e = e.gsub(">"+index, ">"+value)
			e = e.gsub("<"+index, "<"+value)
			e = e.gsub("="+index, "="+value)
			e = e.gsub("=> "+index, "=> "+value)
			e = e.gsub("<= "+index, "<= "+value)
			e = e.gsub("> "+index, "> "+value)
			e = e.gsub("< "+index, "< "+value)
			e = e.gsub("= "+index, "= "+value)
		end
		e = "+"+e unless (coefficient.include?("-") || vc_index==0)
		final_text += e
	end
	final_text
end

def sub_sum(equation, indexvalues={:indices => [], :values => []})
	#in: "sum(i in (0..3), x[i]) <= 100"
	#out: "x[0]+x[1]+x[2]+x[3] <= 100"
	sums = (equation+"#").split("sum(").map{|ee|ee.split(")")[0..-2].join(")")}.find_all{|eee|eee!=""}.find_all{|eeee|!eeee.include?("forall")}
	sums.each do |text|
		e = text
		unless indexvalues[:indices].empty?
			indexvalues[:indices].each_index do |i|
				index = indexvalues[:indices][i]
				value = indexvalues[:values][i].to_s
				e = e.gsub("("+index, "("+value)
				e = e.gsub(index+")", value+")")
				e = e.gsub("["+index, "["+value)
				e = e.gsub(index+"]", value+"]")
				e = e.gsub("=>"+index, "=>"+value)
				e = e.gsub("<="+index, "<="+value)
				e = e.gsub(">"+index, ">"+value)
				e = e.gsub("<"+index, "<"+value)
				e = e.gsub("="+index, "="+value)
				e = e.gsub("=> "+index, "=> "+value)
				e = e.gsub("<= "+index, "<= "+value)
				e = e.gsub("> "+index, "> "+value)
				e = e.gsub("< "+index, "< "+value)
				e = e.gsub("= "+index, "= "+value)
			end
		end
		equation = equation.gsub(text, e)
		result = sum(text)
		equation = equation.gsub("sum("+text+")", result)
	end
	return(equation)
end

def coefficients(equation)#parameter is one side of the equation
	equation = add_ones(equation)
	if equation[0]=="-"
		equation.scan(/[+-][\d\.]+/)
	else
		("#"+equation).scan(/[#+-][\d\.]+/).map{|e|e.gsub("#","+")}
	end
end

def variables(equation)#parameter is one side of the equation
	equation = add_ones(equation)
	equation.scan(/[a-z]+[\[\]\d]*/)
end

class LinearProgram
	attr_accessor :objective
	attr_accessor :constraints
	attr_accessor :rows
	attr_accessor :solution

	def initialize(objective, constraints)
		@objective = objective
		@constraints = constraints
		@rows = []
	end
end

class Objective
	attr_accessor :function
	attr_accessor :optimization#minimize, maximize, equals
	attr_accessor :variable_coefficient_pairs
	attr_accessor :optimized_value

	def initialize(function, optimization)
		@function = function
		@optimization = optimization
	end
end

class Row
	attr_accessor :name
	attr_accessor :constraint
	attr_accessor :lower_bound
	attr_accessor :upper_bound
	attr_accessor :variable_coefficient_pairs

	def initialize(name, lower_bound, upper_bound)
		@name = name
		@lower_bound = lower_bound
		@upper_bound = upper_bound
		@variable_coefficient_pairs = []
	end
end

class VariableCoefficientPair
	attr_accessor :variable
	attr_accessor :coefficient

	def initialize(variable, coefficient)
		@variable = variable
		@coefficient = coefficient
	end
end

def get_all_vars(constraints)
	all_vars = []
	constraints.each do |constraint|
		constraint = constraint.gsub(" ", "")
		value = constraint.split(":")[1] || constraint
		all_vars << variables(value)
	end
	all_vars.flatten.uniq
end

def get_constants(text)
	#in: "-8 + x + y + 3"
	#out: "[-8, +3]"
	text = text.gsub(" ","")
	text = text+"#"
	cs = []
	potential_constants = text.scan(/[\d\.]+[^a-z^\[^\]^\d^\.^\)]/)
	#potential_constants = text.scan(/\d+[^a-z^\[^\]^\d]/)
	constants = potential_constants.find_all{|c|![*('a'..'z'),*('A'..'Z')].include?(text[text.index(c)-1])}
	constants.each do |constant|
		c = constant.scan(/[\d\.]+/)[0]
		index = text.index(constant)
		if index == 0
			c = "+"+c
		else
			c = text.scan(/[\-\+]#{constant}/)[0]
		end
		cs << c.scan(/[\-\+][\d\.]+/)[0]
	end
	return({:formatted => cs, :unformatted => constants})
end

def put_constants_on_rhs(text)
	#in: "-8 + x + y + 3 <= 100"
	#out: "x + y <= 100 + 5"
	text = text.gsub(" ","")
	s = sides(text)
	constants_results = get_constants(s[:lhs])
	constants = constants_results[:formatted]
	unless constants.empty?
		sum = constants.map{|cc|cc.to_f}.inject("+").to_s
		if sum.include?("-")
			sum = sum.gsub("-","+")
		else
			sum = "-"+sum
		end
		lhs = s[:lhs].gsub(" ","")+"#"
		constants_results[:unformatted].each do |constant|
			index = lhs.index(constant)
			if index == 0
				lhs = lhs[(constant.size-1)..(lhs.size-1)]
			else
				lhs = lhs[0..(index-2)]+lhs[(index+(constant.size-1))..(lhs.size-1)]
			end
		end
		text = text.gsub(s[:lhs], lhs[0..-2])
		text += sum
	end
	return(text)
end

def sum_constants(text)
	#in: "100+ 10-3"
	#out: "107"
	constants = get_constants(text)[:formatted]
	if constants.to_s.include?(".")
		constants.map{|c|c.to_f}.inject("+").to_s
	else
		constants.map{|c|c.to_i}.inject("+").to_s
	end
end

def sub_rhs_with_summed_constants(constraint)
	rhs = sides(constraint)[:rhs]
	constraint.gsub(rhs, sum_constants(rhs))
end

def get_coefficient_variable_pairs(text)
	text.scan(/\d*[\*]*[a-z]\[*\d*\]*/)
end

def put_variables_on_lhs(text)
	#in: "x + y - x[3] <= 3z + 2x[2] - 10"
	#out: "x + y - x[3] - 3z - 2x[2] <= -10"
	text = text.gsub(" ", "")
	s = sides(text.gsub(" ",""))
	rhs = s[:rhs]
	lhs = s[:lhs]
	coefficient_variable_pairs = get_coefficient_variable_pairs(rhs)
	add_to_left = []
	remove_from_right = []
	coefficient_variable_pairs.each do |cvp|
		index = rhs.index(cvp)
		if index == 0
			add_to_left << "-"+cvp
			remove_from_right << cvp
		else
			if rhs[index-1] == "+"
				add_to_left << "-"+cvp
				remove_from_right << "+"+cvp
			else
				add_to_left << "+"+cvp
				remove_from_right << "-"+cvp
			end
		end
	end
	new_lhs = lhs+add_to_left.join("")
	text = text.gsub(lhs, new_lhs)
	new_rhs = rhs
	remove_from_right.each do |rfr|
		new_rhs = new_rhs.gsub(rfr, "")
	end
	text = text.gsub(rhs, new_rhs)
	return(text)
end

def split_equals(constraint)
	[constraint.gsub("=", "<="), constraint.gsub("=", ">=")]
end

def split_equals_a(constraints)
	constraints.map do |constraint|
		if (constraint.split("") & ["<=",">=","<",">"]).empty?
			split_equals(constraint)
		else
			constraint
		end
	end.flatten
end

def subject_to(constraints)
	constraints = constraints.flatten
	constraints = split_equals_a(constraints)
	constraints = constraints.map do |constraint|
		sub_forall(constraint)
	end.flatten
	constraints = constraints.map do |constraint|
		sub_sum(constraint)
	end
	constraints = constraints.map do |constraint|
		put_constants_on_rhs(constraint)
	end
	constraints = constraints.map do |constraint|
		put_variables_on_lhs(constraint)
	end
	constraints = constraints.map do |constraint|
		sub_rhs_with_summed_constants(constraint)
	end
	all_vars = get_all_vars(constraints)
	rows = []
	constraints.each do |constraint|
		negate = false
		constraint = constraint.gsub(" ", "")
		name = constraint.split(":")[0]
		value = constraint.split(":")[1] || constraint
		lower_bound = nil
		if value.include?("<=")
			upper_bound = value.split("<=")[1]
		elsif value.include?(">=")
			negate = true
			bound = value.split(">=")[1].to_f
			upper_bound = (bound*-1).to_s
		elsif value.include?("<")
			upper_bound = (value.split("<")[1]).to_f - 1
		elsif value.include?(">")
			negate = true
			bound = (value.split(">")[1]).to_f + 1
			upper_bound = (bound*-1).to_s
		end
		coefs = coefficients(sides(value)[:lhs])
		if negate
			coefs = coefs.map do |coef|
				if coef.include?("+")
					coef.gsub("+", "-")
				elsif coef.include?("-")
					coef.gsub("-", "+")
				end
			end
		end
		vars = variables(sides(value)[:lhs])
		zero_coef_vars = all_vars - vars
		row = Row.new(name, lower_bound, upper_bound)
		row.constraint = constraint
		coefs = coefs + zero_coef_vars.map{|z|0}
		vars = vars + zero_coef_vars
		zipped = vars.zip(coefs)
		pairs = []
		all_vars.each do |var|
			coef = coefs[vars.index(var)]
			pairs << VariableCoefficientPair.new(var, coef)
		end
		row.variable_coefficient_pairs = pairs
		rows << row
	end
	rows
end

def maximize(objective, rows_c)#objective function has no = in it
	optimize("maximize", objective, rows_c)
end

def minimize(objective, rows_c)#objective function has no = in it
	optimize("minimize", objective, rows_c)
end

def optimize(optimization, objective, rows_c)
	o = Objective.new(objective, optimization)
	lp = LinearProgram.new(o, rows_c.map{|row|row.constraint})
	objective = sub_sum(objective)
	objective_constants = get_constants(objective)
	if objective_constants[:formatted].empty?
		objective_addition = 0
	else
		objective_addition = sum_constants(objective_constants[:formatted].inject("+"))
	end
	lp.rows = rows_c
	p = Rglpk::Problem.new
	p.name = "sample"
	if optimization == "maximize"
		p.obj.dir = Rglpk::GLP_MAX
	elsif optimization == "minimize"
		p.obj.dir = Rglpk::GLP_MIN
	end
	rows = p.add_rows(rows_c.size)
	rows_c.each_index do |i|
		row = rows_c[i]
		rows[i].name = row.name
		rows[i].set_bounds(Rglpk::GLP_UP, 0.0, row.upper_bound) unless row.upper_bound.nil?
		rows[i].set_bounds(Rglpk::GLP_LO, 0.0, row.lower_bound) unless row.lower_bound.nil?
	end
	vars = rows_c.first.variable_coefficient_pairs.map{|vcp|vcp.variable}
	cols = p.add_cols(vars.size)
	vars.each_index do |i|
		column_name = vars[i]
		cols[i].name = column_name
		cols[i].set_bounds(Rglpk::GLP_LO, 0.0, 0.0)
	end
	all_vars = rows_c.first.variable_coefficient_pairs.map{|vcp|vcp.variable}
	obj_coefficients = coefficients(objective.gsub(" ","")).map{|c|c.to_f}
	obj_vars = variables(objective.gsub(" ",""))
	all_obj_coefficients = []
	all_vars.each do |var|
		i = obj_vars.index(var)
		coef = i.nil? ? 0 : obj_coefficients[i]
		all_obj_coefficients << coef
	end
	p.obj.coefs = all_obj_coefficients
	p.set_matrix(rows_c.map{|row|row.variable_coefficient_pairs.map{|vcp|vcp.coefficient.to_f}}.flatten)
	p.simplex
	lp.objective.optimized_value = p.obj.get + objective_addition.to_f
	answer = Hash.new()
	cols.each do |c|
		answer[c.name] = c.get_prim.to_s
	end
	lp.solution = answer
	lp
end
