/****************************************************************
WUENIC: Rule based estimates.

Code under development. Not to be circulated.

Author: Tony BURTON,
        System Analyst,
	Department of Immunizations, Vaccines and Biologics
        World Health Organization
        1211 Geneva 27
        Switzerland

Date:   9 December 2008. Last update 17 May 2010.
	RAK edit forall

Depends upon: SWI-Prolog (Multi-threaded, version 5.6.59)
http://www.swi-prolog.org/

Based on methods described in:

  Burton A, Monash R, Lautenbach B, Gacic-Dobo M, Neill M, Karimov
  R, Wolfson L, Jones G, Birmingham M. WHO and UNICEF estimates of
  national infant immunization coverage: methods and processes.
  Bull World Health Organ 2009; 87:535-541.
  http://www.who.int/bulletin/volumes/87/7/08-053819.pdf

  Burton A, Gacic-Dobo M, Karimov R, Kowalski R, and Neill M.
  WUENIC: a formal representation of the WHO and UNICEF estimates
  of national immunization coverage. DRAFT October 2009.

  Articles and code available at: http://sites.google.com/site/wuenic/


Predicates
----------
wuenic(Country,Vaccine,Year,Rule,Justification,Coverage).

anchor_point(Country,Vaccine,Year,Justification,Coverage).

reported_time_series(Country,Vaccine,Year,Justification,Coverage).
reportedAccepted(Country,Vaccine,Year,Justification,Coverage).
reported(Country,Vaccine,Year,Coverage).

surveyAccepted(Country,Vaccine,Year,Description,Coverage).
survey(Country,Vaccine,Year,D,Percent),
	member(title:Title,D),
	member(type:SurveyType,D),
	member(yrcol:YearDataCollected,D),
	member(cr:CardRetention,D),
	member(confirm:ConfirmationMethod,D),
	member(age:AgeCohort,D),
	member(timeadm:Timely,D),
	member(val:Validity,D),
	member(ss:SampleSize,D).

wgd(Country,Vaccine,Year,Coverage,Condition,Justification,AlternativeCoverage)
      Justification ::= [ignoreSurvey | acceptSurvey | ignoreReported |
      acceptReported | modifySurvey | modifyReported | assignAnchor |
      accignWUENIC | comment].

interpolateSegment(Country,Vaccine,Y1,Y2,Justification)

add: Marta's rule (survey "supports" reported includes multiple years.)
     vaccine to vaccine consistency
     improve sawtooth
     Rousland's Magic Formula for DTP1.
     Rules for denominator heuristics.

-----------------------
   Rule for vaccine to vaccine consistency
   for all c,v,y
   if
     anchor point in year y and vaccine v resolved to survey
     not (anchor point for any other vaccines (v1 NE v) resolved to
     survey)
     abs(survey - reported) > 10 and < 20
   then
     anchor resolved to reported.

   for all c,v,y

     anchor point in year y and vaccine v resolved to reported
     not (anchor point for any other vaccines (v1 NE v) resolved to
     reported)
     abs(survey - reported) > 10 and < 20
   then
     anchor resolved to survey.
----------------

****************************************************************************/

data(type,country,vaccine,year,coverage).
survey(country,vaccine,year,description,coverage).
wgd(country,vaccine,year,originalCoverage,rule,justification,assignedCoverage).
interpolate_segment(country,vaccine,year1,year2,justification).

% import file containing reported, survey, working group decisions,
% and country,vaccine,year combinations for which estimates are
% required.
% ----------
:- ['data.pl'].
:- op(1000,xfy,:).
:- dynamic anchor_point/6.

% =========================================
% Top level predicated to produce estmates.
% Creates data structure, one row per estimate.
% of country name, production date, country
% code, vaccine, year, estimated coverage,
% top level rule, explanatory text, and supporting
% data.
% =========================================
estimate :-
	country(_,Country_Name),
	date(Date),

	forall(new_anchor_point(Co,Va,Ye,Ty,Ex,Per),
	       asserta(anchor_point(Co,Va,Ye,Ty,Ex,Per))),

	setof([Country_Name,Date,C,V,Y,Coverage,Rule,Justification,Data],
	      est(C,V,Y,Rule,Justification,Data,Coverage),
	      Estimates),
	output_estimates(Estimates).

% ============================================================
% The predicate est/7 has been added as a layer above wuenic/7,
% to faciliate RMF calculations. This structure can be extended
% for 1) vaccine to vaccine comparision and 2) for testing
% whether previous estimates were based on calibration.
% =============================================================

% Estimate based on working group decision
% ----------------------------------------
est(C,V,Y,'X',Explanation,Data,Coverage) :-
	estimate_required(C,V,Y),
	wgd(C,V,Y,_,assignWUENIC,Justification,Coverage),

	% Create explanation.
	collect_data(C,V,Y,Data),
	collect_explanations(C,V,Y,Exceptions),
	swritef(Explanation,'Estimate assigned by working group. %w %w',
		[Justification,Exceptions]).

% Estimate for non-DTP1 other vaccines = wuenic estimate.
% -------------------------------------------------
est(C,V,Y,Rule,Explanation,Data,Coverage) :-
	estimate_required(C,V,Y),
	not(member(V,['dtp1'])),
	not(wgd(C,V,Y,_,assignWUENIC,_,_)),
	wuenic(C,V,Y,Rule,Justification,Coverage),

	% Create explanation.
	collect_data(C,V,Y,Data),
	collect_explanations(C,V,Y,Exceptions),
	swritef(Explanation,'%w %w',[Justification,Exceptions]).

