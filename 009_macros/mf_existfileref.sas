/*** HELP START ***//**
  @file
  @brief Checks whether a fileref exists
  @details You can probably do without this macro as it is just a one liner.
  Mainly it is here as a convenient way to remember the syntax!

  @param [in] fref the fileref to detect

  @return output Returns 1 if found and 0 if not found.  Note - it is possible
  that the fileref is found, but the file does not (yet) exist. If you need
  to test for this, you may as well use the fileref function directly.

  @version 8
  @author [Allan Bowe](https://www.linkedin.com/in/allanbowe/)
**//*** HELP END ***/

%macro mf_existfileref(fref
)/*/STORE SOURCE*/;

  %local rc;
  %let rc=%sysfunc(fileref(&fref));
  %if &rc=0 %then %do;
    1
  %end;
  %else %if &rc<0 %then %do;
    %put &sysmacroname: Fileref &fref exists but the underlying file does not;
    1
  %end;
  %else %do;
    0
  %end;

%mend mf_existfileref;
