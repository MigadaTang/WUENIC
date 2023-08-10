['data.pl'].

output_estimates(Estimates) :-
    open('survey.out',write,Out), nl(Out),
	output_results(Estimates,Out), close(Out).

output_results([],_).
output_results([H|T],Out) :- output_fields(H,Out), output_results(T,Out).

output_fields([],Out) :- nl(Out).
output_fields([H|T],Out) :- write(Out,H),write(Out,'\t'),output_fields(T,Out).

gather_estimates(V) :-
    setof([Explanation], translate(Explanation, V), Estimates),
    output_estimates(Estimates).

translate(Explanation, V) :-
    wgd(C,V,Y,From, Rule, Reason, To),
	swritef(Explanation,'the working group decides that the coverage in %w for %w for %w should be changed from %w to %w according to rule %w and explanation %w',[C,V,Y, From, To, Rule, Reason]).

translate(Explanation, V) :-
    estimate_required(C,V,Y),
	swritef(Explanation,'estimate is required for %w for %w for %w.',[C,V,Y]).

translate(Explanation, V) :- 
    data(reported,C,V,Y,Coverage),
	swritef(Explanation,'the reported data shows that the coverage in %w for %w for %w is %w.',[C,V,Y,Coverage]).

translate(Explanation, V) :- 
    data(gov,C,V,Y,Coverage),
	swritef(Explanation,'the government data shows that the coverage in %w for %w for %w is %w.',[C,V,Y,Coverage]).

translate(Explanation, V) :- 
    data(admin,C,V,Y,Coverage),
	swritef(Explanation,'the administrative data shows that the coverage in %w for %w for %w is %w.',[C,V,Y,Coverage]).

translate(Explanation, V) :- 
    data(legacy,C,V,Y,Coverage),
	swritef(Explanation,'the legacy data shows that the coverage in %w for %w for %w is %w.',[C,V,Y,Coverage]).

translate(Explanation, V) :- 
    survey(C, V, Y, [title:Title,type:Type,yrcoll:YCrol,cr:CR,confirm:CFM,age:AGE,timead:_TMD,val:VAL,ss:SS], Coverage),
	swritef(Explanation,'the survey data with title as %w and survey type as %w and year data collected from %w and card retention as %w and confirmation method as %w and age cohort of %w and validity till %w and sample size as %w shows that the coverage in %w for %w for %w is %w.',[Title,Type,YCrol,CR,CFM,AGE,VAL,SS,C,V,Y,Coverage]).