% DTP1: estimated DTP3 greater than estimated DTP1, estimate = RMF.
% -----------------------------------------------------------------
est(C,dtp1,Y,'RMF',Exp,Data,RMF) :-
	estimate_required(C,dtp1,Y),
	not(wgd(C,dtp1,Y,_,assignWUENIC,_,_)),

	wuenic(C,dtp1,Y,_,_,Dtp1Coverage),
	wuenic(C,dtp3,Y,_,_,Dtp3Coverage),

	Dtp3Coverage > Dtp1Coverage,

	P is ((Dtp3Coverage * 100) +
	     (-0.0066 * ((Dtp3Coverage*100)*(Dtp3Coverage*100))) +
	     (0.4799 * (Dtp3Coverage*100)) + 16.67) / 100,
	value(P,RMF),

	% Create explanation.
	collect_data(C,dtp1,Y,Data),
	collect_explanations(C,dtp1,Y,Exceptions),
	swritef(Exp,'Estimated DTP3 greater than estimated DTP1; DTP1 estimate based on the relationship between DTP1 and DTP3 from 282 surveys. %w', [Exceptions]).

% DTP1: estimated DTP3 less than or equal to DTP1, estimate = estimate.
% --------------------------------------------------------------------
est(C,dtp1,Y,Rule,Explanation,Data,Dtp1Coverage) :-
	estimate_required(C,dtp1,Y),
	not(wgd(C,dtp1,Y,_,assignWUENIC,_,_)),

	wuenic(C,dtp1,Y,Rule,Justification,Dtp1Coverage),
	wuenic(C,dtp3,Y,_,_,Dtp3Coverage),

	Dtp3Coverage =< Dtp1Coverage,

	% Create explanation.
	collect_data(C,dtp1,Y,Data),
	collect_explanations(C,dtp1,Y,Exceptions),
	swritef(Explanation,'%w %w',[Justification,Exceptions]).

% =========================================
% WHO & UNICEF vaccine specific estimates.
% =========================================

% Estimate based on reported time series, no evidence to contrary
% ---------------------------------------------------------------
wuenic(C,V,Y,'RO',Explanation,Coverage) :-
	estimate_required(C,V,Y),
	not(anchor_point(C,V,_,_,_,_)),
	not(wgd(C,V,Y,_,assignWUENIC,_,_)),

	reported_time_series(C,V,Y,Justification,Coverage),

	swritef(Explanation,'%w',[Justification]).

% DTP1 Estimate based on relationship between DTP1 and DTP3 (RMF)
% No DTP1 data (admin, gov, reported, or survey) available.
% --------------------------------------------------------------
wuenic(C,dtp1,Y,'RMF',Explanation,Coverage) :-
	estimate_required(C,dtp1,Y),
	not(reported_time_series(C,dtp1,_,_,_)),
	not(survey_results(C,dtp1,_,_,_)),
	not(wgd(C,dtp1,Y,_,assignWUENIC,_,_)),

	wuenic(C,dtp3,Y,_,_,Dtp3Coverage),

	P is ((Dtp3Coverage * 100) + (-0.006 * ((Dtp3Coverage*100)*(Dtp3Coverage*100))) +
	     (0.4799 * (Dtp3Coverage*100)) + 16.67) / 100 ,
	value(P,Coverage),


	swritef(Explanation,'No DTP1 data available for any year; estimate based on the relationship between DTP1 and DTP3 from 282 surveys.').

% Estimate at anchor points.
% -------------------------
wuenic(C,V,Y,Rule,Explanation,Coverage) :-
	estimate_required(C,V,Y),
	not(wgd(C,V,Y,_,assignWUENIC,_,_)),
	not(year_between_WGD_segment(C,V,Y)),

	anchor_point(C,V,Y,AnchorType,Explanation,P),
	value(P,Coverage),
	swritef(Rule,'AP:%w',[AnchorType]).

% ==========================================
% Estimate values between two anchor points.
% =========================================

% Reported data.
% Both anchor points supported by survey or wgd.
% ---------------------------------------------
wuenic(C,V,Y,Rule,Explanation,Coverage) :-
	estimate_required(C,V,Y),
	not(anchor_point(C,V,Y,_,_,_)),
	not(year_between_WGD_segment(C,V,Y)),
	not(wgd(C,V,Y,_,assignWUENIC,_,_)),

	anchor_point(C,V,Y1,AnchorType1,_,_), member(AnchorType1,['R','XR']),
	anchor_point(C,V,Y2,AnchorType2,_,_), member(AnchorType2,['R','XR']),
	Y1 < Y, Y < Y2,
	not(anchor_point_between(C,V,Y1,Y2,_)),

	reported_time_series(C,V,Y,Explanation,Coverage),

	swritef(Rule,'RBAP: %w-%w',[AnchorType1,AnchorType2]).

