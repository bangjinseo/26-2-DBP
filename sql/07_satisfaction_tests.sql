-- 만족도 자동 검증. 03_satisfaction_seed.sql 뒤 실행하며, 검증용 변경은 롤백한다.
SET SERVEROUTPUT ON
CREATE OR REPLACE TRIGGER test_fail_satisfaction_log
BEFORE INSERT ON change_log FOR EACH ROW
BEGIN
 IF :NEW.target_type='SURVEY_RESPONSE' AND :NEW.action_type='COMPLETE' THEN
  RAISE_APPLICATION_ERROR(-20999,'Injected satisfaction log failure');
 END IF;
END;
/

DECLARE
 v_n NUMBER;
 v_score NUMBER;
 v_count NUMBER;
 v_question NUMBER;
 v_question2 NUMBER;
 v_response NUMBER;
 v_status VARCHAR2(15);
 v_code NUMBER;
 v_cursor SYS_REFCURSOR;

 PROCEDURE eq(p_name VARCHAR2,p_actual NUMBER,p_expected NUMBER) IS
 BEGIN
  IF p_actual IS NULL OR p_actual<>p_expected THEN
   RAISE_APPLICATION_ERROR(-20820,p_name||': expected='||p_expected||',actual='||p_actual);
  END IF;
  DBMS_OUTPUT.PUT_LINE('PASS | '||p_name||' | expected='||p_expected||' actual='||p_actual);
 END;

 PROCEDURE error_is(p_name VARCHAR2,p_sql VARCHAR2,p_expected NUMBER) IS
  v_actual NUMBER:=0;
 BEGIN
  SAVEPOINT satisfaction_expected_error;
  BEGIN EXECUTE IMMEDIATE p_sql;
  EXCEPTION WHEN OTHERS THEN v_actual:=SQLCODE;
  END;
  ROLLBACK TO satisfaction_expected_error;
  eq(p_name,v_actual,p_expected);
 END;
