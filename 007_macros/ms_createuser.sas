/*** HELP START ***//**
  @file
  @brief Creates a user on SASjs Server
  @details Creates a user on SASjs Server with the following attributes:

  @li UserName
  @li Password
  @li isAdmin
  @li displayName

  The userid is created by sasjs/server. All users are created with `isActive`
  set to `true`.

  Example:

      %ms_createuser(newuser,secretpass,displayname=New User!)

  @param [in] username The username to apply.  No spaces or special characters.
  @param [in] password The initial password to set.
  @param [in] isadmin= (false) Set to true to give the user admin rights
  @param [in] displayName= (0) Set a friendly name (spaces & special characters
    are ok).  If not provided, username will be used instead.
  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages
  @param [out] outds= (work.ms_createuser) This output dataset will contain the
    values from the JSON response (such as the id of the new user)
|ID:best.|DISPLAYNAME:$8.|USERNAME:$8.|ISACTIVE:best.|ISADMIN:best.|
|---|---|---|---|---|
|`6 `|`New User `|`newuser `|`1 `|`0 `|



  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mp_abort.sas

  <h4> Related Files </h4>
  @li ms_createuser.test.sas
  @li ms_getusers.sas

**//*** HELP END ***/

%macro ms_createuser(username,password
    ,isadmin=false
    ,displayname=0
    ,outds=work.ms_createuser
    ,mdebug=0
  );

%mp_abort(
  iftrue=(&syscc ne 0)
  ,mac=ms_createuser.sas
  ,msg=%str(syscc=&syscc on macro entry)
)

%local fref0 fref1 fref2 libref optval rc msg;
%let fref0=%mf_getuniquefileref();
%let fref1=%mf_getuniquefileref();
%let fref2=%mf_getuniquefileref();
%let libref=%mf_getuniquelibref();

/* avoid sending bom marker to API */
%let optval=%sysfunc(getoption(bomfile));
options nobomfile;

data _null_;
  file &fref0 termstr=crlf;
  username=quote(cats(symget('username')));
  password=quote(cats(symget('password')));
  isadmin=symget('isadmin');
  displayname=quote(cats(symget('displayname')));
  if displayname='"0"' then displayname=username;

%if &mdebug=1 %then %do;
  putlog _all_;
%end;

  put '{'@;
  put '"displayName":' displayname @;
  put ',"username":' username @;
  put ',"password":' password @;
  put ',"isAdmin":' isadmin @;
  put ',"isActive": true }';
run;

data _null_;
  file &fref1 lrecl=1000;
  infile "&_sasjs_tokenfile" lrecl=1000;
  input;
  if _n_=1 then do;
    put "Content-Type: application/json";
    put "accept: application/json";
  end;
  put _infile_;
run;

%if &mdebug=1 %then %do;
  data _null_;
    infile &fref0;
    input;
    put _infile_;
  data _null_;
    infile &fref1;
    input;
    put _infile_;
  run;
%end;

proc http method='POST' in=&fref0 headerin=&fref1 out=&fref2
  url="&_sasjs_apiserverurl/SASjsApi/user";
%if &mdebug=1 %then %do;
  debug level=1;
%end;
run;

%mp_abort(
  iftrue=(&syscc ne 0)
  ,mac=ms_createuser.sas
  ,msg=%str(Issue submitting query to SASjsApi/user)
)

libname &libref JSON fileref=&fref2;

data &outds;
  set &libref..root;
  drop ordinal_root;
run;


%mp_abort(
  iftrue=(&syscc ne 0)
  ,mac=ms_createuser.sas
  ,msg=%str(Issue reading response JSON)
)

/* reset options */
options &optval;

%if &mdebug=1 %then %do;
  filename &fref0 clear;
  filename &fref1 clear;
  filename &fref2 clear;
  libname &libref clear;
%end;

%mend ms_createuser;
