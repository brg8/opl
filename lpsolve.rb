require "rglpk"

#TODO
#handle all relationships (<, >, =, <=, >=)
#handle constants in constraints and objectives

def sides(equation)
	if equation.include?("<")
		char = "<="
	elsif equation.include?(">")
		char = ">="
	elsif equation.include?("<=")
		char = "<"
	elsif equation.include?("<=")
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

def coefficients(equation)#parameter is one side of the equation
	equation = add_ones(equation)
	if equation[0]=="-"
		equation.scan(/[+-]\d+/)
	else
		("#"+equation).scan(/[#+-]\d+/).map{|e|e.gsub("#","+")}
	end
end

def variables(equation)#parameter is one side of the equation
	equation = add_ones(equation)
	equation.scan(/[a-z]+[\d]*/)
end

class LinearProgram
	attr_accessor :objective
	attr_accessor :constraints
	attr_accessor :rows

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

	def initialize(function, optimization)
		@function = function
		@optimization = optimization
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

def get_all_vars(constraints)
	all_vars = []
	constraints.each do |constraint|
		constraint = constraint.gsub(" ", "")
		value = constraint.split(":")[1] || constraint
		all_vars << variables(value)
	end
	all_vars.flatten.uniq
end

def subject_to(constraints)
	all_vars = get_all_vars(constraints)
	rows = []
	constraints.each do |constraint|
		constraint = constraint.gsub(" ", "")
		name = constraint.split(":")[0]
		value = constraint.split(":")[1] || constraint
		lower_bound = value.split(">=")[1] rescue nil
		upper_bound = value.split("<=")[1] rescue nil
		coefs = coefficients(sides(value)[:lhs])
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
	lp = LinearProgram.new(objective, rows_c.map{|row|row.constraint})
	lp.rows = rows_c
	p = Rglpk::Problem.new
	p.name = "sample"
	p.obj.dir = Rglpk::GLP_MAX
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
	obj_coefficients = coefficients(objective.gsub(" ","")).map{|c|c.to_i}
	obj_vars = variables(objective.gsub(" ",""))
	all_obj_coefficients = []
	all_vars.each do |var|
		i = obj_vars.index(var)
		coef = i.nil? ? 0 : obj_coefficients[i]
		all_obj_coefficients << coef
	end
	p.obj.coefs = all_obj_coefficients
	p.set_matrix(rows_c.map{|row|row.variable_coefficient_pairs.map{|vcp|vcp.coefficient.to_i}}.flatten)
	p.simplex
	z = p.obj.get
	answer = Hash.new()
	cols.each do |c|
		answer[c.name] = c.get_prim.to_s
	end
	answer
end
