OPL (pronounced Opal) is a Linear Programming syntax based off of OPL Studio.

The entire purpose of this gem is to allow you to write your linear programs or optimization problems in a simple, human-understandable way. So instead of 30 lines of code to set up a problem (as in the rglpk documentation), you can set up your problem like so:

maximize(
-
"x + y",\nsubject_to([\n"x <= 10",\n"y <= 3"\n]))

I try to keep the tests up to date, so take a look in there for more examples.
