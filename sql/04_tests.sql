-- 02_seed.sql 직후 실행. 자동 검증이며 정상 데이터를 남긴 채 각 테스트를 롤백한다.
-- 의도한 오류는 블록 내부에서 SQLCODE를 검사한다. 예상과 다르면 스크립트 실패.
-- 전용 실습 스키마에서만 실행: 로그 실패 재현용 트리거를 잠시 생성/삭제한다.
SET SERVEROUTPUT ON
CREATE OR REPLACE TRIGGER test_fail_log
BEFORE INSERT ON change_log FOR EACH ROW
BEGIN
 IF :NEW.reason='TEST_FAIL_LOG' THEN RAISE_APPLICATION_ERROR(-20999,'Injected log failure'); END IF;
END;
/
DECLARE
 v_id NUMBER; v_exp NUMBER; v_n NUMBER; v_before NUMBER; v_after NUMBER;
 v_app_pending NUMBER; v_app_approved NUMBER; v_exp_pending NUMBER;
 PROCEDURE eq(p_name VARCHAR2,p_actual NUMBER,p_expected NUMBER) IS
 BEGIN
  IF p_actual IS NULL OR p_actual<>p_expected THEN
   RAISE_APPLICATION_ERROR(-20800,p_name||': expected='||p_expected||',actual='||p_actual);
  END IF;
  DBMS_OUTPUT.PUT_LINE('PASS | '||p_name||' | expected='||p_expected||' actual='||p_actual);
 END;
 PROCEDURE error_is(p_name VARCHAR2,p_sql VARCHAR2,p_code NUMBER,p_preserve_error_state BOOLEAN DEFAULT FALSE) IS
  v_code NUMBER:=0;
 BEGIN
  SAVEPOINT expected_error;
  BEGIN EXECUTE IMMEDIATE p_sql;
  EXCEPTION WHEN OTHERS THEN v_code:=SQLCODE;
  END;
  -- 내부 롤백 검증 시 여기서 롤백하지 않는다. 프로시저가 복구한 직후 상태를 검사한다.
  IF NOT p_preserve_error_state THEN ROLLBACK TO expected_error; END IF;
  eq(p_name,v_code,p_code);
 END;
