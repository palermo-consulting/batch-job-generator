*&---------------------------------------------------------------------*
*& Report  ZHRU_CREATE_BATCH_JOB
*&
*&---------------------------------------------------------------------*
*&
*&
*&---------------------------------------------------------------------*

REPORT zhru_create_batch_job.

INCLUDE zhru_create_batch_job_d1.
INCLUDE zhru_create_batch_job_s1.
INCLUDE zhru_create_batch_job_f1.

INITIALIZATION.

  PERFORM initialization.

START-OF-SELECTION.

  PERFORM start_of_selection.

END-OF-SELECTION.

  PERFORM end_of_selection.
