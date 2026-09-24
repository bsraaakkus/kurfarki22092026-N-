CLASS zfi003_cl_dd_behaviourd DEFINITION PUBLIC ABSTRACT FINAL FOR BEHAVIOR OF zfi003_dd_behaviourd.
  CLASS-DATA: gt_table  TYPE TABLE FOR ACTION IMPORT i_journalentrytp~Post,
              gv_pid    TYPE abp_behv_pid.