% Calibrate.
% At least one anchor point not resolved to reported data.
% Anchor point and reported trends the same.
% Estimate based on reported data calibrated anchor point levels.
% ---------------------------------------------------------------
wuenic(C,V,Y,Rule,Explanation,Coverage) :-
	estimate_required(C,V,Y),
	not(anchor_point(C,V,Y,_,_,_)),
	not(year_between_WGD_segment(C,V,Y)),
	not(wgd(C,V,Y,_,assignWUENIC,_,_)),

	anchor_point(C,V,Y1,AnchorType1,_,_),
	anchor_point(C,V,Y2,AnchorType2,_,_),

	Y1 < Y, Y < Y2,
	(member(AnchorType1,['X','S']); member(AnchorType2,['X','S'])),

	not(anchor_point_between(C,V,Y1,Y2,_)),
%	not(interpolate_segment(C,V,Y1,Y2,_)),
	reported_time_series(C,V,Y,Justification,Preported),
	trend_consistent(C,V,Y1,Y2),

	calibrate_between(C,V,Y1,Y2,Y,_,P),
	value(P,Coverage),

	swritef(Rule,'CBAP:%w-%w',[AnchorType1,AnchorType2]),
	swritef(Explanation,'Reported data (%w) calibrated between %w and %w. %w',[Preported,Y1,Y2,Justification]).

% Interpolate.
% At least one anchor point not resolved to reported data.
% Anchor point and reported trends not the same.
% Estimate interpolated between anchor points.
% --------------------------------------------
wuenic(C,V,Y,Rule,Explanation,Coverage) :-
	estimate_required(C,V,Y),
	not(anchor_point(C,V,Y,_,_,_)),
	not(year_between_WGD_segment(C,V,Y)),
	not(wgd(C,V,Y,_,assignWUENIC,_,_)),

	anchor_point(C,V,Y1,AnchorType1,_,P1),
	anchor_point(C,V,Y2,AnchorType2,_,P2),

	Y1 < Y, Y < Y2,
	(member(AnchorType1,['X','S']); member(AnchorType2,['X','S'])),

	not(anchor_point_between(C,V,Y1,Y2,_)),
%	not(interpolate_segment(C,V,Y1,Y2,_)),
	not(trend_consistent(C,V,Y1,Y2)),

	interpolate(Y1,P1,Y2,P2,Y,P),
	value(P,Coverage),

	swritef(Rule,'IBAP:%w-%w',[AnchorType1,AnchorType2]),
	swritef(Explanation,'Estimate interpolated between %w and %w.',	[Y1,Y2]).

% Interpolate.
% Working group decision to
% interpolate between anchor points.
% --------------------------------------------
wuenic(C,V,Y,'WGD:IBAP',Explanation,Coverage) :-
	estimate_required(C,V,Y),
	not(wgd(C,V,Y,_,assignWUENIC,_,_)),
	interpolate_segment(C,V,Y1,Y2,Justification),
	Y1 < Y, Y < Y2,

	anchor_point(C,V,Y1,_,_,P1),
	anchor_point(C,V,Y2,_,_,P2),

	interpolate(Y1,P1,Y2,P2,Y,P),
	value(P,Coverage),

	swritef(Explanation,'Estimate based on working group decision to interpolate between %w and %w. %w', [Y1,Y2,Justification]).

% ===================================================
% Year of estmiate earlier than earliest anchor point.
% ====================================================

% Reported.
% Anchor point resolved to reported data.
% ----------------------------------------
wuenic(C,V,Y,Rule,Explanation,Coverage) :-
	estimate_required(C,V,Y),
	not(anchor_point(C,V,Y,_,_,_)),
	not(wgd(C,V,Y,_,assignWUENIC,_,_)),

	anchor_point(C,V,Y1,AnchorType,_,_), member(AnchorType,['R','XR']),

	Y < Y1,
	not(anchor_point_before(C,V,Y1,_)),
%	not(anchor_point_between(C,V,Y,Y1,_)),
	reported_time_series(C,V,Y,Justification,Coverage),

	swritef(Rule,'RFAP:%w',[AnchorType]),
	swritef(Explanation,'Estimate based on trend in reported data. %w',[Justification]).

% Extrapolate.
% Anchor point resolved to survey results or set by working group.
% ----------------------------------------------------------------
wuenic(C,V,Y,'EFAP',Explanation,Coverage) :-
	estimate_required(C,V,Y),
	not(wgd(C,V,Y,_,assignWUENIC,_,_)),
	not(anchor_point(C,V,Y,_,_,_)),

	anchor_point(C,V,Y1,AnchorType,_,Coverage),member(AnchorType,['X','S']),
	Y2 is Y1 + 1,
	not(wuenic_calibrated(C,V,Y2)),

	Y < Y1,
	anchor_point_after(C,V,Y1,_),
	not(anchor_point_before(C,V,Y1,_)),
%	not(anchor_point_between(C,V,Y,Y1,_)),

	swritef(Explanation,'Estimate extrapolated from %w value of %w.',
		[Y1,Coverage]).

% Calibrate.
% Anchor point calibrated.
%----------------------------------------------------
wuenic(C,V,Y,'CFAP',Explanation,Coverage) :-
	estimate_required(C,V,Y),
	not(wgd(C,V,Y,_,assignWUENIC,_,_)),
	not(anchor_point(C,V,Y,_,_,_)),
	not(interpolate_segment(C,V,Y1,Y2,_)),

	anchor_point(C,V,Y1,AnchorType,_,Psurv), member(AnchorType,['X','S']),
	Y < Y1,

	not(anchor_point_before(C,V,Y1,_)),
