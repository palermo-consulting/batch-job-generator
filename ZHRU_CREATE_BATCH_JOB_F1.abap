*&---------------------------------------------------------------------*
*&  Include           ZHRU_CREATE_BATCH_JOB_F1
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&      Form  START_OF_SELECTION
*&---------------------------------------------------------------------*
*       Start of Selection
*----------------------------------------------------------------------*
FORM start_of_selection .

  DATA: ls_batch_job_sh LIKE LINE OF gt_batch_job_sh,
        ls_batch_job_lg LIKE LINE OF gt_batch_job_lg,
        ls_batch_job_pa LIKE LINE OF gt_batch_job_pa,
        lt_batch_job_sh LIKE gt_batch_job_sh,
        lv_tabix        LIKE sy-tabix.

  DATA: BEGIN OF lt_jobs OCCURS 0,
          sign   TYPE c LENGTH 1,
          option TYPE c LENGTH 2,
          low    LIKE ls_batch_job_pa-jobname,
          high   LIKE ls_batch_job_pa-jobname,
        END OF lt_jobs,
        ls_job LIKE lt_jobs.

* The program will look in the Run Date table and determine which jobs are schedule to be run on the selection screen date.
* If the time schedule has already past, the job will be skipped.
  IF p_rundt EQ sy-datum. "Same day, check that time is not past.
    SELECT * FROM zhr_batch_job_sh INTO TABLE gt_batch_job_sh
      WHERE rundate EQ p_rundt AND
            runtime GE gv_uzeit.
  ELSEIF p_rundt GT sy-datum. "In future, don't worry about the time
    SELECT * FROM zhr_batch_job_sh INTO TABLE gt_batch_job_sh
      WHERE rundate EQ p_rundt.
  ENDIF.

* The program will then review the log table ....
  IF p_rundt EQ sy-datum. "Same day, check tthat time is not past.
    SELECT * FROM zhr_batch_job_lg INTO TABLE gt_batch_job_lg
      WHERE rundate EQ p_rundt AND
            runtime GE gv_uzeit.
  ELSEIF p_rundt GT sy-datum. "In future, don't worry about the time
    SELECT * FROM zhr_batch_job_lg INTO TABLE gt_batch_job_lg
      WHERE rundate EQ p_rundt.
  ENDIF.

* And determine if the job has already been scheduled.
  lt_batch_job_sh[] = gt_batch_job_sh[].
  LOOP AT gt_batch_job_sh INTO ls_batch_job_sh.
    lv_tabix = sy-tabix.
    LOOP AT gt_batch_job_lg INTO ls_batch_job_lg
      WHERE jobname EQ ls_batch_job_sh-jobname
        AND rundate EQ ls_batch_job_sh-rundate
        AND runtime EQ ls_batch_job_sh-runtime.
      DELETE lt_batch_job_sh WHERE jobname EQ ls_batch_job_sh-jobname
                               AND rundate EQ ls_batch_job_sh-rundate
                               AND runtime EQ ls_batch_job_sh-runtime.
    ENDLOOP.
  ENDLOOP.
  gt_batch_job_sh[] = lt_batch_job_sh[].

* Get list of jobs to create
  ls_job-sign = 'I'.
  ls_job-option = 'EQ'.
  LOOP AT gt_batch_job_sh INTO ls_batch_job_sh.
    MOVE ls_batch_job_sh-jobname TO ls_job-low.
    APPEND ls_job TO lt_jobs.
  ENDLOOP.

* If the jobs have not been schedule, then the program will create the jobs with all steps and variants as per the Job Parameters table.
  SELECT * FROM zhr_batch_job_pa INTO TABLE gt_batch_job_pa
    WHERE jobname IN lt_jobs.

  SORT gt_batch_job_pa BY jobname stepno.

ENDFORM.                    " START_OF_SELECTION
*&---------------------------------------------------------------------*
*&      Form  INITIALIZATION
*&---------------------------------------------------------------------*
*       Initialization
*----------------------------------------------------------------------*
FORM initialization .