BEGIN
 SELECT application_id INTO v_app_pending FROM mileage_application WHERE student_id=5 AND standard_id=1;
 SELECT application_id INTO v_app_approved FROM mileage_application WHERE student_id=1 AND standard_id=1;
 SELECT expense_id INTO v_exp_pending FROM expense WHERE project_budget_id=4 AND expense_amount=50000;
 -- 수작업 예상값: 100+300+50+80+200+80=810.
 SELECT SUM(total_mileage) INTO v_n FROM v_student_mileage; eq('Q05 total',v_n,810);
 SELECT total_mileage INTO v_n FROM v_student_mileage WHERE student_id=1; eq('Q05 student1',v_n,400);
 SELECT total_mileage INTO v_n FROM v_student_mileage WHERE student_id=10; eq('Q05 no application',v_n,0);
 SELECT total_mileage INTO v_n FROM v_student_mileage WHERE student_id=8; eq('Q05 revoked excluded',v_n,0);
 SELECT COUNT(*) INTO v_n FROM v_student_mileage WHERE total_mileage=0; eq('Q05 zero students',v_n,6);
 SELECT SUM(c.earned_mileage) INTO v_n FROM mileage_accrual c JOIN mileage_application a ON a.application_id=c.application_id
 JOIN mileage_standard ms ON ms.standard_id=a.standard_id
 WHERE a.status='APPROVED' AND c.status='ACTIVE' AND ms.program_id=1
 AND a.approved_at>=TIMESTAMP '2026-10-01 00:00:00' AND a.approved_at<TIMESTAMP '2026-11-01 00:00:00';
 eq('Q06 program1',v_n,400);
 SELECT COUNT(*) INTO v_n FROM mileage_application WHERE status='PENDING'; eq('Q07 pending applications',v_n,2);
 SELECT COUNT(*) INTO v_n FROM attachment_file WHERE application_id=v_app_pending; eq('Q07 multiple evidence',v_n,2);
 SELECT COUNT(*) INTO v_n FROM v_budget_summary; eq('Q08 seven items',v_n,7);
 SELECT SUM(approved_expense) INTO v_n FROM v_budget_summary; eq('Q08 approved total',v_n,1500000);
 SELECT balance INTO v_n FROM v_budget_summary WHERE project_budget_id=5; eq('Q08 no approved expense balance',v_n,500000);
 SELECT execution_rate INTO v_n FROM v_budget_summary WHERE project_budget_id=7; eq('Q08 zero budget',v_n,0);
 SELECT balance INTO v_n FROM v_budget_summary WHERE project_budget_id=4; eq('Q08 amended budget balance',v_n,1000000);
 SELECT execution_rate INTO v_n FROM v_budget_summary WHERE project_budget_id=4; eq('Q08 amended budget rate',v_n,9.09);
 SELECT SUM(expense_amount) INTO v_n FROM expense WHERE professor_id=1 AND status='APPROVED'; eq('Q09 professor1',v_n,600000);
 SELECT SUM(expense_amount) INTO v_n FROM expense WHERE expense_subject_id=1 AND status='APPROVED'; eq('Q09 industry',v_n,700000);
 error_is('duplicate student number',q'[UPDATE student SET student_no='DEMO2026001' WHERE student_id=2]',-1);
 error_is('duplicate login',q'[UPDATE user_account SET login_id='master_demo' WHERE user_id=2]',-1);
 error_is('missing program FK',q'[INSERT INTO mileage_standard VALUES(99,999,'PARTICIPATION',10)]',-2291);
 error_is('missing student FK',q'[INSERT INTO mileage_application(student_id,standard_id,applied_mileage) VALUES(999,1,100)]',-2291);
 error_is('negative mileage',q'[INSERT INTO mileage_standard VALUES(99,1,'AWARD',-1)]',-2290);
 error_is('duplicate mileage application',q'[INSERT INTO mileage_application(student_id,standard_id,applied_mileage) VALUES(1,1,100)]',-1);
 error_is('duplicate accrual','INSERT INTO mileage_accrual(application_id,earned_mileage) VALUES('||v_app_approved||',100)',-1);
 error_is('zero expense',q'[INSERT INTO expense(project_budget_id,professor_id,expense_subject_id,input_user_id,expense_date,detail_item,expense_amount) VALUES(1,1,1,2,DATE '2026-10-20','bad',0)]',-2290);
 error_is('negative expense',q'[INSERT INTO expense(project_budget_id,professor_id,expense_subject_id,input_user_id,expense_date,detail_item,expense_amount) VALUES(1,1,1,2,DATE '2026-10-20','bad',-1)]',-2290);
 error_is('unknown state','UPDATE mileage_application SET status=''UNKNOWN'' WHERE application_id='||v_app_pending,-2290);
 error_is('admin cannot approve','BEGIN pbl_workflow.process_mileage(2,'||v_app_pending||',''APPROVED'',''test''); END;',-20001);
 error_is('student cannot approve','BEGIN pbl_workflow.process_mileage(105,'||v_app_pending||',''APPROVED'',''test''); END;',-20001);
 error_is('repeat mileage approval','BEGIN pbl_workflow.process_mileage(1,'||v_app_approved||',''APPROVED'',''test''); END;',-20002);
 error_is('null state transition','BEGIN pbl_workflow.process_mileage(1,'||v_app_pending||',NULL,''test''); END;',-20002);
 error_is('own submission required',q'[DECLARE v NUMBER; BEGIN pbl_workflow.submit_mileage(101,10,1,v); END;]',-20001);
 -- 정상 승인 전후와 전액 회수. 신청/적립/로그가 함께 생성됨을 확인.
 SAVEPOINT case_mileage;
 pbl_workflow.process_mileage(1,v_app_pending,'APPROVED','test approve');
 SELECT total_mileage INTO v_n FROM v_student_mileage WHERE student_id=5; eq('approve adds 100',v_n,100);
 SELECT COUNT(*) INTO v_n FROM mileage_process_history WHERE application_id=v_app_pending; eq('approval history',v_n,1);
 pbl_workflow.process_mileage(1,v_app_pending,'REVOKED','test revoke');
 SELECT total_mileage INTO v_n FROM v_student_mileage WHERE student_id=5; eq('revoke removes 100',v_n,0);
 ROLLBACK TO case_mileage;
 SAVEPOINT case_reject;
 pbl_workflow.process_mileage(1,v_app_pending,'REJECTED','test reject');
 SELECT COUNT(*) INTO v_n FROM mileage_accrual WHERE application_id=v_app_pending; eq('reject creates no accrual',v_n,0);
 ROLLBACK TO case_reject;
 -- 금액 기준이 바뀌어도 신청 당시 값 유지.
 SAVEPOINT case_snapshot;
 UPDATE mileage_standard SET grant_mileage=999 WHERE standard_id=1;
 pbl_workflow.process_mileage(1,v_app_pending,'APPROVED','snapshot test');
 SELECT earned_mileage INTO v_n FROM mileage_accrual WHERE application_id=v_app_pending; eq('application snapshot',v_n,100);
 ROLLBACK TO case_snapshot;
 -- 상한 경계: 기존 100000 + 700000 = 한도800000 승인 허용, 이후50000 추가는 거부.
 SAVEPOINT case_limit;
 SELECT expense_id INTO v_exp FROM expense WHERE project_budget_id=4 AND expense_amount=700000;
 pbl_workflow.process_expense(1,v_exp,'APPROVED','exact limit');
 SELECT available_limit INTO v_n FROM v_budget_summary WHERE project_budget_id=4; eq('exact limit allowed',v_n,0);
 error_is('over limit rejected','BEGIN pbl_workflow.process_expense(1,'||v_exp_pending||',''APPROVED'',''test''); END;',-20003);
 error_is('repeat expense approval','BEGIN pbl_workflow.process_expense(1,'||v_exp||',''APPROVED'',''test''); END;',-20002);
 SELECT COUNT(*) INTO v_n FROM expense WHERE expense_id=v_exp_pending AND status='PENDING'; eq('over limit stays pending',v_n,1);
 ROLLBACK TO case_limit;
 SAVEPOINT case_cancel;
 pbl_workflow.process_expense(1,v_exp_pending,'APPROVED','test approve');
 SELECT approved_expense INTO v_n FROM v_budget_summary WHERE project_budget_id=4; eq('expense approval adds',v_n,150000);
 pbl_workflow.process_expense(1,v_exp_pending,'CANCELLED','test cancel');
 SELECT approved_expense INTO v_n FROM v_budget_summary WHERE project_budget_id=4; eq('expense cancellation removes',v_n,100000);
 ROLLBACK TO case_cancel;
 error_is('limit below approved sum',q'[BEGIN pbl_workflow.change_budget(1,1,1000000,299999,'test'); END;]',-20003);
 error_is('limit above budget',q'[BEGIN pbl_workflow.change_budget(1,1,1000000,1000001,'test'); END;]',-20007);
 error_is('admin cannot change budget',q'[BEGIN pbl_workflow.change_budget(2,1,1000000,1000000,'test'); END;]',-20001);
 -- 강제 로그 실패: 상태/적립/처리이력/로그 전부 부분 반영 없이 복구되는지 확인.
 SELECT COUNT(*) INTO v_before FROM change_log;
 error_is('mileage log failure','BEGIN pbl_workflow.process_mileage(1,'||v_app_pending||',''APPROVED'',''TEST_FAIL_LOG''); END;',-20999,TRUE);
 SELECT COUNT(*) INTO v_n FROM mileage_application WHERE application_id=v_app_pending AND status='PENDING'; eq('rollback mileage status',v_n,1);
 SELECT COUNT(*) INTO v_n FROM mileage_accrual WHERE application_id=v_app_pending; eq('rollback mileage accrual',v_n,0);
 SELECT COUNT(*) INTO v_n FROM mileage_process_history WHERE application_id=v_app_pending; eq('rollback mileage history',v_n,0);
 error_is('expense log failure','BEGIN pbl_workflow.process_expense(1,'||v_exp_pending||',''APPROVED'',''TEST_FAIL_LOG''); END;',-20999,TRUE);
 SELECT COUNT(*) INTO v_n FROM expense WHERE expense_id=v_exp_pending AND status='PENDING'; eq('rollback expense status',v_n,1);
 SELECT COUNT(*) INTO v_n FROM expense_process_history WHERE expense_id=v_exp_pending; eq('rollback expense history',v_n,0);
 error_is('budget log failure',q'[BEGIN pbl_workflow.change_budget(1,1,1200000,1100000,'TEST_FAIL_LOG'); END;]',-20999,TRUE);
 SELECT current_amount INTO v_n FROM project_budget WHERE project_budget_id=1; eq('rollback budget amount',v_n,1000000);
 SELECT COUNT(*) INTO v_n FROM budget_change_history WHERE project_budget_id=1; eq('rollback budget history',v_n,0);
 SELECT COUNT(*) INTO v_after FROM change_log; eq('rollback log count unchanged',v_after,v_before);
 -- 승인/적립 구조 불일치 탐지: 0건이어야 함.
 SELECT COUNT(*) INTO v_n FROM mileage_application a LEFT JOIN mileage_accrual c ON c.application_id=a.application_id
 WHERE (a.status='APPROVED' AND (c.accrual_id IS NULL OR c.status<>'ACTIVE'))
 OR (a.status='REVOKED' AND (c.accrual_id IS NULL OR c.status<>'REVOKED'))
 OR (a.status IN ('PENDING','REJECTED','CANCELLED') AND c.accrual_id IS NOT NULL);
 eq('accrual consistency',v_n,0);
 ROLLBACK;
 DBMS_OUTPUT.PUT_LINE('ALL TESTS PASSED');