%	not(anchor_point_between(C,V,Y,Y1,_)),

	Y2 is Y1 + 1,
	wuenic_calibrated(C,V,Y2),
	calibrate_from_single(C,V,Y,Y1,Psurv,ReportedTimeSeries,_,P),
	value(P,Coverage),

	swritef(Explanation,'Reported data (%w) calibrated to %w level (%w).', [ReportedTimeSeries,Y1,Psurv]).

% ===============================================
% Year of estimated later than latest anchor point.
% ===============================================

% Reported data.
% Anchor point resolved to reported data.
% ----------------------------------------
wuenic(C,V,Y,Rule,Explanation,Coverage) :-
	estimate_required(C,V,Y),
	not(anchor_point(C,V,Y,_,_,_)),
	not(wgd(C,V,Y,_,assignWUENIC,_,_)),

	anchor_point(C,V,Y1,AnchorType,_,_), member(AnchorType,['R','XR']),

	Y1 < Y,
	not(anchor_point_after(C,V,Y1,_)),
%	not(anchor_point_between(C,V,Y1,Y,_)),
	reported_time_series(C,V,Y,Justification,Coverage),

	swritef(Rule,'RFAP:%w',[AnchorType]),
	swritef(Explanation,'Estimate based on trend in reported data. %w', [Justification]).

% Extrapolate:
% Anchor point resolved to survey results or set by working group.
% ----------------------------------------------------------------
wuenic(C,V,Y,'EFAP',Explanation,Coverage) :-
	estimate_required(C,V,Y),
	not(wgd(C,V,Y,_,assignWUENIC,_,_)),
	not(anchor_point(C,V,Y,_,_,_)),

	anchor_point(C,V,Y1,AnchorType,_,Coverage),member(AnchorType,['X','S']),
	Y2 is Y1 - 1,

	not(wuenic_calibrated(C,V,Y2)),

	Y1 < Y,

	anchor_point_before(C,V,Y1,_),
	not(anchor_point_after(C,V,Y1,_)),
	% not(anchor_point_between(C,V,Y1,Y,_)),

	swritef(Explanation,'Estimate extrapolated from %w level (%w).',[Y1,Coverage]).

% Calibrate.
% Anchor point calibrated.
%----------------------------------------------------
wuenic(C,V,Y,'CAP',Explanation,Coverage) :-
	estimate_required(C,V,Y),
	not(wgd(C,V,Y,_,assignWUENIC,_,_)),
	not(anchor_point(C,V,Y,_,_,_)),

	anchor_point(C,V,Y1,AnchorType,_,Psurv), member(AnchorType,['X','S']),
	Y1 < Y,

	not(anchor_point_after(C,V,Y1,_)),
%	not(anchor_point_between(C,V,Y1,Y,_)),

	Y2 is Y1 - 1,
	wuenic_calibrated(C,V,Y2),
       	calibrate_from_single(C,V,Y,Y1,Psurv,ReportedTimeSeries,_,P),
	value(P,Coverage),

	swritef(Explanation,'Reported data (%w) calibrated to %w level (%w).',
		[ReportedTimeSeries,Y1,Psurv]).

% Single anchor point: Calibrate if not equal to reported
% ----------------------------------------------------
wuenic(C,V,Y,'CSAP',Explanation,Coverage) :-
	estimate_required(C,V,Y),
	not(wgd(C,V,Y,_,assignWUENIC,_,_)),

	anchor_point(C,V,Y1,_,_,AnchorValue),

	not(Y1 == Y),
	not(anchor_point_before(C,V,Y1,_)),
	not(anchor_point_after(C,V,Y1,_)),

	reported_time_series(C,V,Y1,_,ReportedValueAtAnchor),
	not(AnchorValue == ReportedValueAtAnchor),

	reported_time_series(C,V,Y,_,ReportedTimeSeries),
	calibrate_from_single(C,V,Y,Y1,AnchorValue,ReportedTimeSeries,_,P),
	value(P,Coverage),

	swritef(Explanation,'Estimate calibrated to %w level (%w) and reported coverage (%w).',[Y1,AnchorValue,ReportedTimeSeries]).

% ==================================
% Determine value at anchor points.
% Anchor points are defined as years
% were there are survey results or working group
% assignments of an anchor point.
% ===============================

% Anchor point: survey result supports reported data.
% ---------------------------------------------------
new_anchor_point(C,V,Y,'R',Explanation, Preported) :-
	estimate_required(C,V,Y),
	not(wgd(C,V,Y,_,assignAnchor,_,_)),

	reported_time_series(C,V,Y,_,Preported),
	reported_accepted(C,V,Y,_,_),
	survey_results(C,V,Y,Justification,Psurvey),
	survey_supports_reported(Preported, Psurvey),

	% Create explanation.
	swritef(Explanation,'Survey (%w) confirms reported data (%w). %w',
		[Psurvey,Preported,Justification]).

% Anchor point: survey result supports trend in reported data
% but not reported point for the year.
% ------------------------------------------------------------
new_anchor_point(C,V,Y,'R',Explanation, Preported) :-
	estimate_required(C,V,Y),
	not(wgd(C,V,Y,_,assignAnchor,_,_)),

	reported_time_series(C,V,Y,_,Preported),
	not(reported_accepted(C,V,Y,_,_)),
	survey_results(C,V,Y,Justification,Psurvey),
	survey_supports_reported(Preported, Psurvey),

	% Create explanation.
	swritef(Explanation,'Survey (%w) confirms trend in reported data. %w',
		[Psurvey,Justification]).

