SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK

DECLARE
 v_budget NUMBER;
 v_expense NUMBER;
 v_income NUMBER;
 v_count NUMBER;
 v_income_total NUMBER;
 v_paid_total NUMBER;
 v_cash NUMBER;

 PROCEDURE assert_number(p_name VARCHAR2,p_actual NUMBER,p_expected NUMBER) IS
 BEGIN
  IF NVL(p_actual,-999999999)<>NVL(p_expected,-999999999) THEN
   RAISE_APPLICATION_ERROR(-20830,p_name||': expected='||p_expected||', actual='||p_actual);
  END IF;
  DBMS_OUTPUT.PUT_LINE('PASS | '||p_name||' | expected='||p_expected||' actual='||p_actual);
 END;
BEGIN
 SAVEPOINT cashflow_test;

 SELECT project_budget_id INTO v_budget
 FROM project_budget
 WHERE status='CONFIRMED'
   AND EXISTS(
    SELECT 1 FROM expense e
    WHERE e.project_budget_id=project_budget.project_budget_id
      AND e.status='APPROVED'
   )
   AND ROWNUM=1;

 budget_cashflow_workflow.register_income(
  1,v_budget,DATE '2026-11-18',100000,'TEST','rollback-only cashflow test',v_income
 );
 budget_cashflow_workflow.process_income(1,v_income,'RECEIVED','test receipt');

 SELECT expense_id INTO v_expense
 FROM expense
 WHERE project_budget_id=v_budget AND status='APPROVED' AND ROWNUM=1;

 budget_cashflow_workflow.update_expense_payment(
  1,v_expense,'PAID','TEST-REFERENCE','test payment'
 );

 SELECT total_income,actual_paid,actual_cash_balance
 INTO v_income_total,v_paid_total,v_cash
 FROM v_budget_cash_summary
 WHERE project_budget_id=v_budget;

 assert_number('income aggregation',v_income_total,100000);
 SELECT expense_amount INTO v_count FROM expense WHERE expense_id=v_expense;
 assert_number('paid aggregation',v_paid_total,v_count);
 assert_number('cash balance',v_cash,100000-v_count);

 SELECT COUNT(*) INTO v_count
 FROM v_budget_transaction
 WHERE project_budget_id=v_budget
   AND transaction_id IN ('INC-'||v_income,'EXP-'||v_expense);
 assert_number('unified transaction rows',v_count,2);

 ROLLBACK TO cashflow_test;
 DBMS_OUTPUT.PUT_LINE('ALL BUDGET CASHFLOW TESTS PASSED');
END;
/

SELECT COUNT(*) AS persisted_test_income
FROM income
WHERE income_description='rollback-only cashflow test';

