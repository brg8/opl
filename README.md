Meant to solve simple linear optimization problems. By simple I mean that there are no forall or summation statements.

You can write out your optimization problem in a syntactically pleasant way. For example:

solution = 
maximize(
	"10x1 + 6x2 + 4x3",
subject_to([
	"p: x1 + x2 + x3 <= 100",
	"q: 10x1 + 4x2 + 5x3 <= 600",
	"r: 2x1 + 2x2 + 6x3 <= 300",
	"s: x1 >= 0",
	"t: x2 >= 0",
	"u: x3 >= 0"
]))