% Anchor point where survey result does not support reported data.
% ----------------------------------------------------------------
new_anchor_point(C,V,Y, 'S',Explanation, Psurvey) :-
	estimate_required(C,V,Y),
	not(wgd(C,V,Y,_,assignAnchor,_,_)),

	reported_time_series(C,V,Y,_,Preported),
	survey_results(C,V,Y,E,Psurvey),
	not(survey_supports_reported(Preported, Psurvey)),

	% Create explanation.
	swritef(Explanation,'Reported data (%w) not consistent with survey results (%w). %w',[Preported,Psurvey,E]).

% Anchor point resolved by working group,
% same as reported time series value.
% ---------------------------------------
new_anchor_point(C,V,Y,'XR',Explanation,Prpt) :-
	estimate_required(C,V,Y),
	wgd(C,V,Y,_,assignAnchor,Justification,P1),
	reported_time_series(C,V,Y,_,P2),
	value(P1,Pwgd), value(P2,Prpt),
	Pwgd == Prpt,

	% Create explanation,
	swritef(Explanation,'%w',[Justification]).

% Anchor point resolved by working group.
% ---------------------------------------
new_anchor_point(C,V,Y,'X',Explanation,Pwgd) :-
	estimate_required(C,V,Y),
	wgd(C,V,Y,_,assignAnchor,Justification,P1),
	reported_time_series(C,V,Y,_,P2),
	value(P1,Pwgd), value(P2,Prpt),
	not(Pwgd == Prpt),

	% Create explanation,
	swritef(Explanation,'%w',[Justification]).

% Survey supports reported
% -------------------------
survey_supports_reported(Reported,Survey) :- (abs(Reported - Survey) =< 0.101).

% Set survey results. Average multiple results for same year.
% -----------------------------------------------------------
survey_results(C,V,Y,Explanation,Psurvey) :-
	bagof(P,survey_accepted(C,V,Y,P),R),
	length(R,N),N == 1,
	sumlist(R,S),Psurvey is (S / N),

	% Create explanation.
	swritef(Explanation,'',[Psurvey]).

survey_results(C,V,Y,Explanation,Psurvey) :-
	bagof(P,survey_accepted(C,V,Y,P),R),
	length(R,N), N > 1,
	sumlist(R,S), Psurvey is (S / N),

	% Create explanation.
	swritef(Explanation,'%w surveys, results = %w, mean = %w.',[N,R,Psurvey]).

% Survey data reviewed.
% ---------------------
survey_accepted(C,V,Y,Coverage) :-
	survey(C,V,Y,Description,Coverage),

	member(ss:SampleSize,Description),
	SampleSize >= 300,

	member(confirm:Method,Description),
	member(Method,['card or history']),

	member(age:AgeCohort,Description),
	member(AgeCohort,['12-23 m','12-24 m',
			      '18-29 m','15-27 m','15-26 m']),

	not(wgd(C,V,Y,Coverage,ignoreSurvey,_,_)),

%	not(survey_reason_to_exclude(C,V,Y,_,Coverage)),
	not(survey_modified(C,V,Y,Description,Coverage,_,_)).

survey_accepted(C,V,Y,Coverage) :-
	survey(C,V,Y,Description,Ps),

	member(ss:SampleSize,Description),
	SampleSize >= 300,

	member(confirm:Method,Description),
	member(Method,['card or history']),

	member(age:AgeCohort,Description),
	member(AgeCohort,['12-23 m','12-24 m',
			      '18-29 m','15-27 m','15-26 m']),

	not(wgd(C,V,Y,Ps,ignoreSurvey,_,_)),

%	not(survey_reason_to_exclude(C,V,Y,_,Ps)),
	survey_modified(C,V,Y,Description,Ps,_,Coverage).

survey_modified(C,V,Y,Description,Ps,Justification,Coverage) :-
	survey(C,V,Y,Description,Ps),

	member(ss:SampleSize,Description),
	SampleSize >= 300,

	member(confirm:Method,Description),
	member(Method,['card or history']),

	member(age:AgeCohort,Description),
	member(AgeCohort,['12-23 m','12-24 m',
			      '18-29 m','15-27 m','15-26 m']),

	not(wgd(C,V,Y,Ps,ignoreSurvey,_,_)),

%	not(survey_reason_to_exclude(C,V,Y,_,Ps)),
	recall_adjusted(C,V,Y,Description,Ps,Justification,Coverage).

