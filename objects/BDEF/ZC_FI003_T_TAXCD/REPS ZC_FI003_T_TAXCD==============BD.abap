projection implementation in class ZBP_C_FI003_T_TAXCD unique;
strict ( 2 );
use draft;
define behavior for ZC_FI003_T_TAXCD alias ZcFi003TTaxcd
use etag

{
  use create;
  use update;
  use delete;

  use action Edit;
  use action Activate;
  use action Discard;
  use action Resume;
  use action Prepare;
}