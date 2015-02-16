class String
	def paren_to_array
		#in: "(2..5)"
		#out: "[2,3,4,5]"
		start = self[1].to_i
		stop = self[-2].to_i
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

	def index_array(str)
		indices = []
		string = self
		ignore_indices = []
		search_length = str.size
		[*(0..string.size-1)].each do |i|
			if !ignore_indices.include?(i)
				compare_str = string[i..(i+search_length-1)]
				if compare_str == str
					indices << i
					ignore_indices = ignore_indices + [i..(i+search_length-1)]
				end
			end
		end
		return(indices)
	end
end