* Set the start time of the program.
  gv_uzeit = sy-uzeit.

ENDFORM.                    " INITIALIZATION
*&---------------------------------------------------------------------*
*&      Form  END_OF_SELECTION
*&---------------------------------------------------------------------*
*       End of Selection
*----------------------------------------------------------------------*
FORM end_of_selection .

  DATA: ls_batch_job_sh LIKE LINE OF gt_batch_job_sh,
        ls_batch_job_lg LIKE LINE OF gt_batch_job_lg,
        ls_batch_job_pa LIKE LINE OF gt_batch_job_pa,
        lt_batch_job_sh LIKE gt_batch_job_sh,
        ls_batch_job_df LIKE zhr_batch_job_df,
        lv_tabix        LIKE sy-tabix.

  DATA: lv_jobname    LIKE  tbtcjob-jobname,
        lv_rundate    LIKE  tbtcjob-sdlstrtdt,
        lv_runtime    LIKE  tbtcjob-sdlstrttm,
        lv_progname   LIKE  sy-repid,
        lv_variant    LIKE  raldb-variant,
        lv_stepno     LIKE  tbtcjob-stepcount,
        ls_priparams  LIKE  pri_params,
        lv_distlist   LIKE  ls_batch_job_df-distlist.

  DATA: ls_display_log LIKE LINE OF gt_display_log.

  DATA: lv_jobid    LIKE  tbtcjob-jobcount,
        lv_released LIKE  btch0000-char1.

  DATA: ls_recipient_obj      LIKE  swotobjid.

  CLEAR gt_batch_job_lg[].

* The program will create the jobs with all steps and variants as per the Job Parameters table.
  LOOP AT gt_batch_job_sh INTO ls_batch_job_sh.

    CLEAR: ls_display_log, lv_jobid.

    lv_jobname = ls_batch_job_sh-jobname.
    lv_rundate = ls_batch_job_sh-rundate.
    lv_runtime = ls_batch_job_sh-runtime.

    LOOP AT gt_batch_job_pa INTO ls_batch_job_pa
      WHERE jobname EQ ls_batch_job_sh-jobname.
    ENDLOOP.
    IF sy-subrc NE 0.
      ls_display_log-jobname = lv_jobname.
      ls_display_log-rundate = lv_rundate.
      ls_display_log-runtime = lv_runtime.
      ls_display_log-msgcode = 'E09'.
      ls_display_log-message = 'Job parameters could not be found'.
      APPEND ls_display_log TO gt_display_log.
      CONTINUE.
    ENDIF.

    CALL FUNCTION 'JOB_OPEN'
      EXPORTING
        jobname          = lv_jobname
        sdlstrtdt        = lv_rundate
        sdlstrttm        = lv_runtime
      IMPORTING
        jobcount         = lv_jobid
      EXCEPTIONS
        cant_create_job  = 1
        invalid_job_data = 2
        jobname_missing  = 3
        OTHERS           = 4.
    ls_display_log-jobname = lv_jobname.
    ls_display_log-rundate = lv_rundate.
    ls_display_log-runtime = lv_runtime.
    ls_display_log-jobid   = lv_jobid.
    IF sy-subrc <> 0.  "Couldn't open job
      CASE sy-subrc.
        WHEN '2'.
          ls_display_log-msgcode = 'E02'.
          ls_display_log-message = 'Invalid job data'.
        WHEN '3'.
          ls_display_log-msgcode = 'E03'.
          ls_display_log-message = 'Job name missing'.
        WHEN OTHERS.
          ls_display_log-msgcode = 'E01'.
          ls_display_log-message = 'Can''t create job'.
      ENDCASE.
      APPEND ls_display_log TO gt_display_log.
    ELSE. "Job opened; now add steps.
