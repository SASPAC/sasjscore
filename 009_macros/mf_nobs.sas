/*** HELP START ***//**
  @file
  @brief Returns number of logical (undeleted) observations.
  @details Beware - will not work on external database tables!
  Is just a convenience macro for calling <code> %mf_getattrn()</code>.

        %put Number of observations=%mf_nobs(sashelp.class);

  <h4> SAS Macros </h4>
  @li mf_getattrn.sas

  @param [in] libds library.dataset

  @return output returns result of the attrn value supplied, or log message
    if err.


  @version 9.2
  @author Allan Bowe

**//*** HELP END ***/

%macro mf_nobs(libds
)/*/STORE SOURCE*/;
  %mf_getattrn(&libds,NLOBS)
%mend mf_nobs;
