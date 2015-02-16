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