*      ls_display_log-cdate   = sy-datum.
*      ls_display_log-ctime   = sy-uzeit.
      ls_display_log-msgcode = 'S01'.
      ls_display_log-message = 'Job Opened'.
      APPEND ls_display_log TO gt_display_log.

      LOOP AT gt_batch_job_pa INTO ls_batch_job_pa
        WHERE jobname EQ ls_batch_job_sh-jobname.

        lv_progname = ls_batch_job_pa-progname.
        lv_variant  = ls_batch_job_pa-variant.
        CALL FUNCTION 'JOB_SUBMIT'
          EXPORTING
            authcknam               = ls_batch_job_pa-btuname
            jobcount                = lv_jobid
            jobname                 = lv_jobname
            report                  = lv_progname
            variant                 = lv_variant
          IMPORTING
            step_number             = lv_stepno
          EXCEPTIONS
            bad_priparams           = 1
            bad_xpgflags            = 2
            invalid_jobdata         = 3
            jobname_missing         = 4
            job_notex               = 5
            job_submit_failed       = 6
            lock_failed             = 7
            program_missing         = 8
            prog_abap_and_extpg_set = 9
            OTHERS                  = 10.
        ls_display_log-stepno = ls_batch_job_pa-stepno.
        IF sy-subrc <> 0.
          CASE sy-subrc.
            WHEN '3'.
              ls_display_log-msgcode = 'E02'.
              ls_display_log-message = 'Invalid job data'.
            WHEN '4'.
              ls_display_log-msgcode = 'E03'.
              ls_display_log-message = 'Job name missing'.
            WHEN OTHERS.
              ls_display_log-msgcode = 'E04'.
              ls_display_log-message = 'Failed to submit job step'.
          ENDCASE.
          APPEND ls_display_log TO gt_display_log.
          EXIT.
        ELSE.
          ls_display_log-msgcode = 'S02'.
          ls_display_log-message = 'Job step submitted'.
          APPEND ls_display_log TO gt_display_log.
        ENDIF.

      ENDLOOP.

*    Close job
      CLEAR ls_display_log-stepno.
      IF sy-subrc EQ 0 AND lv_jobid IS NOT INITIAL.
        SELECT SINGLE distlist FROM zhr_batch_job_df INTO (lv_distlist)
          WHERE jobname EQ lv_jobname.
        PERFORM get_recipient USING lv_distlist CHANGING ls_recipient_obj.

        CALL FUNCTION 'JOB_CLOSE'
          EXPORTING
            jobcount             = lv_jobid
            jobname              = lv_jobname
            sdlstrtdt            = lv_rundate
            sdlstrttm            = lv_runtime
            recipient_obj        = ls_recipient_obj
          IMPORTING
            job_was_released     = lv_released
          EXCEPTIONS
            cant_start_immediate = 1
            invalid_startdate    = 2
            jobname_missing      = 3
            job_close_failed     = 4
            job_nosteps          = 5
            job_notex            = 6
            lock_failed          = 7
            invalid_target       = 8
            OTHERS               = 9.
        IF sy-subrc <> 0.
          CASE sy-subrc.
            WHEN 1.
              ls_display_log-msgcode = 'E05'.
              ls_display_log-message = 'Cannot start the job immediately'.
            WHEN 2.
              ls_display_log-msgcode = 'E06'.
              ls_display_log-message = 'Invalid start date'.
            WHEN 3.
              ls_display_log-msgcode = 'E03'.
              ls_display_log-message = 'Job name missing'.
            WHEN 5.
              ls_display_log-msgcode = 'E08'.
              ls_display_log-message = 'No job steps defined.  At lease one must be defined.'.
            WHEN OTHERS.
              ls_display_log-msgcode = 'E07'.
              ls_display_log-message = 'Failed to close the job'.
          ENDCASE.
          APPEND ls_display_log TO gt_display_log.
          CALL FUNCTION 'BP_JOB_DELETE'
            EXPORTING
              jobcount                 = lv_jobid
              jobname                  = lv_jobname
            EXCEPTIONS
              cant_delete_event_entry  = 1
              cant_delete_job          = 2
              cant_delete_joblog       = 3
              cant_delete_steps        = 4
              cant_delete_time_entry   = 5
              cant_derelease_successor = 6
              cant_enq_predecessor     = 7
              cant_enq_successor       = 8
              cant_enq_tbtco_entry     = 9
              cant_update_predecessor  = 10
              cant_update_successor    = 11
              commit_failed            = 12
              jobcount_missing         = 13
              jobname_missing          = 14
              job_does_not_exist       = 15
              job_is_already_running   = 16
              no_delete_authority      = 17
              OTHERS                   = 18.
          IF sy-subrc NE 0.
            ls_display_log-msgcode = 'E10'.
            ls_display_log-message = 'Could not delete job.  Delete manually.'.
            APPEND ls_display_log TO gt_display_log.
          ENDIF.
        ELSE.
          ls_display_log-cdate   = sy-datum.
          ls_display_log-ctime   = sy-uzeit.
          ls_display_log-msgcode = 'S03'.
          ls_display_log-message = 'Job created'.
          APPEND ls_display_log TO gt_display_log.
          MOVE-CORRESPONDING ls_display_log TO ls_batch_job_lg.
          APPEND ls_batch_job_lg TO gt_batch_job_lg.

        ENDIF.
      ENDIF.
    ENDIF.
  ENDLOOP.

