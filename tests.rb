require "rspec"
require "./lpsolve"

describe "lpsolve" do
	before :all do
	end

	before :each do
	end

	it "solves problem 1" do
		solution = maximize(
			"10x1 + 6x2 + 4x3",
		subject_to([
			"p: x1 + x2 + x3 <= 100",
			"q: 10x1 + 4x2 + 5x3 <= 600",
			"r: 2x1 + 2x2 + 6x3 <= 300",
			"s: x1 >= 0",
			"t: x2 >= 0",
			"u: x3 >= 0"
		]))
		solution["x1"].to_f.round(2).should eq 33.33
		solution["x2"].to_f.round(2).should eq 66.67
		solution["x3"].to_f.round(2).should eq 0.0
	end

	it "solves problem 2" do
		solution = maximize(
			"x + y - z",
		subject_to([
			"x + 2y <= 3",
			"3x-z <= 5",
			"x >= 0",
			"y >= 0",
			"z >= 0"
		]))
		solution["x"].to_f.round(2).should eq 1.67
		solution["y"].to_f.round(2).should eq 0.67
		solution["z"].to_f.round(2).should eq 0.0
	end

	it "solves problem 3" do
		solution = minimize(
			"a - x4",
		subject_to([
			"a + x4 >= 4",
			"a + x4 <= 10"
		]))
		solution["a"].to_f.round(2).should eq 0.0
		solution["x4"].to_f.round(2).should eq 10.0
	end

	#have one here that has a constant in it
end