BEGIN
 SELECT COUNT(*) INTO v_n FROM user_errors WHERE name='SATISFACTION_WORKFLOW';
 eq('satisfaction package compile errors',v_n,0);
 SELECT COUNT(*) INTO v_n FROM user_objects
  WHERE object_name IN ('SATISFACTION_WORKFLOW','V_SATISFACTION_SUMMARY','V_SATISFACTION_BY_DEPARTMENT')
    AND status='VALID';
 eq('satisfaction valid package and views',v_n,4);

 SELECT average_score,response_count INTO v_score,v_count
  FROM v_satisfaction_summary WHERE survey_id=1 AND question_order=1;
 eq('Q10 completed score average',v_score,4.5);
 eq('Q10 excludes incomplete response',v_count,4);
 SELECT average_score,response_count INTO v_score,v_count
  FROM v_satisfaction_summary WHERE survey_id=1 AND question_order=2;
 eq('Q10 second score average',v_score,4);
 eq('Q10 second score response count',v_count,4);
 SELECT COUNT(*) INTO v_n FROM v_satisfaction_summary
  WHERE survey_id=1 AND question_type='TEXT' AND average_score IS NULL AND response_count=4;
 eq('Q10 text answers have no average',v_n,1);

 SELECT COUNT(*) INTO v_n FROM v_satisfaction_by_department
  WHERE survey_id=1 AND question_order=1 AND department_id=10 AND grade=1
    AND average_score=4.67 AND response_count=3;
 eq('Q11 department and grade aggregation',v_n,1);
 SELECT COUNT(*) INTO v_n FROM v_satisfaction_by_department
  WHERE survey_id=1 AND question_type='TEXT' AND answer_text IS NOT NULL;
 eq('Q11 anonymous text opinions',v_n,4);
 SELECT COUNT(*) INTO v_n FROM user_tab_columns
  WHERE table_name='V_SATISFACTION_BY_DEPARTMENT'
    AND column_name IN ('STUDENT_ID','STUDENT_NAME','RESPONSE_ID');
 eq('Q11 omits student identifiers',v_n,0);

 -- 권한·중복·점수/문항 형식·완료조건 오류를 확인한다.
 BEGIN
  satisfaction_workflow.open_result(101,1,v_cursor);
  CLOSE v_cursor;
  v_code:=0;
 EXCEPTION WHEN OTHERS THEN v_code:=SQLCODE;
 END;
 eq('student cannot read admin results',v_code,-20051);
 error_is('student cannot submit for another student',
  'DECLARE v NUMBER; BEGIN satisfaction_workflow.start_response(101,2,1,v); END;',-20051);
 error_is('duplicate student survey response',
  'INSERT INTO survey_response(survey_id,student_id) VALUES(1,1)',-1);

 SELECT question_id INTO v_question FROM survey_question WHERE survey_id=1 AND question_order=1;
 SELECT question_id INTO v_question2 FROM survey_question WHERE survey_id=1 AND question_order=2;
 SELECT response_id INTO v_response FROM survey_response WHERE survey_id=1 AND student_id=4;
 error_is('database rejects empty answer',
  'INSERT INTO survey_response_detail(response_id,survey_id,question_id,score,answer_text) VALUES('||v_response||',1,'||v_question2||',NULL,NULL)',-2290);
 error_is('database rejects blank text answer',
  'INSERT INTO survey_response_detail(response_id,survey_id,question_id,score,answer_text) VALUES('||v_response||',1,'||v_question2||',NULL,''   '')',-2290);
 error_is('out of range satisfaction score',
  'DECLARE v NUMBER; BEGIN satisfaction_workflow.answer_question(104,'||v_response||','||v_question||',6,NULL); END;',-20058);
 error_is('required questions prevent completion',
  'BEGIN satisfaction_workflow.complete_response(104,'||v_response||'); END;',-20059);

 -- 응답 데이터와 공통 로그의 원자성: 로그 실패 후 응답은 IN_PROGRESS에 남는다.
 SAVEPOINT satisfaction_log_rollback;
 SELECT question_id INTO v_question FROM survey_question WHERE survey_id=1 AND question_order=2;
 satisfaction_workflow.answer_question(104,v_response,v_question,3,NULL);
 SELECT question_id INTO v_question FROM survey_question WHERE survey_id=1 AND question_order=1;
 satisfaction_workflow.answer_question(104,v_response,v_question,4,NULL);
 SELECT COUNT(*) INTO v_n FROM survey_response_detail_history h
  JOIN survey_response_detail d ON d.detail_id=h.detail_id
  WHERE d.response_id=v_response AND d.question_id=v_question AND h.changed_by=104
   AND h.old_score=3 AND h.new_score=4;
 eq('answer edit history records old and new value',v_n,1);
 SELECT COUNT(*) INTO v_n FROM change_log WHERE target_type='SURVEY_RESPONSE_DETAIL'
  AND action_type='UPDATE' AND actor_user_id=104;
 eq('answer edit writes common change log',v_n,1);
 SELECT question_id INTO v_question FROM survey_question WHERE survey_id=1 AND question_order=3;
 satisfaction_workflow.answer_question(104,v_response,v_question,NULL,'검증용 의견');
 v_code:=0;
 BEGIN
  satisfaction_workflow.complete_response(104,v_response);
 EXCEPTION WHEN OTHERS THEN v_code:=SQLCODE;
 END;
 eq('satisfaction log failure returned',v_code,-20999);
 SELECT response_status INTO v_status FROM survey_response WHERE response_id=v_response;
 IF v_status<>'IN_PROGRESS' THEN RAISE_APPLICATION_ERROR(-20821,'Response was not rolled back'); END IF;
 DBMS_OUTPUT.PUT_LINE('PASS | satisfaction response status rolled back');
 SELECT COUNT(*) INTO v_n FROM change_log
  WHERE target_type='SURVEY_RESPONSE' AND target_id=v_response AND action_type='COMPLETE';
 eq('satisfaction completion log rolled back',v_n,0);
 SAVEPOINT satisfaction_closed_survey;
 UPDATE satisfaction_survey SET survey_status='CLOSED' WHERE survey_id=1;
 error_is('in-progress answer cannot change after survey closes',
  'BEGIN satisfaction_workflow.answer_question(104,'||v_response||','||v_question||',2,NULL); END;',-20057);
 error_is('in-progress response cannot submit after survey closes',
  'BEGIN satisfaction_workflow.complete_response(104,'||v_response||'); END;',-20057);
 ROLLBACK TO satisfaction_closed_survey;
 ROLLBACK TO satisfaction_log_rollback;
 DBMS_OUTPUT.PUT_LINE('SATISFACTION TESTS PASSED');
EXCEPTION WHEN OTHERS THEN ROLLBACK; RAISE;
END;
/
DROP TRIGGER test_fail_satisfaction_log;