* The program will then update the Job Log table with the created dates and Job ID.
  INSERT zhr_batch_job_lg FROM TABLE gt_batch_job_lg.

  PERFORM display_log.


ENDFORM.                    " END_OF_SELECTION
*&---------------------------------------------------------------------*
*&      Form  DISPLAY_LOG
*&---------------------------------------------------------------------*
*       Display the log
*----------------------------------------------------------------------*
FORM display_log .

  DATA: ls_display_log        LIKE LINE OF gt_display_log,
        ls_display_log_save   LIKE LINE OF gt_display_log.

  SORT gt_display_log BY jobname rundate runtime.

  LOOP AT gt_display_log INTO ls_display_log.

    ls_display_log_save = ls_display_log.

*   Format color col_background intensified on.
    IF ls_display_log-msgcode(1) EQ 'E'.
      FORMAT COLOR COL_NEGATIVE   INTENSIFIED ON.
    ELSE.
      FORMAT COLOR COL_TOTAL INTENSIFIED ON.
    ENDIF.

    AT NEW jobname.
      WRITE /. WRITE /.

      WRITE:/ text-t01.
      WRITE:/ text-t02, ls_display_log_save-jobname.
      WRITE:/ text-t03, ls_display_log_save-rundate DD/MM/YYYY.
      WRITE:/ text-t04, ls_display_log_save-runtime .
      IF ls_display_log_save-jobid IS NOT INITIAL.
        WRITE:/ text-t05, ls_display_log_save-jobid .
      ENDIF.
      IF ls_display_log_save-cdate IS NOT INITIAL.
        WRITE:/ text-t06, ls_display_log_save-cdate .
      ENDIF.
      IF ls_display_log_save-ctime IS NOT INITIAL.
        WRITE:/ text-t07, ls_display_log_save-ctime .
      ENDIF.
      IF ls_display_log_save-stepno IS NOT INITIAL.
        WRITE:/ text-t10, ls_display_log_save-stepno .
      ENDIF.
      IF ls_display_log_save-msgcode(1) EQ 'E'.
        WRITE:/ text-t08, ls_display_log_save-msgcode .
      ELSEIF ls_display_log_save-msgcode(1) EQ 'S'.
        WRITE:/ text-t09, ls_display_log_save-msgcode .
      ENDIF.
      IF ls_display_log_save-message IS NOT INITIAL.
        WRITE:/ ls_display_log_save-message .
      ENDIF.
      CONTINUE.
    ENDAT.

    AT NEW rundate.
      WRITE /. WRITE /.

      WRITE:/ text-t01.
      WRITE:/ text-t02, ls_display_log_save-jobname.
      WRITE:/ text-t03, ls_display_log_save-rundate DD/MM/YYYY.
      WRITE:/ text-t04, ls_display_log_save-runtime .
      IF ls_display_log_save-jobid IS NOT INITIAL.
        WRITE:/ text-t05, ls_display_log_save-jobid .
      ENDIF.
      IF ls_display_log_save-cdate IS NOT INITIAL.
        WRITE:/ text-t06, ls_display_log_save-cdate .
      ENDIF.
      IF ls_display_log_save-ctime IS NOT INITIAL.
        WRITE:/ text-t07, ls_display_log_save-ctime .
      ENDIF.
      IF ls_display_log_save-stepno IS NOT INITIAL.
        WRITE:/ text-t10, ls_display_log_save-stepno .
      ENDIF.
      IF ls_display_log_save-msgcode(1) EQ 'E'.
        WRITE:/ text-t08, ls_display_log_save-msgcode .
      ELSEIF ls_display_log_save-msgcode(1) EQ 'S'.
        WRITE:/ text-t09, ls_display_log_save-msgcode .
      ENDIF.
      IF ls_display_log_save-message IS NOT INITIAL.
        WRITE:/ ls_display_log_save-message .
      ENDIF.
      CONTINUE.
    ENDAT.

    AT NEW runtime.
      WRITE /. WRITE /.

      WRITE:/ text-t01.
      WRITE:/ text-t02, ls_display_log_save-jobname.
      WRITE:/ text-t03, ls_display_log_save-rundate DD/MM/YYYY.
      WRITE:/ text-t04, ls_display_log_save-runtime .
      IF ls_display_log_save-jobid IS NOT INITIAL.
        WRITE:/ text-t05, ls_display_log_save-jobid .
      ENDIF.
      IF ls_display_log_save-cdate IS NOT INITIAL.
        WRITE:/ text-t06, ls_display_log_save-cdate .
      ENDIF.
      IF ls_display_log_save-ctime IS NOT INITIAL.
        WRITE:/ text-t07, ls_display_log_save-ctime .
      ENDIF.
      IF ls_display_log_save-stepno IS NOT INITIAL.
        WRITE:/ text-t10, ls_display_log_save-stepno .
      ENDIF.
      IF ls_display_log_save-msgcode(1) EQ 'E'.
        WRITE:/ text-t08, ls_display_log_save-msgcode .
      ELSEIF ls_display_log_save-msgcode(1) EQ 'S'.
        WRITE:/ text-t09, ls_display_log_save-msgcode .
      ENDIF.
      IF ls_display_log_save-message IS NOT INITIAL.
        WRITE:/ ls_display_log_save-message .
      ENDIF.
      CONTINUE.
    ENDAT.

    IF ls_display_log-msgcode EQ 'S03'.
      IF ls_display_log-cdate IS NOT INITIAL.
        WRITE:/ text-t06, ls_display_log-cdate .
      ENDIF.
      IF ls_display_log-ctime IS NOT INITIAL.
        WRITE:/ text-t07, ls_display_log-ctime .
      ENDIF.
    ENDIF.

    IF ls_display_log-stepno IS NOT INITIAL.
      WRITE:/ text-t10, ls_display_log-stepno .
    ENDIF.
    IF ls_display_log-msgcode(1) EQ 'E'.
      WRITE:/ text-t08, ls_display_log-msgcode .
    ELSEIF ls_display_log-msgcode(1) EQ 'S'.
      WRITE:/ text-t09, ls_display_log-msgcode .
    ENDIF.
    IF ls_display_log-message IS NOT INITIAL.
      WRITE:/ ls_display_log-message .
    ENDIF.

  ENDLOOP.

