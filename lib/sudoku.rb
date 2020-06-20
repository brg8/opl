class Sudoku
  attr_accessor :input_matrix
  attr_accessor :lp
  attr_accessor :solution

  def initialize(input_matrix)
    @input_matrix = input_matrix
    ""
  end

  def solve
    size = input_matrix.count
    rubysize = size-1

    constant_constraints = []
    input_matrix.each_index do |i|
      row = input_matrix[i]

      row.each_index do |j|
        element = input_matrix[i][j]

        if element != 0
          constant_constraints << "x[#{i}][#{j}][#{element-1}] = 1"
        end
      end
    end

    @lp = minimize("y", subject_to([
      "y = 2",# y is a dummy variable so I don't have to worry about the objective function
      "forall(i in (0..#{rubysize}), j in (0..#{rubysize}), sum(k in (0..#{rubysize}), x[i][j][k]) = 1)",# an element contains only one number
      "forall(i in (0..#{rubysize}), k in (0..#{rubysize}), sum(j in (0..#{rubysize}), x[i][j][k]) = 1)",# every row contains every number
      "forall(j in (0..#{rubysize}), k in (0..#{rubysize}), sum(i in (0..#{rubysize}), x[i][j][k]) = 1)",# every column contains every number
      "forall(u in [0,3,6], v in [0,3,6], k in (0..#{rubysize}), sum(i in ((0+u)..(#{(size/3)-1}+u)), j in ((0+v)..(#{(size/3)-1}+v)), x[i][j][k]) = 1)",# every 3x3 grid contains every number
      constant_constraints# some elements already have their values set
    ].flatten,["BOOLEAN: x"]))
    ""
  end

  def format_solution
    @lp.matrix_solution["x"]
    mat = @lp.matrix_solution["x"]
    sol = Array.new(mat[0][0].size) { Array.new(mat[0][0].size, 0) }
    mat.each_index do |i|
      mat[i].each_index do |j|
        mat[i][j].each_index do |k|
          if mat[i][j][k].to_f == 1.0
            sol[i][j] = k+1
          end
        end
      end
    end
    @solution = sol
    ""
  end

  def print_problem
    @input_matrix.each do |row|
      puts row.join(" ")
    end
    ""
  end

  def print_solution
    @solution.each do |row|
      puts row.join(" ")
    end
    ""
  end
end