% Adjust third dose for recall bias. Apply dropout observed
% between 1st and 3 dose documenented by card to history doses.
% Recalculate "card or history" based on adjustment to history.
% -------------------------------------------------------------
recall_adjusted(C,V,Y,Description_Tcoh,Ps,Explanation,Coverage) :-
	member(V,['dtp3','pol3','hib3','hepb3']),
	member(confirm:Method,Description_Tcoh),
	member(Method,['card or history']),
	member(ss:SampleSizeTcoh,Description_Tcoh),

	% Third dose, card only
	survey(C,V,Y,Description_Tc,Tc),
	member(confirm:Method_c,Description_Tc), member(Method_c,['card']),
	member(ss:SampleSizeTc,Description_Tc), SampleSizeTc == SampleSizeTcoh,

	% First dose, card or history
	sub_string(V,0,3,_,Sub), string_concat(Sub,'1',FD), string_to_atom(FD,FirstDose),
	survey(C,FirstDose,Y,Description_Fcoh,Fcoh),
	member(confirm:Method_Fcoh,Description_Fcoh), member(Method_Fcoh,['card or history']),
	member(ss:SampleSizeFcoh,Description_Fcoh), SampleSizeFcoh == SampleSizeTcoh,

	% First dose, card only
	survey(C,FirstDose,Y,Description_Fc,Fc),Fc > 0,
	member(confirm:Method_Fc,Description_Fc), member(Method_Fc,['card']),
	member(ss:SampleSizeFc,Description_Fc), SampleSizeFc == SampleSizeTcoh,

	Adj is Tc/Fc,
 	ThirdHistoryAdj is ((Fcoh - Fc)*Adj),

	Cov is Tc + ThirdHistoryAdj,
	value(Cov,Coverage),

	swritef(Explanation,'Survey results (%w) adjusted for recall bias to %w based on first dose card or history coverage (%w) and documented drop-out between first (%w) and third (%w) doses.',[Ps,Coverage,Fcoh,Fc,Tc]).

/*
recall_adjusted_reason_to_not_apply(C,V,Y,Description,Ps) :-
	survey(C,V,Y,Description,Ps),
	wgd(C,V,Y,Ps,noRecallAdjustment,_,_).

recallAdjustedReasonToNotApply(C,V,Y,Description,Ps) :-
	survey(C,V,Y,Description,Ps),
	member(cr:CardRetention,Description),
	CardRetention < 0.3.
*/

survey_reason_to_exclude(C,V,Y,Explanation,Coverage) :-
	survey(C,V,Y,Description,Coverage),
	member(ss:SampleSize,Description),
	SampleSize < 300,
	not(wgd(C,V,Y,Coverage,acceptSurvey,_,_)),
	swritef(Explanation,'Survey results of %w with sample size %w ignored; sample size less than 300.',[Coverage,SampleSize]).

survey_reason_to_exclude(C,V,Y,Explanation,Coverage) :-
	survey(C,V,Y,Description,Coverage),
	wgd(C,V,Y,Coverage,ignoreSurvey,Justification,_),

	member(confirm:Method,Description),
	member(Method,['card or history']),

	member(age:AgeCohort,Description),
	member(AgeCohort,['12-23 m','12-24 m',
			      '18-29 m','15-27 m','15-26 m']),

	swritef(Explanation,'Survey results of %w ignored by working group. %w',[Coverage,Justification]).

% Complete reported time series: reviewed reported data.
% ------------------------------------------------------
reported_time_series(C,V,Y,Justification, Coverage) :-
	estimate_required(C,V,Y),
	reported_accepted(C,V,Y,Justification,P),
	value(P,Coverage).

reported_time_series(C,V,Y,Explanation,Coverage) :-
	estimate_required(C,V,Y),
	not(reported_accepted(C,V,Y,_,_)),

	reported_accepted(C,V,Ybefore,_,Pbefore),
	reported_accepted(C,V,Yafter,_,Pafter),
	Ybefore < Y,
	Y < Yafter,
	not(reported_accepted_between(C,V,Ybefore,Yafter)),

	interpolate(Ybefore,Pbefore,Yafter,Pafter,Y,P),
	value(P,Coverage),

	swritef(Explanation,'Missing or reported reported data interpolated between reported values of %w in %w and %w in %w.',
		[Pbefore,Ybefore,Pafter,Yafter]).

reported_time_series(C,V,Y,Explanation, Coverage) :-
	estimate_required(C,V,Y),
	not(reported_accepted(C,V,Y,_,_)),

	reported_accepted(C,V,Y1,_,P),
	value(P,Coverage),
	Y1 < Y,
	not(reported_accepted_between(C,V,Y1,Y)),
	not(reported_accepted_after(C,V,Y1)),
	swritef(Explanation,'Missing or ignored reported value extrapolated from %w reported value of %w.',[Y1,Coverage]).

reported_time_series(C,V,Y,Explanation, Coverage) :-
	estimate_required(C,V,Y),
	not(reported_accepted(C,V,Y,_,_)),

	reported_accepted(C,V,Y1,_,P),
	value(P,Coverage),
	Y1 > Y,
	not(reported_accepted_between(C,V,Y,Y1)),
	not(reported_accepted_before(C,V,Y1)),
	swritef(Explanation,'Missing or ignored reported data extrapolation from %w reported value of %w.',[Y1,Coverage]).

% Reported data reviewed.
% -----------------------
reported_accepted(C,V,Y,Explanation,Coverage) :-
	data(reported,C,V,Y,Coverage),
	not(reported_reason_to_exclude(C,V,Y,_,_)),
	swritef(Explanation,'',[Coverage]).

reported_reason_to_exclude(C,V,Y,Explanation,Coverage) :-
	data(reported,C,V,Y,Coverage),Coverage > 1.00,
	swritef(Explanation,'%w reported data (%w) not used; greater than 100 percent.',[Y,Coverage]).

