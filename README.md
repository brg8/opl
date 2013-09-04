OPL (pronounced Opal) is a Linear Programming syntax based off of OPL Studio.

The entire purpose of this gem is to allow you to write your linear programs or optimization problems in a simple, human-understandable way. So instead of 30 lines of code to set up a problem (as in the rglpk documentation), you can set up your problem like so:

maximize(  
  "x + y",  
subject_to([  
  "x <= 10",  
  "y <= 3"  
]))

I try to keep the tests up to date, so take a look in there for more examples.

Functionality to come includes forall and summation statements. E.g.

maximize(  
  "sum(i in (0..3) x[i])",  
subject_to([  
  "forall(i in (0..3), x[i] <= 3"  
]))

Comments are much appreciated.