EXCEPTION WHEN OTHERS THEN ROLLBACK; RAISE;
END;
/

-- BEGIN STUDENT_AND_TOPCIT
DECLARE
 v_n NUMBER;
 v_before NUMBER;
 v_after NUMBER;
 v_score_id NUMBER;
 v_request_id NUMBER;
 v_text VARCHAR2(4000);
 v_rc SYS_REFCURSOR;

 PROCEDURE eq(p_name VARCHAR2,p_actual NUMBER,p_expected NUMBER) IS
 BEGIN
  IF p_actual IS NULL OR p_actual<>p_expected THEN
   RAISE_APPLICATION_ERROR(-20810,p_name||': expected='||p_expected||',actual='||p_actual);
  END IF;
  DBMS_OUTPUT.PUT_LINE('PASS | '||p_name||' | expected='||p_expected||' actual='||p_actual);
 END;

 PROCEDURE text_eq(p_name VARCHAR2,p_actual VARCHAR2,p_expected VARCHAR2) IS
 BEGIN
  IF NVL(p_actual,CHR(0))<>NVL(p_expected,CHR(0)) THEN
   RAISE_APPLICATION_ERROR(-20811,p_name||': expected='||p_expected||',actual='||p_actual);
  END IF;
  DBMS_OUTPUT.PUT_LINE('PASS | '||p_name||' | expected='||p_expected||' actual='||p_actual);
 END;

 PROCEDURE error_is(p_name VARCHAR2,p_sql VARCHAR2,p_code NUMBER,p_preserve BOOLEAN DEFAULT FALSE) IS
  v_code NUMBER:=0;
 BEGIN
  SAVEPOINT expected_student_topcit_error;
  BEGIN EXECUTE IMMEDIATE p_sql;
  EXCEPTION WHEN OTHERS THEN v_code:=SQLCODE;
  END;
  IF NOT p_preserve THEN ROLLBACK TO expected_student_topcit_error; END IF;
  eq(p_name,v_code,p_code);
 END;

 PROCEDURE access_error_is(p_name VARCHAR2,p_actor NUMBER,p_student NUMBER,p_code NUMBER) IS
  v_code NUMBER:=0;
  v_cursor SYS_REFCURSOR;
 BEGIN
  BEGIN
   student_topcit_workflow.open_student_profile(p_actor,p_student,v_cursor);
   CLOSE v_cursor;
  EXCEPTION WHEN OTHERS THEN v_code:=SQLCODE;
  END;
  eq(p_name,v_code,p_code);
 END;
