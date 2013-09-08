require "rspec"
require "./lib/opl.rb"

describe "lpsolve" do
	before :all do
	end

	before :each do
	end

	it "solves problem 1" do
		lp = maximize(
			"10x1 + 6x2 + 4x3",
		subject_to([
			"x1 + x2 + x3 <= 100",
			"10x1 + 4x2 + 5x3 <= 600",
			"2x1 + 2x2 + 6x3 <= 300",
			"x1 >= 0",
			"x2 >= 0",
			"x3 >= 0"
		]))
		lp.solution["x1"].to_f.round(2).should eq 33.33
		lp.solution["x2"].to_f.round(2).should eq 66.67
		lp.solution["x3"].to_f.round(2).should eq 0.0
	end

	it "solves problem 2" do
		lp = maximize(
			"x + y - z",
		subject_to([
			"x + 2y <= 3",
			"3x-z <= 5",
			"x >= 0",
			"y >= 0",
			"z >= 0"
		]))
		lp.solution["x"].to_f.round(2).should eq 1.67
		lp.solution["y"].to_f.round(2).should eq 0.67
		lp.solution["z"].to_f.round(2).should eq 0.0
	end

	it "solves problem 3" do
		lp = minimize(
			"a - x4",
		subject_to([
			"a + x4 >= 4",
			"a + x4 <= 10"
		]))
		lp.solution["a"].to_f.round(2).should eq 0.0
		lp.solution["x4"].to_f.round(2).should eq 10.0
	end

	it "solves problem 4" do
		lp = maximize(
			"x[1] + y + x[3]",
		subject_to([
			"x[1] + x[3] <= 3",
			"y <= 4",
		]))
		lp.solution["x[1]"].to_f.round(2).should eq 3.0
		lp.solution["x[3]"].to_f.round(2).should eq 0.0
		lp.solution["y"].to_f.round(2).should eq 4.0
	end

	it "solves problem 5" do
		lp = minimize(
			"sum(i in [0,1,2,3], x[i])",
		subject_to([
			"x[1] + x[2] >= 3",
			"x[0] >= 0",
			"x[3] >= 0"
		]))
		(lp.solution=={"x[1]"=>"3.0", "x[2]"=>"0.0", "x[0]"=>"0.0", "x[3]"=>"0.0"}).should eq true
	end

	it "solves problem 6" do
		lp = minimize(
			"sum(i in (0..3), x[i])",
		subject_to([
			"x[1] + x[2] >= 3",
			"x[0] >= 0",
			"x[3] >= 0"
		]))
		(lp.solution=={"x[1]"=>"3.0", "x[2]"=>"0.0", "x[0]"=>"0.0", "x[3]"=>"0.0"}).should eq true
	end

	it "solves problem 7" do
		lp = minimize(
			"z + sum(i in (0..3), x[i])",
		subject_to([
			"x[1] + x[2] >= 3",
			"z >= 3",
			"x[0] >= 0",
			"x[1] >= 0",
			"x[2] >= 0",
			"x[3] >= 0"
		]))
		(lp.solution=={"x[1]"=>"3.0", "x[2]"=>"0.0", "z"=>"3.0", "x[0]"=>"0.0", "x[3]"=>"0.0"}).should eq true
	end

	it "solves problem 8" do
		lp = minimize(
			"sum(i in (0..1), j in [0,1], x[i][j])",
		subject_to([
			"sum(j in (0..1), x[1][j]) >= 3",
			"x[1][0] >= 1",
			"x[1][0] <= 1",
			"x[0][0] + x[0][1] >= 0"
		]))
		lp.solution["x[1][0]"].to_f.round(2).should eq 1.0
		lp.solution["x[1][1]"].to_f.round(2).should eq 2.0
		lp.solution["x[0][0]"].to_f.round(2).should eq 0.0
		lp.solution["x[0][1]"].to_f.round(2).should eq 0.0
	end

	it "solves problem 9" do
		lp = minimize(
			"sum(i in (0..1), j in [0,1], x[i][j])",
		subject_to([
			"sum(i in (0..1), j in [0,1], x[i][j]) >= 10"
		]))
		(lp.solution=={"x[0][0]"=>"10.0", "x[0][1]"=>"0.0", "x[1][0]"=>"0.0", "x[1][1]"=>"0.0"}).should eq true
	end

	it "solves problem 10" do
		lp = minimize(
			"sum(i in (0..3), x[i])",
		subject_to([
			"sum(i in (0..1), x[i]) + sum(i in [2,3], 2x[i]) >= 20"
		]))
		(lp.solution=={"x[0]"=>"0.0", "x[1]"=>"0.0", "x[2]"=>"10.0", "x[3]"=>"0.0"}).should eq true
	end

	it "solves problem 11" do
		lp = minimize(
			"sum(i in (0..3), j in (2..3), x[i] + 4x[j])",
		subject_to([
			"sum(i in (0..1), j in (0..3), 2x[i] - 3x[j]) >= 20"
		]))
		(lp.solution=={"x[0]"=>"10.0", "x[1]"=>"0.0", "x[2]"=>"0.0", "x[3]"=>"0.0"}).should eq true
	end

	it "solves problem 12" do
		lp = maximize(
			"sum(i in (0..2), x[i])",
		subject_to([
			"forall(i in (0..2), x[i] <= 5)"
		]))
		lp.solution["x[0]"].to_f.round(2).should eq 5.0
		lp.solution["x[1]"].to_f.round(2).should eq 5.0
		lp.solution["x[2]"].to_f.round(2).should eq 5.0
	end

	it "solves problem 13" do
		lp = minimize(
			"sum(i in (0..3), j in (0..3), x[i][j])",
		subject_to([
			"forall(i in (0..3), sum(j in (i..3), x[i][j]) >= i)",
			"forall(i in (0..3), sum(j in (0..i), x[i][j]) >= i)"
		]))
		(lp.solution=={"x[0][0]"=>"0.0", "x[0][1]"=>"0.0", "x[0][2]"=>"0.0", "x[0][3]"=>"0.0", "x[1][1]"=>"1.0", "x[1][2]"=>"0.0", "x[1][3]"=>"0.0", "x[2][2]"=>"2.0", "x[2][3]"=>"0.0", "x[3][3]"=>"3.0", "x[1][0]"=>"0.0", "x[2][0]"=>"0.0", "x[2][1]"=>"0.0", "x[3][0]"=>"0.0", "x[3][1]"=>"0.0", "x[3][2]"=>"0.0"}).should eq true
	end

	it "solves problem 14" do
		lp = maximize(
			"x + 3",
		subject_to([
			"x + 9 <= 10"
		]))
		lp.solution["x"].to_f.round(2).should eq 1.0
	end

	it "solves problem 15" do
		lp = maximize(
			"x + y - z",
		subject_to([
			"x = 5",
			"y < 3",
			"z > 4"
		]))
		lp.solution["x"].to_f.round(2).should eq 5.0
		lp.solution["y"].to_f.round(2).should eq 2.0
		lp.solution["z"].to_f.round(2).should eq 5.0
	end

	it "solves problem 16" do
		lp = maximize(
			"x + y",
		subject_to([
			"x - 2.3 = 5.2",
			"3.2y <= 3",
		]))
		lp.solution["x"].to_f.round(2).should eq 7.5
		lp.solution["y"].to_f.round(2).should eq 0.94
	end

	it "solves problem 17" do