reported_reason_to_exclude(C,V,Y,Explanation,Coverage) :-
	sudden_temporal_change(C,V,Y,Coverage),
	swritef(Explanation,'%w reported data (%w) inconsistent; unexplained temporal change.',[Y,Coverage]).

reported_reason_to_exclude(C,V,Y,Explanation,Coverage) :-
	wgd(C,V,Y,Coverage,ignoreReported,WGDExplain,_),
	data(reported,C,V,Y,Coverage),
	swritef(Explanation,'%w reported data (%w) ignored by working group. %w',[Y,Coverage,WGDExplain]).

% Sudden temporal change.
% ------------------------
sudden_temporal_change(C,V,Y,Coverage) :-
	data(reported,C,V,Y,Coverage),
	not(wgd(C,V,Y,_,acceptReported,_,_)),

	data(reported,C,V,Y1,P1),
	data(reported,C,V,Y2,P2),

	1 is(Y - Y1), 1 is(Y2 - Y),
	((Coverage - P1 < -0.10, Coverage - P2 < -0.10);
	 (Coverage - P1 > 0.10, Coverage - P2 > 0.10)).

% Sudden temporal change for last reported year.
% ---------------------------------------------
sudden_temporal_change(C,V,Y,Coverage) :-
	data(reported,C,V,Y,Coverage),
	not(wgd(C,V,Y,_,acceptReported,_,_)),
	not(reported_after(C,V,Y)),

	data(reported,C,V,Y1,P1),

	1 is(Y - Y1),
	(abs(Coverage - P1) > 0.10).

% Add underlying data to each C,V,Y estimate
% ------------------------------------------
collect_data(C,V,Y,['RTS=',ReportedTimeSeries,'RA=',ReportedAccepted,
		    'Rpt=',Reported,'Gov=',Gov,'Admin=',Admin,'Legacy=',Legacy,
		    'SR=',SurveyResults,'SA=',SurveyAccepted,'Surv=',Survey]) :-
	addReportedTimeSeries(C,V,Y,ReportedTimeSeries),
	addReportedAccepted(C,V,Y,ReportedAccepted),
	addReported(C,V,Y,Reported),
	addGov(C,V,Y,Gov),
	addAdmin(C,V,Y,Admin),
	addLegacy(C,V,Y,Legacy),
	addSurveyResults(C,V,Y,SurveyResults),
	addSurveyAccepted(C,V,Y,SurveyAccepted),
	addSurvey(C,V,Y,Survey).

addReportedTimeSeries(C,V,Y,'') :-
	not(reported_time_series(C,V,Y,_,_)).
addReportedTimeSeries(C,V,Y,ReportedTimeSeries) :-
	reported_time_series(C,V,Y,_,ReportedTimeSeries).
addReportedAccepted(C,V,Y,'') :-
	not(reported_accepted(C,V,Y,_,_)).
addReportedAccepted(C,V,Y,ReportedAccepted) :-
	reported_accepted(C,V,Y,_,ReportedAccepted).

addReported(C,V,Y,'') :-
	not(data(reported,C,V,Y,_)).
addReported(C,V,Y,Reported) :-
	data(reported,C,V,Y,Reported).
addGov(C,V,Y,'') :-
	not(data(gov,C,V,Y,_)).
addGov(C,V,Y,Gov) :-
	data(gov,C,V,Y,Gov).
addAdmin(C,V,Y,'') :-
	not(data(admin,C,V,Y,_)).
addAdmin(C,V,Y,Admin) :-
	data(admin,C,V,Y,Admin).
addLegacy(C,V,Y,'') :-
	not(data(legacy,C,V,Y,_)).
addLegacy(C,V,Y,Legacy) :-
	data(legacy,C,V,Y,Legacy).

addSurveyResults(C,V,Y,'') :-
	not(survey_results(C,V,Y,_,_)).
addSurveyResults(C,V,Y,SurveyResults) :-
	survey_results(C,V,Y,_,SurveyResults).
addSurveyAccepted(C,V,Y,'') :-
	not(survey_accepted(C,V,Y,_)).
addSurveyAccepted(C,V,Y,SurveyAccepted) :-
	bagof(P,survey_accepted(C,V,Y,P),SurveyAccepted).
addSurvey(C,V,Y,'') :-
	not(survey_for_data(C,V,Y,_)).
addSurvey(C,V,Y,Surveys) :-
	bagof(P,survey_for_data(C,V,Y,P),Surveys).
survey_for_data(C,V,Y,Coverage) :-
	survey(C,V,Y,Description,Coverage),

	member(confirm:Method,Description),
	member(Method,['card or history']),

	member(age:AgeCohort,Description),
	member(AgeCohort,['12-23 m','12-24 m',
			      '18-29 m','15-27 m','15-26 m']).

% Add explanation to each estimate
collect_explanations(C,V,Y,Explanations) :-
	bagof(Exception,exceptions(C,V,Y,Exception),Explanations).

exceptions(C,V,Y,'') :-
	not(survey_reason_to_exclude(C,V,Y,_,_)),
	not(survey_modified(C,V,Y,_,_,_,_)),
	not(reported_reason_to_exclude(C,V,Y,_,_)),
	not(wgd(C,V,Y,_,comment,_,_)),
	not(wgd(C,V,Y,_,acceptReported,_,_)),
	not(wgd(C,V,Y,_,acceptSurvey,_,_)).

