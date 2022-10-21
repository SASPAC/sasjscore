/*** HELP START ***//**
  @file
  @brief Create an empty dataset from a metadata definition
  @details This macro was built to support viewing empty tables in
  https://datacontroller.io

  The table can be retrieved using LIBRARY.DATASET reference, or directly
  using the metadata URI.

  The dataset is written to the WORK library.

  Usage:

      %mm_createdataset(libds=metlib.some_dataset)

  or

      %mm_createdataset(tableuri=G5X8AFW1.BE00015Y)

  <h4> SAS Macros </h4>
  @li mm_getlibs.sas
  @li mm_gettables.sas
  @li mm_getcols.sas

  @param libds= library.dataset metadata source.  Note - table names in metadata
    can be longer than 32 chars (just fyi, not an issue here)
  @param tableuri= Metadata URI of the table to be created
  @param outds= (work.mm_createdataset) The dataset to create.  The table name
    needs to be 32 chars or less as per SAS naming rules.
  @param mdebug= (0) Set to 1 to enable DEBUG messages

  @version 9.4
  @author Allan Bowe

**//*** HELP END ***/

%macro mm_createdataset(libds=,tableuri=,outds=work.mm_createdataset,mDebug=0);
%local dbg errorcheck tempds1 tempds2 tempds3;
%if &mDebug=0 %then %let dbg=*;
%let errorcheck=1;

%if %index(&libds,.)>0 %then %do;
  /* get lib uri */
  data;run;%let tempds1=&syslast;
  %mm_getlibs(outds=&tempds1)
  data _null_;
    set &tempds1;
    if upcase(libraryref)="%upcase(%scan(&libds,1,.))";
    call symputx('liburi',LibraryId,'l');
  run;
  /* get ds uri */
  data;run;%let tempds2=&syslast;
  %mm_gettables(uri=&liburi,outds=&tempds2)
  data _null_;
    set &tempds2;
    where upcase(tablename)="%upcase(%scan(&libds,2,.))";
    &dbg putlog tableuri=;
    call symputx('tableuri',tableuri);
  run;
%end;

data;run;
%let tempds3=&syslast;
%mm_getcols(tableuri=&tableuri,outds=&tempds3)

%if %mf_nobs(&tempds3)=0 %then %do;
  %put &libds (&tableuri) has no columns defined!!;
  data &outds;
  run;
  %return;
%end;

data _null_;
  set &tempds3 end=last;
  if _n_=1 then call execute('data &outds;');
  length attrib $32767;

  if SAScolumntype='C' then type='$';
  attrib='attrib '!!cats(colname)!!' length='!!cats(type,SASColumnLength,'.');

  if not missing(sasformat) then fmt=' format='!!cats(sasformat);
  if not missing(sasinformat) then infmt=' informat='!!cats(sasinformat);
  if not missing(coldesc) then desc=' label='!!quote(cats(coldesc));

  attrib=trim(attrib)!!fmt!!infmt!!desc!!';';

  call execute(attrib);
  if last then call execute('call missing(of _all_);stop;run;');
run;

%mend mm_createdataset;
