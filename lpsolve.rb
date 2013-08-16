require "rglpk"

# maximize
#   z = 10 * x1 + 6 * x2 + 4 * x3
#
# subject to
#   p:      x1 +     x2 +     x3 <= 100
#   q: 10 * x1 + 4 * x2 + 5 * x3 <= 600
#   r:  2 * x1 + 2 * x2 + 6 * x3 <= 300
#
# where all variables are non-negative
#   x1 >= 0, x2 >= 0, x3 >= 0

=begin

maximize("10x1 + 6x2 + 4x3",
subject_to(["p: x1 + x2 + x3 <= 100",
"q: 10x1 + 4x2 + 5x3 <= 600",
"r: 2x1 + 2x2 + 6x3 <= 300",
"s: x1 >= 0",
"t: x2 >= 0",
"u: x3 >= 0"]))

=end

#The basic task is to parse an equation into it's parts:
#coefficients (+-), variables, relationships (<=, =>, =, <, >)
	#left side, right side
#just deal with integer coefficients for now

#equation.lhs.coefficients
#equation.lhs.variables
#equation.rhs.coefficients
#equation.rhs.variables
#equation.relationship

#to rebuild equation:
#equation.lhs.build = equation.lhs.coefficients.zip(equation.lhs.variables).join("+")
#equation.lhs.build+equation.relationship+equation.rhs.build

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
		equation = equation.gsub(p,q).gsub("#","")
	end
	equation
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

def elements(equation)
	letters = "abcdefghijklmnopqrstuvwxyz".split("")
	numbers = "1234567890".split("")
	#types are coefficient, variable, operator, relationship (c, v, o, r)
	equation = equation.gsub(" ","")
	equation.each do |char|
		if ["+","-","*"].include?(char)
			#operator
		elsif ["<=",">=","=","<",">"].include?(char)
			#relationship
		else
			if currently_parsing_variable
				#variable
			elsif currently_parsing_coefficient
				#coefficient
			elsif letters.include?(char)
				#variable
			elsif numbers.include?(char)
				#coefficient
			end
		end
	end
end

class Row
	attr_accessor :name
	attr_accessor :lower_bound
	attr_accessor :upper_bound
	attr_accessor :coefficients

	def initialize(name, lower_bound, upper_bound)
		@name = name
		@lower_bound = lower_bound
		@upper_bound = upper_bound
	end
end

class Column
	attr_accessor :name
	attr_accessor :lower_bound
	attr_accessor :upper_bound

	def initialize(name, lower_bound, upper_bound)
		@name = name
		@lower_bound = lower_bound
		@upper_bound = upper_bound
	end
end

def subject_to(constraints)
	rows = []
	constraints.each do |constraint|
		constraint = constraint.gsub(" ", "")
		name = constraint.split(":")[0]
		value = constraint.split(":")[1] rescue constraint
		lower_bound = value.split(">=")[1] rescue nil
		upper_bound = value.split("<=")[1] rescue nil
		row = Row.new(name, lower_bound, upper_bound)
		row.coefficients = coefficients(sides(value)[:lhs])
		rows << row
	end
	rows
end

def maximize(objective, rows_c)#objective function has no = in it
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
	obj_coefficients = coefficients(objective.gsub(" ","")).map{|c|c.to_i}
	vars = variables(objective.gsub(" ",""))
	cols = p.add_cols(vars.size)
	vars.each_index do |i|
		column_name = vars[i]
		cols[i].name = column_name
		cols[i].set_bounds(Rglpk::GLP_LO, 0.0, 0.0)
	end
	p.obj.coefs = obj_coefficients
	p.set_matrix(rows_c.map{|row|row.coefficients.map{|c|c.to_i}}.flatten)
	p.simplex
	z = p.obj.get
	answer = Hash.new()
	cols.each do |c|
		answer[c.name] = c.get_prim.to_s
	end
	answer
end
