/*** HELP START ***//**
  @file
  @brief The CNTLOUT table generated by proc format
  @details The actual CNTLOUT table may have varying variable lengths,
  depending on the data values, therefore the max possible lengths
  (given various practical restrictions) are described here to enable
  consistency when dealing with format data.

**//*** HELP END ***/


%macro mddl_sas_cntlout(libds=WORK.CNTLOUT);

  proc sql;
  create table &libds(
    TYPE char(1) label='Type of format - either N (num fmt), C (char fmt), I (num infmt) or J (char infmt)'
    ,FMTNAME char(32)     label='Format name'
    ,FMTROW num label='CALCULATED Position of record by FMTNAME (reqd for multilabel formats)'
    ,START char(32767)    label='Starting value for format'
    /*
      Keep lengths of START and END the same to avoid this err:
      "Start is greater than end:  -<."
      Similar usage note: https://support.sas.com/kb/69/330.html
    */
    ,END char(32767)      label='Ending value for format'
    ,LABEL char(32767)    label='Format value label'
    ,MIN num length=3     label='Minimum length'
    ,MAX num length=3     label='Maximum length'
    ,DEFAULT num length=3 label='Default length'
    ,LENGTH num length=3  label='Format length'
    ,FUZZ num             label='Fuzz value'
    ,PREFIX char(2)       label='Prefix characters'
    ,MULT num             label='Multiplier'
    ,FILL char(1)         label='Fill character'
    ,NOEDIT num length=3  label='Is picture string noedit?'
    ,SEXCL char(1)        label='Start exclusion'
    ,EEXCL char(1)        label='End exclusion'
    ,HLO char(13)         label='Additional information. M=MultiLabel'
    ,DECSEP char(1)       label='Decimal separator'
    ,DIG3SEP char(1)      label='Three-digit separator'
    ,DATATYPE char(8)     label='Date/time/datetime?'
    ,LANGUAGE char(8)     label='Language for date strings'
  );

  %local lib;
  %let libds=%upcase(&libds);
  %if %index(&libds,.)=0 %then %let lib=WORK;
  %else %let lib=%scan(&libds,1,.);

  proc datasets lib=&lib noprint;
    modify %scan(&libds,-1,.);
    index create
      pk_cntlout=(type fmtname fmtrow)
      /nomiss unique;
  quit;

%mend mddl_sas_cntlout;
