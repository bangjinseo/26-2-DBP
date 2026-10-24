-- 시드 직후의 별도 실습 연결에서 F5 실행. 모든 변경은 끝에서 롤백.
SET SERVEROUTPUT ON
ALTER SESSION SET TIME_ZONE = '+09:00';
-- 1. 학생5 마일리지 승인 전 0, 승인 후100, 회수 후0.
SELECT * FROM v_student_mileage WHERE student_id=5;
DECLARE v_id NUMBER;
BEGIN
 SELECT application_id INTO v_id FROM mileage_application WHERE student_id=5 AND standard_id=1;
 pbl_workflow.process_mileage(1,v_id,'APPROVED','승인 전후 시연');
END;
/
SELECT * FROM v_student_mileage WHERE student_id=5;
DECLARE v_id NUMBER;
BEGIN
 SELECT application_id INTO v_id FROM mileage_application WHERE student_id=5 AND standard_id=1;
 pbl_workflow.process_mileage(1,v_id,'REVOKED','전액 회수 시연');
END;
/
SELECT * FROM v_student_mileage WHERE student_id=5;
ROLLBACK;
-- 2. 연구활동비 지출 승인 전10만원, 승인 후15만원, 취소 후10만원.
SELECT * FROM v_budget_summary WHERE project_budget_id=4;
DECLARE v_id NUMBER;
BEGIN
 SELECT expense_id INTO v_id FROM expense WHERE project_budget_id=4 AND expense_amount=50000;
 pbl_workflow.process_expense(1,v_id,'APPROVED','지출 승인 시연');
END;
/
SELECT * FROM v_budget_summary WHERE project_budget_id=4;
DECLARE v_id NUMBER;
BEGIN
 SELECT expense_id INTO v_id FROM expense WHERE project_budget_id=4 AND expense_amount=50000;
 pbl_workflow.process_expense(1,v_id,'CANCELLED','지출 취소 시연');
END;
/
SELECT * FROM v_budget_summary WHERE project_budget_id=4;
ROLLBACK;
-- 실제 업무에서 변경을 확정하려면 성공 후 COMMIT을 명시한다.