lp = maximize(
"c",
subject_to([
"c + g + d + r + n + a + j + o = 100",
"o = 0",
"c < 50",
"2c + 2g > 100",
"2c + 2d > 100",
"2g + 2d > 100",
"g - d = 0",
"r - n = 0",
"r >= 3",
"a - j = 0",
"a >= 0.5"
]))
	end

	it "solves problem 18" do
		lp = maximize(
			"c",
		subject_to([
			"t = 5",
			"c < t"
		]))
		lp.solution["t"].to_f.round(2).should eq 5.0
		lp.solution["c"].to_f.round(2).should eq 4.0
	end

	it "solves problem 19" do
lp = minimize(
#"sum(i in (0..6), r[i] + o[i]) + 47250*f[0] + 40500*f[0] + 33750*f[0] + 27000*f[0] + 20250*f[4] + 13500*f[5] + 6750*f[6]",
"sum(i in (0..6), r[i] + o[i] + j[i] - h[i])",
subject_to([
"sum(i in (0..7), f[i]) = 1",
"forall(i in (1..6), l[i] - l[i-1] >= f[i] + d[i])",
"forall(i in (1..6), sum(j in (0..j), f[i] + d[i]) >= l[i])",
"forall(i in (0..6), r[i] = 13500*s[i] + 7000*l[i])",
"forall(i in (0..5), s[i] >= s[i+1])",
"forall(i in (0..5), l[i+1] >= l[i])",
"forall(i in (0..6), s[i] + l[i] = 1)",
"forall(i in (0..6), o[i] = 2000*l[i])",
"forall(i in (0..6), d[i] <= l[i])",
"forall(i in (0..5), d[i] <= d[i+1])",
"forall(i in (0..6), h[i] = 13500*d[i])",
"j[0] = 47250*f[0]", "j[1] = 40500*f[1]", "j[2] = 33750*f[2]", "j[3] = 27000*f[3]", "j[4] = 20250*f[4]", "j[5] = 13500*f[5]", "j[6] = 6750*f[6]", "j[7] = 0*f[7]",
"sum(i in (0..6) d[i]) <= f[7]",
"forall(i in (0..6) d[i] + f[i] <= 1)"
]))
#"forall(i in (0..6), 10*s[i] >= 8.999999 + s[i])",
#"sum(i in (0..6), l[i]) = 1"

#we have to pay the fee (even if it is $0)
#if we are out of the apt in a month, then we either pay a fee or rent it out that month
#for each month, rent costs $13500 if we stay that month, and $7000 if we leave that month
#if we stay then we can stay the next month
#if we leave then we cannot return
#in any given month we are either staying or leaving
#office space costs us $2000 per month if we've left
#we can only rent the place out if we have left
#if we rent the place, then it will be rented until our lease is up
#the amount of money we rented the place for is $12000
#j[i] is the amount of money we pay in fees in month i
#if we rent the place, then we don't pay a fee. If we don't rent the place, then we may or may not pay a fee
#in any given month, we cannot both rent the place and pay a fee
	end

it "solves problem 20" do
lp = minimize(
"m",
subject_to([
"t = 5",
"c < t"
]))
	end
end
