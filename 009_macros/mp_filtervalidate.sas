/*** HELP START ***//**
  @file
  @brief Checks a generated filter query for validity
  @details Runs a generated filter in proc sql with the validate option.
  Used in mp_filtercheck.sas in an fcmp container.

  Built to support dynamic filtering in
  [Data Controller for SAS&reg;](https://datacontroller.io).

  Usage:

      data work.filtertable;
        infile datalines4 dsd;
        input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
          OPERATOR_NM:$10. RAW_VALUE:$4000.;
      datalines4;
      AND,AND,1,AGE,=,12
      AND,AND,1,SEX,<=,"'M'"
      AND,OR,2,Name,NOT IN,"('Jane','Alfred')"
      AND,OR,2,Weight,>=,7
      ;;;;
      run;

      %mp_filtergenerate(work.filtertable,outref=myfilter)

      %mp_filtervalidate(myfilter,sashelp.class)


  @returns The SYSCC value will be 1008 if there are validation issues.

  @param [in] inref The input fileref to validate (generated by
    mp_filtergenerate.sas)
  @param [in] targetds The target dataset against which to verify the query
  @param [out] abort= (YES) If YES will call mp_abort.sas on any exceptions
  @param [out] outds= (work.mp_filtervalidate) Output dataset containing the
    err / warning message, if one exists.  If this table contains any rows,
    there are problems!

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mf_nobs.sas
  @li mp_abort.sas

  <h4> Related Macros </h4>
  @li mp_filtercheck.sas
  @li mp_filtergenerate.sas

  @version 9.3
  @author Allan Bowe

**//*** HELP END ***/

%macro mp_filtervalidate(inref,targetds,abort=YES,outds=work.mp_filtervalidate);

%mp_abort(iftrue= (&syscc ne 0 or &syserr ne 0)
  ,mac=&sysmacroname
  ,msg=%str(syscc=&syscc / syserr=&syserr - on macro entry)
)

%local fref1;
%let fref1=%mf_getuniquefileref();

data _null_;
  file &fref1;
  infile &inref end=eof;
  if _n_=1 then do;
    put "proc sql;";
    put "validate select * from &targetds";
    put "where " ;
  end;
  input;
  put _infile_;
  putlog _infile_;
  if eof then put ";quit;";
run;

%inc &fref1;

data &outds;
  if &sqlrc or &syscc or &syserr then do;
    REASON_CD='VALIDATION_ERR'!!'OR: '!!
      coalescec(symget('SYSERRORTEXT'),symget('SYSWARNINGTEXT'));
    output;
  end;
  else stop;
run;

filename &fref1 clear;

%if %mf_nobs(&outds)>0 %then %do;
  %if &abort=YES %then %do;
    data _null_;
      set &outds;
      call symputx('REASON_CD',reason_cd,'l');
      stop;
    run;
    %mp_abort(
      mac=&sysmacroname,
      msg=%str(Filter validation issues.)
    )
  %end;
  %let syscc=1008;
%end;

%mend mp_filtervalidate;
