try running r locally

data <- data.frame(
  year = c(1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009),
  wuenic = c(0.70, 0.71, 0.73, 0.66, 0.71, 0.68, 0.73, 0.71, 0.77, 0.78, 0.85, 0.85, 0.86),
  gov = c("", "", 0.92, 0.66, 0.71, 0.68, 0.73, 0.71, 0.77, 0.78, 0.85, 0.85, 0.86),
  admin = c("", "", 1.02, 0.66, 0.71, 0.68, 0.73, 0.71, 0.77, 0.78, 0.85, 0.85, 0.86),
  survey = c("", "", 0.66, "", "", "", "", "", 0.75, "", "", "", ""),
  survey_accepted = c("", "", 0.66, "", "", "", "", "", 0.75, "", "", "","")
)

plot_cmd:
r_data_frame(line0, [year=A, number=B], 'WUENIC_decides_the_coverage_in_for_for_is_due_to_the_fact_that'(sdn, dtp1, A, B, _)), 
<- {|r||"plot(NULL, main='SDN-DTP',xlab='Year',ylab='Coverage',xlim=c(1997,2009),ylim=c(0,1.25))
lines(line0$year,line0$number,col=\"blue\",lwd=5)"|}.


the coverage for 1997 is 0.70.
the coverage for 1998 is 0.71.
the coverage for 1999 is 0.73.
the coverage for 2000 is 0.66.
the coverage for 2001 is 0.71.
the coverage for 2002 is 0.68.
the coverage for 2003 is 0.73.
the coverage for 2004 is 0.71.
the coverage for 2005 is 0.77.
the coverage for 2006 is 0.78.
the coverage for 2007 is 0.85.
the coverage for 2008 is 0.85.
the coverage for 2009 is 0.86.

the government estimate for 1999 is 0.92.
the government estimate for 2000 is 0.66.
the government estimate for 2001 is 0.71.
the government estimate for 2002 is 0.68.
the government estimate for 2003 is 0.73.
the government estimate for 2004 is 0.71.
the government estimate for 2005 is 0.77.
the government estimate for 2006 is 0.78.
the government estimate for 2007 is 0.85.
the government estimate for 2008 is 0.85.
the government estimate for 2009 is 0.86.

the administrative estimate for 1999 is 1.02.
the administrative estimate for 2000 is 0.66.
the administrative estimate for 2001 is 0.71.
the administrative estimate for 2002 is 0.68.
the administrative estimate for 2003 is 0.73.
the administrative estimate for 2004 is 0.71.
the administrative estimate for 2005 is 0.77.
the administrative estimate for 2006 is 0.78.
the administrative estimate for 2007 is 0.85.
the administrative estimate for 2008 is 0.85.
the administrative estimate for 2009 is 0.86.

the survey estimate for 1999 is 0.66.
the survey estimate for 2005 is 0.75.

the accepted survey estimate for 1999 is 0.66.
the accepted survey estimate for 2005 is 0.75.

display the year and the number
  from the coverage for a year is a number
    as a line with a colour of blue and a width of 5.


parse_and_query('my_test', en("the target language is: prolog.

the templates are:
  *a creature* is a dragon.

scenario smoky is:
     bob is a dragon.
     alice is a dragon.

query happy is:
     which creature is a dragon."), happy, smoky, Answer).