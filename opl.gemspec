Gem::Specification.new do |s|
	s.name = "opl"
	s.version = "2.5.1"
	s.date = "2020-06-20"
	s.summary = "Linear Or Mixed Integer Program Solver"
	s.description = "This gem gives you a beautifully simple way to formulate your linear or mixed integer program. The syntax is inspired by OPL Studio, which remains my favorite linear programming software, but the license is quite expensive."
	s.authors = ["Benjamin Godlove"]
	s.email = "bgodlove88@gmail.com"
	s.files = ["lib/array.rb", "lib/opl.rb", "lib/string.rb", "lib/sudoku.rb"]
	s.homepage = "http://github.com/brg8/opl"
	s.license = "GNU"
	s.add_runtime_dependency "rglpk"
end