BEGIN
 -- 최소 정상 데이터 규모와 역할·권한 데이터.
 SELECT COUNT(*) INTO v_n FROM role; eq('three roles',v_n,3);
 SELECT COUNT(*) INTO v_n FROM role_permission WHERE role_id=1; eq('student permissions',v_n,4);
 SELECT COUNT(*) INTO v_n FROM student; eq('ten students',v_n,10);
 SELECT COUNT(DISTINCT department_id) INTO v_n FROM student; eq('two departments',v_n,2);
 SELECT COUNT(DISTINCT grade) INTO v_n FROM student; eq('two grades',v_n,2);
 SELECT COUNT(*) INTO v_n FROM student_change_request; eq('five change requests',v_n,5);
 SELECT COUNT(*) INTO v_n FROM student_change_request WHERE request_status='APPROVED'; eq('approved requests',v_n,2);
 SELECT COUNT(*) INTO v_n FROM student_change_request WHERE request_status='REJECTED'; eq('rejected requests',v_n,2);
 SELECT COUNT(*) INTO v_n FROM student_change_request WHERE request_status='PENDING'; eq('pending requests',v_n,1);
 SELECT COUNT(*) INTO v_n FROM topcit_round; eq('two TOPCIT rounds',v_n,2);
 SELECT COUNT(*) INTO v_n FROM topcit_score; eq('fifteen TOPCIT scores',v_n,15);

 -- Q01과 접근 범위: 학생 본인, 일반관리자, 마스터 허용. 다른 학생은 차단.
 student_topcit_workflow.open_student_profile(101,1,v_rc); CLOSE v_rc;
 eq('Q01 own profile allowed',1,1);
 student_topcit_workflow.open_student_profile(2,1,v_rc); CLOSE v_rc;
 eq('Q01 admin profile allowed',1,1);
 student_topcit_workflow.open_student_profile(1,1,v_rc); CLOSE v_rc;
 eq('Q01 master profile allowed',1,1);
 access_error_is('Q01 other student blocked',101,2,-20001);
 SELECT COUNT(*) INTO v_n FROM v_student_profile WHERE student_id=1 AND mobile_phone='010-1111-0001';
 eq('Q01 expected current phone',v_n,1);

 -- DB가 직접 강제하는 PK/FK/UNIQUE/CHECK 검증.
 SELECT COUNT(*) INTO v_before FROM student;
 SAVEPOINT duplicate_student_number_case;
 INSERT INTO user_account(user_id,role_id,login_id,password_info,user_type)
 VALUES(9991,1,'duplicate_student_no_case','hash','STUDENT');
 error_is('duplicate student number rejected',
  q'[INSERT INTO student(student_id,user_id,department_id,status_code,admission_type_code,student_no,student_name,grade,admission_date,sms_yn) VALUES(9991,9991,10,'ENROLLED','FRESHMAN','DEMO2026001','duplicate student',1,DATE '2026-03-02','N')]',-1);
 SELECT COUNT(*) INTO v_after FROM student;
 eq('duplicate student failure keeps existing data',v_after,v_before);
 ROLLBACK TO duplicate_student_number_case;
 error_is('duplicate login rejected',
  q'[INSERT INTO user_account(user_id,role_id,login_id,password_info,user_type) VALUES(9991,1,'student_demo_1','hash','STUDENT')]',-1);
 SELECT COUNT(*) INTO v_after FROM user_account;
 eq('duplicate login failure keeps existing data',v_after,12);
 error_is('missing role rejected',
  q'[INSERT INTO user_account(user_id,role_id,login_id,password_info,user_type) VALUES(9991,999,'invalid_role','hash','STUDENT')]',-2291);
 error_is('missing department rejected',q'[UPDATE student SET department_id=999 WHERE student_id=1]',-2291);
 error_is('missing TOPCIT student rejected',
  q'[INSERT INTO topcit_score(student_id,round_id,total_score,created_by) VALUES(999,1,500,2)]',-2291);
 error_is('missing TOPCIT round rejected',
  q'[INSERT INTO topcit_score(student_id,round_id,total_score,created_by) VALUES(9,999,500,2)]',-2291);
 SELECT COUNT(*) INTO v_before FROM topcit_score;
 error_is('duplicate student round rejected',
  q'[INSERT INTO topcit_score(student_id,round_id,total_score,created_by) VALUES(1,1,500,2)]',-1);
 SELECT COUNT(*) INTO v_after FROM topcit_score;
 eq('duplicate TOPCIT failure keeps existing data',v_after,v_before);
 error_is('TOPCIT below minimum rejected',
  q'[INSERT INTO topcit_score(student_id,round_id,total_score,created_by) VALUES(9,1,-1,2)]',-2290);
 error_is('TOPCIT above maximum rejected',
  q'[INSERT INTO topcit_score(student_id,round_id,total_score,created_by) VALUES(10,1,1001,2)]',-2290);

 SAVEPOINT topcit_boundary_cases;
 student_topcit_workflow.register_topcit_score(2,9,1,0,'minimum boundary',v_score_id);
 SELECT total_score INTO v_n FROM topcit_score WHERE score_id=v_score_id; eq('TOPCIT minimum accepted',v_n,0);
 ROLLBACK TO topcit_boundary_cases;
 SAVEPOINT topcit_boundary_cases_max;
 student_topcit_workflow.register_topcit_score(2,10,1,1000,'maximum boundary',v_score_id);
 SELECT total_score INTO v_n FROM topcit_score WHERE score_id=v_score_id; eq('TOPCIT maximum accepted',v_n,1000);
 ROLLBACK TO topcit_boundary_cases_max;

 -- Q02 및 학생정보 요청 승인·반려. 승인 전에는 기본정보가 바뀌지 않는다.
 SELECT email INTO v_text FROM student WHERE student_id=3;
 text_eq('pending request keeps base data',v_text,'student3@example.invalid');
 SELECT COUNT(*) INTO v_n
 FROM student_change_request r JOIN student_change_request_detail d ON d.request_id=r.request_id
 WHERE r.request_id=1 AND r.request_status='APPROVED'
  AND r.processor_id=2 AND r.processed_at IS NOT NULL AND r.process_comment IS NOT NULL;
 eq('Q02 approved request details',v_n,2);
 SAVEPOINT approve_student_request;
 student_topcit_workflow.process_student_change(2,3,'APPROVED','test approval');
 SELECT email INTO v_text FROM student WHERE student_id=3;
 text_eq('approval changes base data',v_text,'student3.pending@example.invalid');
 SELECT COUNT(*) INTO v_n FROM student_change_request
  WHERE request_id=3 AND request_status='APPROVED' AND processor_id=2 AND processed_at IS NOT NULL;
 eq('approval metadata',v_n,1);
 SELECT COUNT(*) INTO v_n FROM change_log
  WHERE target_type='STUDENT_CHANGE_REQUEST' AND target_id=3 AND action_type='APPROVE';
 eq('approval change log',v_n,1);
 ROLLBACK TO approve_student_request;

 SAVEPOINT reject_student_request;
 student_topcit_workflow.process_student_change(2,3,'REJECTED','test rejection');
 SELECT email INTO v_text FROM student WHERE student_id=3;
 text_eq('rejection keeps base data',v_text,'student3@example.invalid');
 SELECT COUNT(*) INTO v_n FROM student_change_request
  WHERE request_id=3 AND request_status='REJECTED' AND processor_id=2 AND process_comment='test rejection';
 eq('rejection metadata',v_n,1);
 SELECT COUNT(*) INTO v_n FROM change_log
  WHERE target_type='STUDENT_CHANGE_REQUEST' AND target_id=3 AND action_type='REJECT';
 eq('rejection change log',v_n,1);
 ROLLBACK TO reject_student_request;

 error_is('approved request cannot be processed again',
  q'[BEGIN student_topcit_workflow.process_student_change(2,1,'APPROVED','repeat'); END;]',-20011);
 error_is('rejected request cannot be processed again',
  q'[BEGIN student_topcit_workflow.process_student_change(2,2,'APPROVED','repeat'); END;]',-20011);

 -- Q03, Q04 및 TOPCIT 수정 로그.
 SELECT score_change INTO v_n FROM v_topcit_score_change WHERE student_id=1 AND round_id=2;
 eq('Q03 student1 score change',v_n,50);
 SELECT COUNT(*) INTO v_n FROM v_topcit_score_change WHERE student_id=1 AND round_id=1 AND previous_score IS NULL;
 eq('Q03 first previous score null',v_n,1);
 SELECT COUNT(*) INTO v_n FROM (
  SELECT s.department_id,s.grade,ROUND(AVG(ts.total_score),2) average_score,COUNT(*) examinee_count
  FROM topcit_score ts JOIN student s ON s.student_id=ts.student_id
  WHERE ts.round_id=1 GROUP BY s.department_id,s.grade
 ) WHERE department_id=10 AND grade=1 AND average_score=766.67 AND examinee_count=3;
 eq('Q04 expected average and count',v_n,1);

 SELECT score_id INTO v_score_id FROM topcit_score WHERE student_id=2 AND round_id=2;
 SAVEPOINT update_topcit_case;
 student_topcit_workflow.update_topcit_score(2,v_score_id,690,'test score correction');
 SELECT total_score INTO v_n FROM topcit_score WHERE score_id=v_score_id; eq('TOPCIT score updated',v_n,690);
 SELECT COUNT(*) INTO v_n FROM change_log
  WHERE target_type='TOPCIT_SCORE' AND target_id=v_score_id AND action_type='UPDATE'
   AND DBMS_LOB.SUBSTR(old_value,100,1)='680' AND DBMS_LOB.SUBSTR(new_value,100,1)='690';
 eq('TOPCIT update change log',v_n,1);
 ROLLBACK TO update_topcit_case;
 error_is('same TOPCIT score rejected',
  'BEGIN student_topcit_workflow.update_topcit_score(2,'||v_score_id||',680,''same score''); END;',-20014);

 -- Q12 시드 로그 건수: 학생 요청 5+처리 4, 회차 2, 점수 등록 15+수정 1.
 SELECT COUNT(*) INTO v_n FROM change_log WHERE target_type='STUDENT_CHANGE_REQUEST';
 eq('Q12 student request logs',v_n,9);
 SELECT COUNT(*) INTO v_n FROM change_log WHERE target_type='TOPCIT_ROUND';
 eq('Q12 TOPCIT round logs',v_n,2);
 SELECT COUNT(*) INTO v_n FROM change_log WHERE target_type='TOPCIT_SCORE';
 eq('Q12 TOPCIT score logs',v_n,16);

 -- 학생 승인 중 로그 실패를 주입하여 기본정보·상태·로그가 모두 롤백되는지 확인.
 SAVEPOINT student_log_failure_case;
 student_topcit_workflow.request_student_change(103,3,'010-3333-0003',NULL,NULL,v_request_id);
 SELECT COUNT(*) INTO v_before FROM change_log;
 error_is('student approval log failure',
  'BEGIN student_topcit_workflow.process_student_change(2,'||v_request_id||',''APPROVED'',''TEST_FAIL_LOG''); END;',-20999,TRUE);
 SELECT COUNT(*) INTO v_n FROM student WHERE student_id=3 AND mobile_phone='010-0000-0003';
 eq('rollback student base data',v_n,1);
 SELECT COUNT(*) INTO v_n FROM student_change_request WHERE request_id=v_request_id AND request_status='PENDING';
 eq('rollback student request state',v_n,1);
 SELECT COUNT(*) INTO v_after FROM change_log; eq('rollback student log count',v_after,v_before);
 ROLLBACK TO student_log_failure_case;

 -- TOPCIT 수정 중 로그 실패도 점수와 로그를 함께 복구한다.
 SELECT score_id INTO v_score_id FROM topcit_score WHERE student_id=2 AND round_id=2;
 SELECT COUNT(*) INTO v_before FROM change_log;
 error_is('TOPCIT update log failure',
  'BEGIN student_topcit_workflow.update_topcit_score(2,'||v_score_id||',690,''TEST_FAIL_LOG''); END;',-20999,TRUE);
 SELECT total_score INTO v_n FROM topcit_score WHERE score_id=v_score_id; eq('rollback TOPCIT score',v_n,680);
 SELECT COUNT(*) INTO v_after FROM change_log; eq('rollback TOPCIT log count',v_after,v_before);

 ROLLBACK;
 DBMS_OUTPUT.PUT_LINE('STUDENT/TOPCIT TESTS PASSED');
EXCEPTION WHEN OTHERS THEN ROLLBACK; RAISE;
END;
/
-- END STUDENT_AND_TOPCIT
DROP TRIGGER test_fail_log;