ENDFORM.                    " DISPLAY_LOG
*&---------------------------------------------------------------------*
*&      Form  GET_RECIPIENT
*&---------------------------------------------------------------------*
*       Get Recipient
*----------------------------------------------------------------------*
*      -->FV_DISLIST          Name of distribution list
*      <--FS_RECIPIENT_OBJ    Recipient object
*----------------------------------------------------------------------*
FORM get_recipient  USING    fv_dislist
                    CHANGING fs_recipient_obj LIKE swotobjid.


* Data declarations for the mail recipient
  DATA: ls_recipient     TYPE obj_record,
        ls_recipient_obj LIKE swotobjid,
        ls_display_log   LIKE LINE OF gt_display_log.

* Create the container
  swc_container ls_container.

* Generate recipient object (see report RSSOKIF1 for an example)

*  1. Create the recipient:

  "** 1.1 Generate an object reference to a recipient object
  swc_create_object ls_recipient 'RECIPIENT' space.

  "* 1.2 Write the import parameters for method
  "* recipient.createaddress into the container
  "* and empty the container
  swc_clear_container ls_container.
  "* Set address element (Share distribution list)
  swc_set_element ls_container 'AddressString' fv_dislist.
  "* Set address type (shared distribution list)
  swc_set_element ls_container 'TypeId' 'C'.

  "* 1.3 Call the method recipient.createaddress
  swc_call_method ls_recipient 'CreateAddress' ls_container.

