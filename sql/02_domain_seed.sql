-- 마일리지·예산 담당 정상 데이터. 공통 데이터 입력 후 1회 실행.
INSERT INTO mileage_standard VALUES(1,1,'PARTICIPATION',100);
INSERT INTO mileage_standard VALUES(2,1,'AWARD',300);
INSERT INTO mileage_standard VALUES(3,2,'PARTICIPATION',50);
INSERT INTO mileage_standard VALUES(4,2,'AWARD',150);
INSERT INTO mileage_standard VALUES(5,3,'PARTICIPATION',80);
INSERT INTO mileage_standard VALUES(6,3,'AWARD',200);
DECLARE
 v_id NUMBER;
 PROCEDURE add_app(p_student NUMBER,p_standard NUMBER,p_status VARCHAR2) IS
 BEGIN
  pbl_workflow.submit_mileage(100+p_student,p_student,p_standard,v_id);
  UPDATE mileage_application SET applied_at=TIMESTAMP '2026-10-15 09:00:00' WHERE application_id=v_id;
  INSERT INTO attachment_file(application_id,file_name,storage_path)
   VALUES(v_id,'demo_'||v_id||'.pdf','/virtual/evidence/demo_'||v_id||'.pdf');
  IF p_status<>'PENDING' THEN
   pbl_workflow.process_mileage(1,v_id,CASE WHEN p_status='REVOKED' THEN 'APPROVED' ELSE p_status END,'가상 검토 결과');
   UPDATE mileage_application SET approved_at=TIMESTAMP '2026-10-20 10:00:00'
    WHERE application_id=v_id AND status='APPROVED';
   UPDATE mileage_accrual SET earned_at=TIMESTAMP '2026-10-20 10:00:00' WHERE application_id=v_id;
   IF p_status='REVOKED' THEN pbl_workflow.process_mileage(1,v_id,'REVOKED','증빙 무효에 따른 전액 회수'); END IF;
  END IF;
 END;
BEGIN
 add_app(1,1,'APPROVED'); add_app(1,2,'APPROVED'); add_app(2,3,'APPROVED');
 add_app(3,5,'APPROVED'); add_app(4,6,'APPROVED'); add_app(5,1,'PENDING');
 add_app(6,3,'REJECTED'); add_app(7,5,'CANCELLED'); add_app(8,2,'REVOKED');
 add_app(9,3,'PENDING'); add_app(2,5,'APPROVED'); add_app(3,1,'REJECTED');
 -- 첨부가 두 개인 신청: Q07 JOIN 시 신청/금액 중복 집계를 방지하는 사례.
 INSERT INTO attachment_file(application_id,file_name,storage_path)
 SELECT application_id,'extra_demo.pdf','/virtual/evidence/extra_demo.pdf'
 FROM mileage_application WHERE student_id=5 AND standard_id=1;
END;
/
INSERT INTO budget_project VALUES(1,2026,1,'가상 SW중심대학사업',DATE '2026-01-01',DATE '2026-12-31','ACTIVE');
INSERT INTO budget_item VALUES(1,'PERSONNEL','인건비','Y');
INSERT INTO budget_item VALUES(2,'STUDENT_LABOR','학생인건비','Y');
INSERT INTO budget_item VALUES(3,'EQUIPMENT','연구장비시설비','Y');
INSERT INTO budget_item VALUES(4,'ACTIVITY','연구활동비','Y');
INSERT INTO budget_item VALUES(5,'MATERIAL','연구재료비','Y');
INSERT INTO budget_item VALUES(6,'ALLOWANCE','연구수당','Y');
INSERT INTO budget_item VALUES(7,'INDIRECT','간접비','Y');
INSERT INTO project_budget(project_budget_id,project_id,budget_item_id,initial_amount,current_amount,spending_limit,input_user_id)
 VALUES(1,1,1,1000000,1000000,1000000,1);
INSERT INTO project_budget(project_budget_id,project_id,budget_item_id,initial_amount,current_amount,spending_limit,input_user_id)
 VALUES(2,1,2,2000000,2000000,2000000,1);
INSERT INTO project_budget(project_budget_id,project_id,budget_item_id,initial_amount,current_amount,spending_limit,input_user_id)
 VALUES(3,1,3,1500000,1500000,1500000,1);
INSERT INTO project_budget(project_budget_id,project_id,budget_item_id,initial_amount,current_amount,spending_limit,input_user_id)
 VALUES(4,1,4,1000000,1000000,800000,1);
INSERT INTO project_budget(project_budget_id,project_id,budget_item_id,initial_amount,current_amount,spending_limit,input_user_id)
 VALUES(5,1,5,500000,500000,500000,1);
INSERT INTO project_budget(project_budget_id,project_id,budget_item_id,initial_amount,current_amount,spending_limit,input_user_id)
 VALUES(6,1,6,300000,300000,300000,1);
INSERT INTO project_budget(project_budget_id,project_id,budget_item_id,initial_amount,current_amount,spending_limit,input_user_id)
 VALUES(7,1,7,0,0,0,1);
INSERT INTO expense_subject VALUES(1,'산학협력','Y');
INSERT INTO expense_subject VALUES(2,'전공','Y');
INSERT INTO expense_subject VALUES(3,'융합','Y');
DECLARE
 v_id NUMBER;
 PROCEDURE add_exp(p_budget NUMBER,p_prof NUMBER,p_subject NUMBER,p_amount NUMBER,p_status VARCHAR2) IS
 BEGIN
  pbl_workflow.submit_expense(2,p_budget,p_prof,p_subject,DATE '2026-10-18','가상 지출 증빙',p_amount,v_id);
  IF p_status<>'PENDING' THEN
   pbl_workflow.process_expense(1,v_id,CASE WHEN p_status='CANCELLED' THEN 'APPROVED' ELSE p_status END,'가상 지출 검토');
   IF p_status='CANCELLED' THEN pbl_workflow.process_expense(1,v_id,'CANCELLED','가상 지출 취소'); END IF;
  END IF;
 END;
BEGIN
 add_exp(1,1,1,200000,'APPROVED'); add_exp(1,2,2,100000,'APPROVED');
 add_exp(2,1,2,400000,'APPROVED'); add_exp(2,3,3,200000,'APPROVED');
 add_exp(3,2,1,500000,'APPROVED'); add_exp(4,3,3,100000,'APPROVED');
 add_exp(4,1,2,50000,'PENDING'); add_exp(5,2,1,80000,'REJECTED');
 add_exp(6,3,3,30000,'PENDING'); add_exp(3,1,1,100000,'CANCELLED');
 add_exp(5,1,2,20000,'PENDING'); add_exp(4,2,1,700000,'PENDING');
 -- 연구활동비의 현재예산만 110만원으로 조정. 최초 100만원은 보존, 한도는 80만원.
 pbl_workflow.change_budget(1,4,1100000,800000,'가상 예산 증액 확정');
END;
/
COMMIT;