exceptions(C,V,Y,Exception) :- survey_reason_to_exclude(C,V,Y,Exception,_).
exceptions(C,V,Y,Exception) :- survey_modified(C,V,Y,_,_,Exception,_).

exceptions(C,V,Y,Exception) :- reported_reason_to_exclude(C,V,Y,Exception,_).
exceptions(C,V,Y,Exception) :- wgd(C,V,Y,_,comment,Exception,_).
exceptions(C,V,Y,Exception) :- wgd(C,V,Y,_,acceptReported,Exception,_).
exceptions(C,V,Y,Exception) :- wgd(C,V,Y,_,acceptSurvey,Exception,_).


% Utilities.
% ---------
interpolate(Year1,P1,Year2,P2,Year,Coverage) :-
	P is P1 + (Year-Year1)*((P2-P1)/(Year2-Year1)),
	value(P,Coverage).

calibrate_between(C,V,Year1,Year2,Year,Adj,ReportedCalibrated) :-
	reported_time_series(C,V,Year1,_,PR1),
	reported_time_series(C,V,Year2,_,PR2),
	anchor_point(C,V,Year1,_,_,Anchor1),
	anchor_point(C,V,Year2,_,_,Anchor2),

	reported_time_series(C,V,Year,_,ReportedTimeSeriesValue),

	interpolate(Year1,PR1,Year2,PR2,Year,ReportedInterpolated),
	interpolate(Year1,Anchor1,Year2,Anchor2,Year,AnchorInterpolated),
	Adj is AnchorInterpolated - ReportedInterpolated,

	X is ReportedTimeSeriesValue + Adj,
	value(X,ReportedCalibrated).

calibrate_from_single(C,V,Y,Y1,AnchorValue,ReportedTimeSeriesValue,Adj,ReportedCalibrated) :-
	reported_time_series(C,V,Y1,_,Reported),
	Adj is AnchorValue - Reported,

	reported_time_series(C,V,Y,_,ReportedTimeSeriesValue),

	X is ReportedTimeSeriesValue + Adj,
	value(X,ReportedCalibrated).

value(X,Y) :- X >= 0, X < 0.99, Y is ((round(X * 100)) / 100).
value(X,Y) :- X <  0, Y is 0.
value(X,Y) :- X >= 0.99, Y is 0.99.

year_between_WGD_segment(C,V,Y) :-
	interpolate_segment(C,V,Ybegin,Yend,_),
	Y > Ybegin,
	Y < Yend.

wuenic_calibrated(C,V,Y) :-
	estimate_required(C,V,Y),
	not(wgd(C,V,Y,_,assignWUENIC,_,_)),
	not(anchor_point(C,V,Y,_,_,_)),

	anchor_point(C,V,Y1,AnchorType1,_,_),
	anchor_point(C,V,Y2,AnchorType2,_,_),

	Y1 < Y, Y < Y2,
	(member(AnchorType1,['X','S']); member(AnchorType2,['X','S'])),

	not(anchor_point_between(C,V,Y1,Y2,_)),
	not(interpolate_segment(C,V,Y1,Y2,_)),
	trend_consistent(C,V,Y1,Y2).

trend_consistent(C,V,Y1,Y2) :-
	anchor_point(C,V,Y1,_,_,P1),
	anchor_point(C,V,Y2,_,_,P2),
	reported_time_series(C,V,Y1,_,P3),
	reported_time_series(C,V,Y2,_,P4),
	((P1 - P2 > 0, P3 - P4 > 0);
	 (P1 - P2 < 0, P3 - P4 < 0)).

reported_accepted_between(C,V,EarlyYear,LateYear) :-
	reported_accepted(C,V,Yb,_,_),
	Yb > EarlyYear,
	Yb < LateYear.

reported_accepted_before(C,V,Y) :-
	reported_accepted(C,V,Yb,_,_),
	Yb < Y.

reported_accepted_after(C,V,Y) :-
	reported_accepted(C,V,Ya,_,_),
	Ya > Y.

reported_after(C,V,Y) :-
	data(reported,C,V,Ya,_),
	Ya > Y.

anchor_point_between(C,V,EarlyYear,LateYear,Type) :-
	anchor_point(C,V,Yb,Type,_,_),
	Yb > EarlyYear,
	Yb < LateYear.

anchor_point_before(C,V,Y1,T) :-
	estimate_required(C,V,Yb),
	anchor_point(C,V,Yb,T,_,_),
	Yb < Y1.

anchor_point_after(C,V,Y1,T) :-
	estimate_required(C,V,Ya),
	anchor_point(C,V,Ya,T,_,_),
	Ya > Y1.

% Output to results to TAB delimited file.
%
% refactor to output disease series as columns.
% --------------------------------------------
output_estimates(Estimates) :-
	% Output estimates
        open('wuenic.out',write,Out),
	write(Out,
	      'Country_Name\tProduction_Date\tCountry\tVaccine\tYear\tWUENIC\tRule\tExplanation\tData\t'),
	nl(Out),
	output_results(Estimates,Out), close(Out).

output_results([],_).
output_results([H|T],Out) :- output_fields(H,Out), output_results(T,Out).

output_fields([],Out) :- nl(Out).
output_fields([H|T],Out) :- write(Out,H),write(Out,'\t'),output_fields(T,Out).