* Issue any error message generated by a method exception
  IF sy-subrc NE 0.
    ls_display_log-msgcode = 'E11'.
    ls_display_log-message = 'Failed to create recipient.'.
    APPEND ls_display_log TO gt_display_log.
  ENDIF.

  swc_call_method ls_recipient 'Save' ls_container.
  swc_object_to_persistent ls_recipient ls_recipient_obj.
* Recipient has been generated and is ready for use in a
* background job

  MOVE ls_recipient_obj TO fs_recipient_obj.

ENDFORM.                    " GET_RECIPIENT
*&---------------------------------------------------------------------*
*&      Form  GET_OBJKEY
*&---------------------------------------------------------------------*
*       Get object key of recipient
*----------------------------------------------------------------------*
*      -->FV_DISLIST  Name of distribution list
*      <--FS_OBJKEY   Object key
*----------------------------------------------------------------------*
FORM get_objkey  USING    fv_dislist
                 CHANGING fs_objkey TYPE ts_objkey.

*        idtype          TYPE so_rec_tp,
*        idyear          TYPE so_rec_yr,
*        idnumber        TYPE so_rec_no,
*        sendtype        TYPE tddevice,
*        sequencenumber  TYPE so_lfd_nr,
*        extidyear       TYPE obj_yr,
*        extidnumber     TYPE obj_no,

  DATA: lv_dli_name LIKE  soobjinfi1-obj_name,
        ls_dli_data LIKE  sodlidati1,
        lv_objno    TYPE  c LENGTH 12,
        lv_objyr    TYPE  c LENGTH 2,
        lv_rcode    LIKE  sy-subrc.

  lv_dli_name = fv_dislist.

  CALL FUNCTION 'SO_DLI_READ_API1'
    EXPORTING
      dli_name                   = lv_dli_name
      shared_dli                 = 'X'
    IMPORTING
      dli_data                   = ls_dli_data
    EXCEPTIONS
      dli_not_exist              = 1
      operation_no_authorization = 2
      parameter_error            = 3
      x_error                    = 4
      OTHERS                     = 5.

* First part of key
  MOVE ls_dli_data-object_id TO fs_objkey.

* Second part of key
  PERFORM get_next_number(sapfsso2) USING 'RCP'
        CHANGING lv_objno lv_objyr lv_rcode.

  MOVE lv_objyr TO fs_objkey-extidyear.
  MOVE lv_objno TO fs_objkey-extidnumber.

ENDFORM.                    " GET_OBJKEY
