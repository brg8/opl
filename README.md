OPL (pronounced Opal) is a Linear Programming syntax based off of OPL Studio.

The entire purpose of this gem is to allow you to write your linear programs or optimization problems in a simple, human-understandable way. So instead of 30 lines of code to set up a problem (as in the rglpk documentation), you can set up your problem like so:

maximize(  
  "x + y",  
subject_to([  
  "x <= 10",  
  "y <= 3"  
]))

I try to keep the tests up to date, so take a look in there for more examples.

Please send comments, suggestions, bugs, complaints, party invites to bgodlove88 at gmail.com.

A quick view at some examples of functionality:

Summation and Forall constraints:

maximize(  
  "sum(i in (0..3) x[i])",  
subject_to([  
  "forall(i in (0..3), x[i] <= 3)"  
]))

Easy specification of variable types:

lp = maximize(  
	"10x1 + 6x2 + 4x3",  
subject_to([  
	"x1 + x2 + x3 <= 100",  
	"10x1 + 4x2 + 5x3 <= 600",  
	"2x1 + 2x2 + 6x3 <= 300",  
	"x1 >= 0",  
	"x2 >= 0",  
	"x3 >= 0"  
],[  
	"BOOLEAN: x1",  
	"INTEGER: x3"  
]  
))

Access to epsilon for strict inequalities:

lp = maximize(  
	"x + y + z",  
subject_to([  
	"x + z < 2",  
	"y <= 4",  
],[  
	"INTEGER: y",  
	"EPSILON: 0.03"  
]  
))  

BE WARNED - When you specify a variable as INTEGER or BOOLEAN, you will be using the Branch & Cut method to solve the problem. This is very inefficient, and some seemingly easy problems can take forever to solve. You may have to formulate your problem in a clever way. Here is an example.  

This problem would take B&C hours to solve:

lp = maximize(  
	"x + y + x[3]",  
subject_to([   
	"x + x[3] <= 2.5",  
	"y <= 4"  
],[  
	"INTEGER: x, y",  
]  
))  

But if we just use some common sense, we can make this model:

lp = maximize(  
	"x + y + x[3]",  
subject_to([  
	"x <= 2.5",  
	"x[3] <= 2.5",  
	"x + x[3] <= 2.5",  
	"y <= 4"  
],[  
	"INTEGER: x, y",  
]  
))  

Which is solvable in a few milliseconds and clearly does not affect the result.
