/*** HELP START ***//**
  @file
  @brief abort gracefully according to context
  @details Configures an abort mechanism according to site specific policies or
    the particulars of an environment.  For instance, can stream custom
    results back to the client in an STP Web App context, or completely stop
    in the case of a batch run.  For STP sessions

  The method used varies according to the context.  Important points:

  @li should not use endsas or abort cancel in 9.4m3 WIN environments as this
    can cause hung multibridge sessions and result in a frozen STP server
  @li The use of endsas in 9.4m6+ windows environments for POST requests to the
    STP server can result in an empty response body
  @li should not use endsas in viya 3.5 as this destroys the session and cannot
    fetch results (although both mv_getjoblog.sas and the @sasjs/adapter will
    recognise this and fetch the log of the parent session instead)
  @li STP environments must finish cleanly to avoid the log being sent to
    _webout.  To assist with this, we also run stpsrvset('program error', 0)
    and set SYSCC=0.
    Where possible, we take a unique "soft abort" approach - we open a macro
    but don't close it!  This works everywhere EXCEPT inside a \%include inside
    a macro.  For that, we recommend you use mp_include.sas to perform the
    include, and then call \%mp_abort(mode=INCLUDE) from the source program (ie,
    OUTSIDE of the top-parent macro).
    The soft abort has become ineffective in 9.4m6 WINDOWS environments.  We are
    currently investigating approaches to deal with this.


  @param [in] mac= (mp_abort.sas) To contain the name of the calling macro. Do
    not use &sysmacroname as this will always resolve to MP_ABORT.
  @param [out] msg= message to be returned
  @param [in] iftrue= (1=1) Condition under which the macro should be executed
  @param [in] errds= (work.mp_abort_errds) There is no clean way to end a
    process within a %include called within a macro.  Furthermore, there is no
    way to test if a macro is called within a %include.  To handle this
    particular scenario, the %include should be switched for the mp_include.sas
    macro.
    This provides an indicator that we are running a macro within a \%include
    (`_SYSINCLUDEFILEDEVICE`) and allows us to provide a dataset with the abort
    values (msg, mac).
    We can then run an abort cancel FILE to stop the include running, and pass
    the dataset back to the calling program to run a regular \%mp_abort().
    The dataset will contain the following fields:
    @li iftrue (1=1)
    @li msg (the message)
    @li mac (the mac param)

  @param [in] mode= (REGULAR) If mode=INCLUDE then the &errds dataset is checked
    for an abort status.
    Valid values:
    @li REGULAR (default)
    @li INCLUDE

  @version 9.4
  @author Allan Bowe

  <h4> Related Macros </h4>
  @li mp_include.sas

  @cond
**//*** HELP END ***/

%macro mp_abort(mac=mp_abort.sas, type=, msg=, iftrue=%str(1=1)
  , errds=work.mp_abort_errds
  , mode=REGULAR
)/*/STORE SOURCE*/;

%global sysprocessmode sysprocessname sasjs_stpsrv_header_loc sasjsprocessmode;
%local fref fid i;

%if not(%eval(%unquote(&iftrue))) %then %return;

%put NOTE: ///  mp_abort macro executing //;
%if %length(&mac)>0 %then %put NOTE- called by &mac;
%put NOTE - &msg;

%if %symexist(_SYSINCLUDEFILEDEVICE)
/* abort cancel FILE does not restart outside the INCLUDE on Viya 3.5 */
and %superq(SYSPROCESSNAME) ne %str(Compute Server)
%then %do;
  %if "*&_SYSINCLUDEFILEDEVICE*" ne "**" %then %do;
    data &errds;
      iftrue='1=1';
      length mac $100 msg $5000;
      mac=symget('mac');
      msg=symget('msg');
    run;
    data _null_;
      abort cancel FILE;
    run;
    %return;
  %end;
%end;

/* Web App Context */
%if %symexist(_PROGRAM)
  or %superq(SYSPROCESSNAME) = %str(Compute Server)
  or &mode=INCLUDE
