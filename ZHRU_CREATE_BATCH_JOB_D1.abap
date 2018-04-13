*&---------------------------------------------------------------------*
*&  Include           ZHRU_CREATE_BATCH_JOB_D1
*&---------------------------------------------------------------------*

TYPES: BEGIN OF ts_display_log.
        INCLUDE TYPE zhr_batch_job_lg.
TYPES:  stepno  TYPE btcstepcnt,
        msgcode TYPE c LENGTH 3,
        message TYPE c LENGTH 255,
       END OF ts_display_log.

TYPES: tt_display_log TYPE STANDARD TABLE OF ts_display_log.

TYPES: BEGIN OF ts_objkey,
        idtype          TYPE so_rec_tp,
        idyear          TYPE so_rec_yr,
        idnumber        TYPE so_rec_no,
        sendtype        TYPE tddevice,
        sequencenumber  TYPE so_lfd_nr,
        extidyear       TYPE obj_yr,
        extidnumber     TYPE obj_no,
       END OF ts_objkey.

DATA: gt_batch_job_sh TYPE STANDARD TABLE OF zhr_batch_job_sh,
      gt_batch_job_pa TYPE STANDARD TABLE OF zhr_batch_job_pa,
      gt_batch_job_lg TYPE STANDARD TABLE OF zhr_batch_job_lg.

DATA: gt_display_log TYPE tt_display_log.

DATA: gv_uzeit LIKE sy-uzeit.

INCLUDE <cntn01>.
