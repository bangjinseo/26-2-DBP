# 예산 수입·지출 조회 API

`sql/08_budget_cashflow_migration.sql`을 적용한 Oracle 스키마의
`V_BUDGET_CASH_SUMMARY`, `V_BUDGET_TRANSACTION`을 읽는 전용 API임.

## 실행

```bash
cd api
npm install
DB_USER=계정 \
DB_PASSWORD=비밀번호 \
DB_CONNECT_STRING=localhost:1521/FREEPDB1 \
CORS_ORIGIN=http://127.0.0.1:43127 \
npm start
```

비밀번호는 파일이나 Git에 저장하지 않음.

## 엔드포인트

```text
GET /health
GET /api/budget/items?projectId=1
GET /api/budget/items/1/transactions?type=ALL&status=ALL&from=2026-11-01&to=2026-11-30&q=강사
```

`type`, `status`, 기간, 검색어는 동시에 적용됨. API는 데이터를 변경하지 않으며,
수입 등록·입금 처리·실제 지급 처리는 `BUDGET_CASHFLOW_WORKFLOW` 패키지를 사용함.

