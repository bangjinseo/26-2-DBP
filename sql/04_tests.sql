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
DROP TRIGGER test_fail_log;
