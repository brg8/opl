require "rglpk"

#TODO
#unbounded or conflicting bounds messages
#	e.g.
#		lp = maximize(
#			"x",
#		subject_to([
#			"x >= 0"
#		]))
#
#should return an error message

#2.4
#catch this error for sum() in forall()
	#"forall(i in (0..2), sum(j in (0..2), x[i][j] = 1))"
	#should be:
	#"forall(i in (0..2), sum(j in (0..2), x[i][j]) = 1)"

#3.0
#multiple level sub notation e.g. x[1][[3]]
	#why would one use that notation rather than x[1][3]???

#3.1
#make sure extreme cases of foralls and sums
	#are handled

#4.0
#absolute value: abs()

#4.1
#if --> then statements

#4.2
#or statements

#4.3
#piecewise statements

#4.4
#duals, sensitivity, etc. - I could simply allow
	#access to the rglpk object wrapper

$default_epsilon = 0.01

class String
	def paren_to_array
		#in: "(2..5)"
		#out: "[2,3,4,5]"
		text = self
		start = text[1].to_i
		stop = text[-2].to_i
		(start..stop).map{|i|i}.to_s
	end

	def sub_paren_with_array
		text = self
		targets = text.scan(/\([\d]+\.\.[\d]+\)/)
		targets.each do |target|
			text = text.gsub(target, target.paren_to_array)
		end
		return(text)
	end

	def to_array(current_array=[self])
		#in: "[1,2,[3,4],[4,2,[3,2,[4,2]]],2,[4,2]]"
		#out: [1,2,[3,4],[4,2,[3,2,[4,2]]],2,[4,2]]
		def current_level_information(b)
			b = b.gsub(" ","")
			stripped_array = b[1..-2]
			in_array = 0
			inside_arrays_string = ""
			inside_values_string = ""
			stripped_array.split("").each do |char|
				if char == "["
					in_array += 1
				elsif char == "]"
					in_array += -1
				end
				if (in_array > 0) || (char == "]")
					inside_arrays_string += char
				end
			end
			stripped_array_without_arrays = stripped_array
			inside_arrays_string.gsub("][","],,,[").split(",,,").each do |str|
				stripped_array_without_arrays = stripped_array_without_arrays.gsub(str,"")
			end
			inside_values_string = stripped_array_without_arrays.split(",").find_all{|e|e!=""}.join(",")
			return {:values => inside_values_string, :arrays => inside_arrays_string}
		end
		if !current_array.join(",").include?("[")
			return(current_array)
		else
			a = []
			element = current_array.find_all{|e|e.include?("[")}.first
			i = current_array.index(element)
			info = current_level_information(element)
			info[:values].split(",").each do |v|
				a << v
			end
			info[:arrays].gsub("][","],,,[").split(",,,").each do |v|
				a << v.to_array
			end
			current_array[i] = a
			return(current_array[0])
		end
	end

	def to_a
		self.to_array
	end
end

class Array
	def dimension
		a = self
		return 0 if a.class != Array
		result = 1
		a.each do |sub_a|
			if sub_a.class == Array
				dim = sub_a.dimension
				result = dim + 1 if dim + 1 > result
			end
		end
		return result
	end

	def values_at_a(indices, current_array=self)
		#in: self = [3,4,[6,5,[3,4]],3], indices = [2,2,0]
		#out: 3
		if indices.size == 1
			return(current_array[indices[0]])
		else
			values_at_a(indices[1..-1], current_array[indices[0]])
		end
	end

	def inject_dim(int)
		arr = self
		int.times do
			arr << []
		end
		arr
	end

	def matrix(int_arr, current_arr=[])		
		int = int_arr[0]
		new_int_arr = int_arr[1..-1]
		if int_arr.empty?
			return(current_arr)
		else
			if current_arr.empty?
				new_arr = current_arr.inject_dim(int)
				self.matrix(new_int_arr, new_arr)
			else
				current_arr.each do |arr|
					arr.matrix(int_arr, arr)
				end
			end
		end
	end

	def insert_at(position_arr, value)
		arr = self
		if position_arr.size == 1
			arr[position_arr[0]] = value
			return(arr)
		else
			arr[position_arr[0]].insert_at(position_arr[1..-1], value)
		end				
	end
end