%then %do;
  options obs=max replace mprint;
  %if "%substr(&sysver,1,1)" ne "4" and "%substr(&sysver,1,1)" ne "5"
  %then %do;
    options nosyntaxcheck;
  %end;

  %if &mode=INCLUDE %then %do;
    %if %sysfunc(exist(&errds))=1 %then %do;
      data _null_;
        set &errds;
        call symputx('iftrue',iftrue,'l');
        call symputx('mac',mac,'l');
        call symputx('msg',msg,'l');
        putlog (_all_)(=);
      run;
      %if (&iftrue)=0 %then %return;
    %end;
    %else %do;
      %put &sysmacroname: No include errors found;
      %return;
    %end;
  %end;

  /* extract log errs / warns, if exist */
  %local logloc logline;
  %global logmsg; /* capture global messages */
  %if %symexist(SYSPRINTTOLOG) %then %let logloc=&SYSPRINTTOLOG;
  %else %let logloc=%qsysfunc(getoption(LOG));
  proc printto log=log;run;
  %let logline=0;
  %if %length(&logloc)>0 %then %do;
    data _null_;
      infile &logloc lrecl=5000;
      input; putlog _infile_;
      i=1;
      retain logonce 0;
      if (
          _infile_=:"%str(WARN)ING" or _infile_=:"%str(ERR)OR"
        ) and logonce=0 then
      do;
        call symputx('logline',_n_);
        logonce+1;
      end;
    run;
    /* capture log including lines BEFORE the err */
    %if &logline>0 %then %do;
      data _null_;
        infile &logloc lrecl=5000;
        input;
        i=1;
        stoploop=0;
        if _n_ ge &logline-15 and stoploop=0 then do until (i>22);
          call symputx('logmsg',catx('\n',symget('logmsg'),_infile_));
          input;
          i+1;
          stoploop=1;
        end;
        if stoploop=1 then stop;
      run;
    %end;
  %end;

  %if %symexist(SYS_JES_JOB_URI) %then %do;
    /* setup webout for Viya */
    options nobomfile;
    %if "X&SYS_JES_JOB_URI.X"="XX" %then %do;
        filename _webout temp lrecl=999999 mod;
    %end;
    %else %do;
      filename _webout filesrvc parenturi="&SYS_JES_JOB_URI"
        name="_webout.json" lrecl=999999 mod;
    %end;
  %end;
  %else %if %sysfunc(filename(fref,&sasjs_stpsrv_header_loc))=0 %then %do;
    options nobomfile;
    /* set up http header for SASjs Server */
    %let fid=%sysfunc(fopen(&fref,A));
    %if &fid=0 %then %do;
      %put %str(ERR)OR: %sysfunc(sysmsg());
      %return;
    %end;
    %let rc=%sysfunc(fput(&fid,%str(Content-Type: application/json)));
    %let rc=%sysfunc(fwrite(&fid));
    %let rc=%sysfunc(fclose(&fid));
    %let rc=%sysfunc(filename(&fref));
  %end;

  /* send response in SASjs JSON format */
  data _null_;
    file _webout mod lrecl=32000 encoding='utf-8';
    length msg syswarningtext syserrortext $32767 mode $10 ;
    sasdatetime=datetime();
    msg=symget('msg');
  %if &logline>0 %then %do;
    msg=cats(msg,'\n\nLog Extract:\n',symget('logmsg'));
  %end;
    /* escape the escapes */
    msg=tranwrd(msg,'\','\\');
    /* escape the quotes */
    msg=tranwrd(msg,'"','\"');
    /* ditch the CRLFs as chrome complains */
    msg=compress(msg,,'kw');
    /* quote without quoting the quotes (which are escaped instead) */
    msg=cats('"',msg,'"');
    if symexist('_debug') then debug=quote(trim(symget('_debug')));
    else debug='""';
    if symget('sasjsprocessmode')='Stored Program' then mode='SASJS';
    if mode ne 'SASJS' then put '>>weboutBEGIN<<';
    put '{"SYSDATE" : "' "&SYSDATE" '"';
    put ',"SYSTIME" : "' "&SYSTIME" '"';
    put ',"sasjsAbort" : [{';
    put ' "MSG":' msg ;
    put ' ,"MAC": "' "&mac" '"}]';
    put ",""SYSUSERID"" : ""&sysuserid"" ";
    put ',"_DEBUG":' debug ;
    if symexist('_metauser') then do;
      _METAUSER=quote(trim(symget('_METAUSER')));
      put ",""_METAUSER"": " _METAUSER;
      _METAPERSON=quote(trim(symget('_METAPERSON')));
      put ',"_METAPERSON": ' _METAPERSON;
    end;
    if symexist('SYS_JES_JOB_URI') then do;
      SYS_JES_JOB_URI=quote(trim(symget('SYS_JES_JOB_URI')));
      put ',"SYS_JES_JOB_URI": ' SYS_JES_JOB_URI;
    end;
    _PROGRAM=quote(trim(resolve(symget('_PROGRAM'))));
    put ',"_PROGRAM" : ' _PROGRAM ;
    put ",""SYSCC"" : ""&syscc"" ";
    syserrortext=cats(symget('syserrortext'));
    if findc(syserrortext,'"\'!!'0A0D09000E0F010210111A'x) then do;
      syserrortext='"'!!trim(
        prxchange('s/"/\\"/',-1,        /* double quote */
        prxchange('s/\x0A/\n/',-1,      /* new line */
        prxchange('s/\x0D/\r/',-1,      /* carriage return */
        prxchange('s/\x09/\\t/',-1,     /* tab */
        prxchange('s/\x00/\\u0000/',-1, /* NUL */
        prxchange('s/\x0E/\\u000E/',-1, /* SS  */
        prxchange('s/\x0F/\\u000F/',-1, /* SF  */
        prxchange('s/\x01/\\u0001/',-1, /* SOH */
        prxchange('s/\x02/\\u0002/',-1, /* STX */
        prxchange('s/\x10/\\u0010/',-1, /* DLE */
        prxchange('s/\x11/\\u0011/',-1, /* DC1 */
        prxchange('s/\x1A/\\u001A/',-1, /* SUB */
        prxchange('s/\\/\\\\/',-1,syserrortext)
      )))))))))))))!!'"';
    end;
    else syserrortext=cats('"',syserrortext,'"');
    put ',"SYSERRORTEXT" : ' syserrortext;
    put ",""SYSHOSTNAME"" : ""&syshostname"" ";
    put ",""SYSJOBID"" : ""&sysjobid"" ";
    put ",""SYSSCPL"" : ""&sysscpl"" ";
    put ",""SYSSITE"" : ""&syssite"" ";
    sysvlong=quote(trim(symget('sysvlong')));
    put ',"SYSVLONG" : ' sysvlong;
    syswarningtext=cats(symget('syswarningtext'));
    if findc(syswarningtext,'"\'!!'0A0D09000E0F010210111A'x) then do;
      syswarningtext='"'!!trim(
        prxchange('s/"/\\"/',-1,        /* double quote */
        prxchange('s/\x0A/\n/',-1,      /* new line */
        prxchange('s/\x0D/\r/',-1,      /* carriage return */
        prxchange('s/\x09/\\t/',-1,     /* tab */
        prxchange('s/\x00/\\u0000/',-1, /* NUL */
        prxchange('s/\x0E/\\u000E/',-1, /* SS  */
        prxchange('s/\x0F/\\u000F/',-1, /* SF  */
        prxchange('s/\x01/\\u0001/',-1, /* SOH */
        prxchange('s/\x02/\\u0002/',-1, /* STX */
        prxchange('s/\x10/\\u0010/',-1, /* DLE */
        prxchange('s/\x11/\\u0011/',-1, /* DC1 */
        prxchange('s/\x1A/\\u001A/',-1, /* SUB */
        prxchange('s/\\/\\\\/',-1,syswarningtext)
      )))))))))))))!!'"';
    end;
    else syswarningtext=cats('"',syswarningtext,'"');
    put ",""SYSWARNINGTEXT"" : " syswarningtext;
    put ',"END_DTTM" : "' "%sysfunc(datetime(),E8601DT26.6)" '" ';
    put "}" ;
    if mode ne 'SASJS' then put '>>weboutEND<<';
  run;

  %put _all_;

  %if "&sysprocessmode " = "SAS Stored Process Server " %then %do;
    data _null_;
      putlog 'stpsrvset program err and syscc';
      rc=stpsrvset('program error', 0);
      call symputx("syscc",0,"g");
    run;
    %if &sysscp=WIN
    and 1=0 /* deprecating this logic until we figure out a consistent abort */
    and "%substr(%str(&sysvlong         ),1,8)"="9.04.01M"
    and "%substr(%str(&sysvlong         ),9,1)">"5" %then %do;
      /* skip approach (below) does not work in windows m6+ envs */
      endsas;
    %end;
    %else %do;
      /**
        * endsas kills 9.4m3 deployments by orphaning multibridges.
        * Abort variants are ungraceful (non zero return code)
        * This approach lets SAS run silently until the end :-)
        * Caution - fails when called within a %include within a macro
        * Use mp_include() to handle this.
        */
      filename skip temp;
      data _null_;
        file skip;
        put '%macro skip();';
        comment '%mend skip; -> fix lint ';
        put '%macro skippy();';
        comment '%mend skippy; -> fix lint ';
      run;
      %inc skip;
    %end;
  %end;
  %else %if "&sysprocessmode " = "SAS Compute Server " %then %do;
    /* endsas kills the session making it harder to fetch results */
    data _null_;
      syswarningtext=symget('syswarningtext');
      syserrortext=symget('syserrortext');
      abort_msg=symget('msg');
      syscc=symget('syscc');
      sysuserid=symget('sysuserid');
      iftrue=symget('iftrue');
      put (_all_)(/=);
      call symputx('syscc',0);
      abort cancel nolist;
    run;
  %end;
  %else %do;
    %abort cancel;
  %end;
%end;
%else %do;
  %put _all_;
  %abort cancel;
%end;
%mend mp_abort;

/** @endcond */