class OPL
	class Helper
		def self.mass_product(array_of_arrays, base=[])
			return(base) if array_of_arrays.empty?
			array = array_of_arrays[0]
			new_array_of_arrays = array_of_arrays[1..-1]
			if base==[]
				self.mass_product(new_array_of_arrays, array)
			else
				self.mass_product(new_array_of_arrays, base.product(array).map{|e|e.flatten})
			end
		end

		def self.forall(text)
			#in: "i in (0..2), x[i] <= 5"
			#out: ["x[0] <= 5", "x[1] <= 5", "x[2] <= 5"]
			helper = self
			text = text.sub_paren_with_array
			if ((text.gsub(" ","")).scan(/\]\,/).size) + ((text.gsub(" ","")).scan(/\)\,/).size) != text.gsub(" ","").scan(/in/).size
				raise "The following forall() constraint is incorrectly formatted: #{text}. Please see the examples in test.rb for forall() constraints. I suspect you are missing a comma somewhere."
			end
			final_constraints = []
			if text.include?("sum")
				indices = text.split("sum")[0].scan(/[a-z] in/).map{|sc|sc[0]}
				values = text.split("sum")[0].scan(/\s\[[\-\s\d+,]+\]/).map{|e|e.gsub(" ", "").scan(/[\-\d]+/)}
			else
				indices = text.scan(/[a-z] in/).map{|sc|sc[0]}
				values = text.scan(/\s\[[\-\s\d+,]+\]/).map{|e|e.gsub(" ", "").scan(/[\-\d]+/)}
			end
			#TODO: the indices and values should only be those
				#of the forall(), not of any sum() that is
				#inside the forall()
			index_value_pairs = indices.zip(values)
			variable = text.scan(/[a-z]\[/)[0].gsub("[","")
			value_combinations = helper.mass_product(values)
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

		def self.sub_forall(equation, indexvalues={:indices => [], :values => []})
			#in: "forall(i in (0..2), x[i] <= 5)"
			#out: ["x[0] <= 5", "x[1] <= 5", "x[2] <= 5"]
			return equation unless equation.include?("forall")
			foralls = (equation+"#").split("forall(").map{|ee|ee.split(")")[0..-2].join(")")}.find_all{|eee|eee!=""}
			constraints = []
			if foralls.empty?
				return(equation)
			else
				foralls.each do |text|
					constraints << self.forall(text)
				end
				return(constraints.flatten)
			end
		end

		def self.sides(text)
			equation = text
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

		def self.add_ones(text, lp)
			equation = text
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

		def self.sum(text, lp, indexvalues={:indices => [], :values => []})
			#in: "i in [0,1], j in [4,-5], 3x[i][j]"
			#out: "3x[0][4] + 3x[0][-5] + 3x[1][4] + 3x[1][-5]"
			text = text.sub_paren_with_array
			if (text.gsub(" ","")).scan(/\]\,/).size != text.scan(/in/).size
				raise "The following sum() constraint is incorrectly formatted: #{text}. Please see the examples in test.rb for sum() constraints. I suspect you are missing a comma somewhere."
			end
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
			value_combinations = OPL::Helper.mass_product(values)
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

		def self.sub_sum(equation, lp, indexvalues={:indices => [], :values => []})
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
				result = self.sum(text, lp)
				equation = equation.gsub("sum("+text+")", result)
			end
			return(equation)
		end

		def self.coefficients(text, lp)#text is one side of the equation
			equation = self.add_ones(text, lp)
			if equation[0]=="-"
				equation.scan(/[+-][\d\.]+/)
			else
				("#"+equation).scan(/[#+-][\d\.]+/).map{|e|e.gsub("#","+")}
			end
		end

		def self.data_coefficients

		end

		def self.variables(text, lp)#parameter is one side of the equation
			equation = self.add_ones(text, lp)
			equation.scan(/[a-z]+[\[\]\d]*/)
		end

		def self.get_all_vars(constraints, lp)
			all_vars = []
			constraints.each do |constraint|
				constraint = constraint.gsub(" ", "")
				value = constraint.split(":")[1] || constraint
				all_vars << self.variables(value, lp)
			end
			all_vars.flatten.uniq
		end

		def self.get_constants(text)
			#in: "-8 + x + y + 3"
			#out: "[-8, +3]"
			text = text.gsub(" ","")
			text = text+"#"
			cs = []
			potential_constants = text.scan(/[\d\.]+[^a-z^\[^\]^\d^\.^\)^\*]/)
			constants = potential_constants.find_all{|c|![*('a'..'z'),*('A'..'Z'),"["].include?(text[text.index(c)-1])}
			searchable_text = text
			constants.each_index do |i|
				constant = constants[i]
				c = constant.scan(/[\d\.]+/)[0]
				index = searchable_text.index(constant)
				if index == 0
					c = "+"+c
				else
					constant = constant.gsub('+','[+]')
					constant = constant.gsub('-','[-]')
					c = searchable_text.scan(/[\-\+]#{constant}/)[0]
				end
				cs << c.scan(/[\-\+][\d\.]+/)[0]
				searchable_text[index] = "**"
			end
			return({:formatted => cs, :unformatted => constants})
		end

		def self.put_constants_on_rhs(text)
			#in: "-8 + x + y + 3 <= 100"
			#out: "x + y <= 100 + 5"
			text = text.gsub(" ","")
			s = self.sides(text)
			constants_results = self.get_constants(s[:lhs])
			constants = []
			constants_results[:formatted].each_index do |i|
				formatted_constant = constants_results[:formatted][i]
				unformatted_constant = constants_results[:unformatted][i]
				unless unformatted_constant.include?("*")
					constants << formatted_constant
				end
			end
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

		def self.sum_constants(text)
			#in: "100+ 10-3"
			#out: "107"
			constants = self.get_constants(text)[:formatted]
			if constants.to_s.include?(".")
				constants.map{|c|c.to_f}.inject("+").to_s
			else
				constants.map{|c|c.to_i}.inject("+").to_s
			end
		end

		def self.sub_rhs_with_summed_constants(constraint)
			rhs = self.sides(constraint)[:rhs]
			constraint.gsub(rhs, self.sum_constants(rhs))
		end

		def self.get_coefficient_variable_pairs(text)
			text.scan(/\d*[\*]*[a-z]\[*\d*\]*/)
		end

		def self.operator(constraint)
			if constraint.include?(">=")
				">="
			elsif constraint.include?("<=")
				"<="
			elsif constraint.include?(">")
				">"
			elsif constraint.include?("<")
				"<"
			elsif constraint.include?("=")
				"="
			end
		end

		def self.put_variables_on_lhs(text)
			#in: "x + y - x[3] <= 3z + 2x[2] - 10"
			#out: "x + y - x[3] - 3z - 2x[2] <= -10"
			text = text.gsub(" ", "")
			s = self.sides(text)
			oper = self.operator(text)
			rhs = s[:rhs]
			lhs = s[:lhs]
			coefficient_variable_pairs = self.get_coefficient_variable_pairs(rhs)
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
			text = text.gsub(lhs+oper, new_lhs+oper)
			new_rhs = rhs
			remove_from_right.each do |rfr|
				new_rhs = new_rhs.gsub(rfr, "")
			end
			new_rhs = "0" if new_rhs == ""
			text = text.gsub(oper+rhs, oper+new_rhs)
			return(text)
		end

		def self.split_equals(constraint)
			[constraint.gsub("=", "<="), constraint.gsub("=", ">=")]
		end

		def self.split_equals_a(constraints)
			constraints.map do |constraint|
				if (constraint.split("") & ["<=",">=","<",">"]).empty?
					self.split_equals(constraint)
				else
					constraint
				end
			end.flatten
		end

		def self.sum_indices(constraint)
			#pieces_to_sub = constraint.scan(/[a-z]\[\d[\d\+\-]+\]/)
			pieces_to_sub = constraint.scan(/[a-z\]]\[\d[\d\+\-]+\]/)
			pieces_to_sub.each do |piece|
				characters_to_sum = piece.scan(/[\d\+\-]+/)[0]
				index_sum = self.sum_constants(characters_to_sum)
				new_piece = piece.gsub(characters_to_sum, index_sum)
				constraint = constraint.gsub(piece, new_piece)
			end
			return(constraint)
		end

		def self.produce_variable_type_hash(variable_types, all_variables)
			#in: ["BOOLEAN: x, y", "INTEGER: z"]
			#out: {:x => 3, :y => 3, :z => 2}
			variable_type_hash = {}
			variable_types.each do |vt|
				type = vt.gsub(" ","").split(":")[0]
				if type.downcase == "boolean"
					type_number = 3
				elsif type.downcase == "integer"
					type_number = 2
				end
				variables = vt.split(":")[1].gsub(" ","").split(",")
				variables.each do |root_var|
					all_variables_with_root = all_variables.find_all{|var|var.include?("[") && var.split("[")[0]==root_var}+[root_var]
					all_variables_with_root.each do |var|
						variable_type_hash[var.to_sym] = type_number
					end
				end
			end
			variable_type_hash
		end

		def self.sum_variables(formatted_constraint, lp)
			#in: x + y - z + x[3] + z + y - z + x - y <= 0
			#out: 2*x + y - z + x[3] <= 0
			helper = self
			lhs = helper.sides(formatted_constraint)[:lhs]
			formatted_lhs = helper.add_ones(lhs, lp)
			vars = helper.variables(formatted_lhs, lp)
			coefs = helper.coefficients(formatted_lhs, lp)
			var_coef_hash = {}
			vars.each_index do |i|
				var = vars[i]
				coef = coefs[i]
				if var_coef_hash[var]
					var_coef_hash[var] += coefs[i].to_f
				else
					var_coef_hash[var] = coefs[i].to_f
				end
			end
			new_lhs = ""
			var_coef_hash.keys.each do |key|
				coef = var_coef_hash[key].to_s
				var = key
				coef = "+"+coef unless coef.include?("-")
				new_lhs += coef+"*"+var
			end
			if new_lhs[0] == "+"
				new_lhs = new_lhs[1..-1]
			end
			formatted_constraint.gsub(lhs, new_lhs)
		end

		def self.get_column_bounds(bound_info, all_variables)
			#in: ["NONNEGATIVE: x1"]
			#out: {:x1 => {:lower => 0}}
			column_bounds = {}
			bound_info.each do |info|
				type = info.gsub(" ","").split(":")[0]
				if type.downcase == "nonnegative"
					bounds = {:lower => 0}
				end
				variables = info.split(":")[1].gsub(" ","").split(",")
				variables.each do |root_var|
					all_variables_with_root = all_variables.find_all{|var|var.include?("[") && var.split("[")[0]==root_var}+[root_var]
					all_variables_with_root.each do |var|
						column_bounds[var.to_sym] = bounds
					end
				end
			end
			column_bounds
		end

		def self.parse_data(data_info)
			#in: "DATA: {d => [1, 0.3, 1.5], o => [10.3, 4.0005, -1]}"
			#out: [data_object_1, data_object_2]
			data_hash_string = data_info.gsub(" ","").split(":")[1]
			data_string = data_hash_string.gsub("{",",").gsub("}",",")
			names = data_string.scan(/,[a-z]/).map{|comma_name|comma_name.gsub(",","")}
			string_values = data_string.scan(/\=\>[\[\d\.\]\,\-]+,/).map{|scanned_value|scanned_value[2..-2]}
			values = string_values.map{|sv|sv.to_a}
			data_hash = {}
			names.each_index do |i|
				name = names[i]
				value = values[i]
				value = value[0] if value.size == 1
				data_hash[name] = value
			end
			return(data_hash)
		end

		def self.substitute_data(text, lp)
			helper = self
			potential_things_to_substitute = helper.variables(text, lp)
			data_names = lp.data.map{|d|d.name}
			things_to_substitute = {}
			data_values = {}
			lp.data.each do |data|
				dname = data.name
				dvalue = data.value
				targets = potential_things_to_substitute.find_all do |ptts|
					dname == ptts[0]
				end
				things_to_substitute[dname] = targets
				targets.each do |target|
					indices = target.scan(/\d+/).map{|ind|ind.to_i}
					indices = "" if indices.empty?
					if dvalue.is_a?(Array)
						value = dvalue.values_at_a(indices)
					else
						value = dvalue
					end
					data_values[dname+indices.to_s.gsub(",","][").gsub(" ","")] = value
				end
			end
			data_values.keys.each do |key|
				name = key
				value = data_values[key]
				text = text.gsub(name, value.to_s)
			end
			plus_minus = text.scan(/\+[\ ]+-/)
			plus_minus.each do |pm|
				text = text.gsub(pm,"-")
			end
			return(text)
		end

		def self.remove_constants(text)
			helper = self
			text = text.gsub(" ","")
			text = "+"+text if text[0]!="-"
			text = text+"#"
			constants = helper.get_constants(text)
			replacements = []
			constants[:formatted].each_index do |i|
				formatted = constants[:formatted][i]
				unformatted = constants[:unformatted][i]
				if formatted.include?("+")
					if unformatted.include?("+")
						replacements << ["+"+unformatted, "+"]
					elsif unformatted.include?("-")
						replacements << ["-"+unformatted, "-"]
					elsif unformatted.include?("#")
						replacements << [formatted+"#",""]
					end
				elsif formatted.include?("-")
					if unformatted.include?("+")
						replacements << ["-"+unformatted, "+"]
					elsif unformatted.include?("-")
						replacements << ["-"+unformatted, "-"]
					elsif unformatted.include?("#")
						replacements << [formatted+"#",""]
					end
				end
			end
			replacements.each do |replacement|
				text = text.gsub(replacement[0],replacement[1])
			end
			text = text[1..-1] if text[0] == "+"
			return(text)
		end

		def self.check_options_syntax(options)
			return if options.empty?
			options.each do |option|
				if option.include?(":")
					title = option.gsub(" ","").split(":")[0]
					value = option.gsub(" ","").split(":")[1]
					if !["nonnegative", "integer", "boolean", "data", "epsilon"].include?(title.downcase)
						raise "Did not recognize the TITLE parameter '#{title}' in the options."
					end
				else
					raise "Options parameter '#{option}' does not have a colon in it. The proper syntax of an option is TITLE: VALUE"
				end
			end
		end
	end

	class LinearProgram
		attr_accessor :objective
		attr_accessor :constraints
		attr_accessor :original_constraints
		attr_accessor :rows
		attr_accessor :solution
		attr_accessor :rglpk_object
		attr_accessor :solver
		attr_accessor :matrix
		attr_accessor :simplex_message
		attr_accessor :mip_message
		attr_accessor :data
		attr_accessor :data_hash
		attr_accessor :variable_types
		attr_accessor :column_bounds
		attr_accessor :epsilon
		attr_accessor :matrix_solution
		attr_accessor :error_message
		attr_accessor :stop_processing

		def keys
			[:objective, :constraints, :rows, :solution, :formatted_constraints, :rglpk_object, :solver, :matrix, :simplex_message, :mip_message, :data]
		end

		def initialize
			@rows = []
			@data = []
			@epsilon = $default_epsilon
			@matrix_solution = {}
			@stop_processing = false
		end

		def solution_as_matrix
			lp = self
			variables = lp.solution.keys.map do |key|
				key.scan(/[a-z]/)[0] if key.include?("[")
			end.uniq.find_all{|e|!e.nil?}
			matrix_solution = {}
			variables.each do |var|
				elements = lp.solution.keys.find_all{|key|key.include?(var) && key.include?("[")}
				num_dims = elements[0].scan(/\]\[/).size + 1
				dim_limits = []
				indices_value_pairs = []
				[*(0..(num_dims-1))].each do |i|
					dim_limit = 0
					elements.each do |e|
						indices = e.scan(/\[\d+\]/).map{|str|str.scan(/\d+/)[0].to_i}
						value = lp.solution[e]
						indices_value_pairs << [indices, value]
						dim_limit = indices[i] if indices[i] > dim_limit
					end
					dim_limits << dim_limit+1
				end
				matrix = [].matrix(dim_limits)
				indices_value_pairs.each do |ivp|
					matrix.insert_at(ivp[0], ivp[1].to_f)
				end
				matrix_solution[var] = matrix
			end
			return(matrix_solution)
		end
	end

	class Objective
		attr_accessor :function
		attr_accessor :expanded_function
		attr_accessor :optimization#minimize, maximize, equals
		attr_accessor :variable_coefficient_pairs
		attr_accessor :optimized_value
		attr_accessor :addition

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
		attr_accessor :epsilon

		def initialize(name, lower_bound, upper_bound, epsilon)
			@name = name
			@lower_bound = lower_bound
			@upper_bound = upper_bound
			@variable_coefficient_pairs = []
			@epsilon = epsilon
		end
	end

	class VariableCoefficientPair
		attr_accessor :variable
		attr_accessor :coefficient
		attr_accessor :variable_type
		attr_accessor :lower_bound
		attr_accessor :upper_bound

		def initialize(variable, coefficient, variable_type=1)
			@variable = variable
			@coefficient = coefficient
			@variable_type = variable_type
		end
	end

	class Data
		attr_accessor :name
		attr_accessor :value
		attr_accessor :value_type#number, array
		attr_accessor :array_dimension

		def initialize(name, value)
			@name = name
			@value = value
			if value.is_a?(Array)
				@value_type = Array
				@array_dimension = value.dimension
			else
				@value_type = Integer
			end
		end
	end
end

def subject_to(constraints, options=[])
	OPL::Helper.check_options_syntax(options)
	lp = OPL::LinearProgram.new
	lp.original_constraints = constraints
	variable_types = options.find_all{|option|option.downcase.include?("boolean") || option.downcase.include?("integer")} || []
	epsilon = options.find_all{|option|option.downcase.include?("epsilon")}.first.gsub(" ","").split(":")[1].to_f rescue $default_epsilon
	bounded_columns = options.find_all{|option|option.downcase.include?("negative") || option.downcase.include?("positive") || option.downcase.include?("nonnegative")}
	data  = options.find_all{|option|option.gsub(" ","").downcase.include?("data:")}[0]
	if data
		parsed_data = OPL::Helper.parse_data(data)
		parsed_data.keys.each do |data_key|
			data_value = parsed_data[data_key]
			lp.data << OPL::Data.new(data_key, data_value)
		end
	end
	lp.epsilon = epsilon
	constraints = constraints.flatten
	constraints = OPL::Helper.split_equals_a(constraints)
	data_names = lp.data.map{|d|d.name}
	constraints = constraints.map do |constraint|
		OPL::Helper.sub_forall(constraint)
	end.flatten
	constraints = constraints.map do |constraint|
		OPL::Helper.sum_indices(constraint)
	end
	constraints = constraints.map do |constraint|
		OPL::Helper.sub_sum(constraint, lp)
	end
	constraints = constraints.map do |constraint|
		OPL::Helper.sum_indices(constraint)
	end
	constraints = constraints.map do |constraint|
		OPL::Helper.put_constants_on_rhs(constraint)
	end
	constraints = constraints.map do |constraint|
		OPL::Helper.put_variables_on_lhs(constraint)
	end
	constraints = constraints.map do |constraint|
		OPL::Helper.sub_rhs_with_summed_constants(constraint)
	end
	constraints = constraints.map do |constraint|
		OPL::Helper.substitute_data(constraint, lp)
	end
	constraints = constraints.map do |constraint|
		OPL::Helper.put_constants_on_rhs(constraint)
	end
	constraints = constraints.map do |constraint|
		OPL::Helper.put_variables_on_lhs(constraint)
	end
	constraints = constraints.map do |constraint|
		OPL::Helper.sub_rhs_with_summed_constants(constraint)
	end
	constraints = constraints.map do |constraint|
		OPL::Helper.sum_variables(constraint, lp)
	end
	lp.constraints = constraints
	all_vars = OPL::Helper.get_all_vars(constraints, lp)
	variable_type_hash = OPL::Helper.produce_variable_type_hash(variable_types, all_vars)
	column_bounds = OPL::Helper.get_column_bounds(bounded_columns, all_vars)
	lp.variable_types = variable_type_hash
	lp.column_bounds = column_bounds
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
			upper_bound = (value.split("<")[1]).to_f - epsilon
		elsif value.include?(">")
			negate = true
			bound = (value.split(">")[1]).to_f + epsilon
			upper_bound = (bound*-1).to_s
		end
		lhs = OPL::Helper.sides(constraint)[:lhs]
		coefs = OPL::Helper.coefficients(lhs, lp)
		if negate
			coefs = coefs.map do |coef|
				if coef.include?("+")
					coef.gsub("+", "-")
				elsif coef.include?("-")
					coef.gsub("-", "+")
				end
			end
		end
		vars = OPL::Helper.variables(lhs, lp)
		zero_coef_vars = all_vars - vars
		row = OPL::Row.new(name, lower_bound, upper_bound, epsilon)
		row.constraint = constraint
		coefs = coefs + zero_coef_vars.map{|z|0}
		vars = vars + zero_coef_vars
		zipped = vars.zip(coefs)
		pairs = []
		all_vars.each do |var|
			coef = coefs[vars.index(var)]
			variable_type = variable_type_hash[var.to_sym] || 1
			vcp = OPL::VariableCoefficientPair.new(var, coef, variable_type)
			vcp.lower_bound = column_bounds[var.to_sym][:lower] rescue nil
			vcp.upper_bound = column_bounds[var.to_sym][:upper] rescue nil
			pairs << vcp
		end
		row.variable_coefficient_pairs = pairs
		rows << row
	end
	lp.rows = rows
	lp
end

def maximize(objective, lp)
	optimize("maximize", objective, lp)
end

def minimize(objective, lp)
	optimize("minimize", objective, lp)
end

def optimize(optimization, objective, lp)
	original_objective = objective
	objective = OPL::Helper.sub_sum(objective, lp)
	objective = OPL::Helper.sum_indices(objective)
	objective = OPL::Helper.substitute_data(objective, lp)
	objective_constants = OPL::Helper.get_constants(objective)
	if objective_constants[:formatted].empty?
		objective_addition = 0
	else
		objective_addition = OPL::Helper.sum_constants(objective_constants[:formatted].inject("+"))
	end
	objective = OPL::Helper.remove_constants(objective)
	objective = OPL::Helper.sum_variables(objective, lp)
	o = OPL::Objective.new(original_objective, optimization)
	o.expanded_function = objective
	lp.objective = o
	lp.objective.addition = objective_addition
	rows_c = lp.rows
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
		if row.lower_bound.nil? && row.upper_bound.nil?
			rows[i].set_bounds(Rglpk::GLP_FR, nil, nil)
		elsif row.lower_bound.nil?
			rows[i].set_bounds(Rglpk::GLP_UP, nil, row.upper_bound)
		elsif row.upper_bound.nil?
			rows[i].set_bounds(Rglpk::GLP_LO, row.lower_bound, nil)
		else
			rows[i].set_bounds(Rglpk::GLP_DB, row.lower_bound, row.upper_bound)
		end
	end
	vars = rows_c.first.variable_coefficient_pairs
	cols = p.add_cols(vars.size)
	solver = "simplex"
	vars.each_index do |i|
		column_name = vars[i].variable
		cols[i].name = column_name
		cols[i].kind = vars[i].variable_type#boolean, integer, etc.
		if [1,2].include? cols[i].kind
			if vars[i].lower_bound.nil? && vars[i].upper_bound.nil?
				cols[i].set_bounds(Rglpk::GLP_FR, nil, nil)
			elsif vars[i].lower_bound.nil?
				cols[i].set_bounds(Rglpk::GLP_UP, nil, vars[i].upper_bound)
			elsif vars[i].upper_bound.nil?
				cols[i].set_bounds(Rglpk::GLP_LO, vars[i].lower_bound, nil)
			else
				cols[i].set_bounds(Rglpk::GLP_DB, vars[i].lower_bound, vars[i].upper_bound)
			end
		end
		if vars[i].variable_type != 1
			solver = "mip"
		end
	end
	lp.solver = solver
	all_vars = rows_c.first.variable_coefficient_pairs.map{|vcp|vcp.variable}
	obj_coefficients = OPL::Helper.coefficients(objective.gsub(" ",""), lp).map{|c|c.to_f}
	obj_vars = OPL::Helper.variables(objective.gsub(" ",""), lp)
	all_obj_coefficients = []
	all_vars.each do |var|
		i = obj_vars.index(var)
		coef = i.nil? ? 0 : obj_coefficients[i]
		all_obj_coefficients << coef
	end
	p.obj.coefs = all_obj_coefficients
	matrix = rows_c.map{|row|row.variable_coefficient_pairs.map{|vcp|vcp.coefficient.to_f}}.flatten
	lp.matrix = matrix
	p.set_matrix(matrix)
	answer = Hash.new()
	lp.simplex_message = p.simplex
	if solver == "simplex"
		lp.objective.optimized_value = p.obj.get + objective_addition.to_f
		cols.each do |c|
			answer[c.name] = c.get_prim.to_s
		end
	elsif solver == "mip"
		lp.mip_message = p.mip
		lp.objective.optimized_value = p.obj.mip + objective_addition.to_f
		cols.each do |c|
			answer[c.name] = c.mip_val.to_s
		end
	end
	lp.solution = answer
	lp.rglpk_object = p
	lp.matrix_solution = lp.solution_as_matrix
	if lp.stop_processing
		lp.solution = lp.error_message
		lp.matrix_solution = lp.error_message
		lp.rglpk_object = lp.error_message
		lp.objective = lp.error_message
	end
	lp
end
