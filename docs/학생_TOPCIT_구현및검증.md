# 학생 인적사항·TOPCIT 구현 및 검증

## 구현 범위

- 필수 15개 테이블 구조 반영함
- 기존 마일리지·예산이 참조하는 `PROGRAM`, `PROFESSOR`를 공통 fixture에 보존함
- 학생 수정 요청 승인·반려, 관리자 학적 변경, TOPCIT 등록·수정을 PL/SQL 패키지로 처리함
- 업무 데이터와 `CHANGE_LOG`를 한 트랜잭션으로 관리함

## 수작업 예상값

| 항목 | 예상값 | 검증 SQL |
|---|---|---|
| 학생 1 현재 휴대전화 | `010-1111-0001` | Q01, `04_tests.sql` |
| 수정 요청 상태 | 승인 2·반려 2·대기 1 | Q02, `04_tests.sql` |
| 학생 1 TOPCIT 변화 | 600→650, +50 | Q03, `04_tests.sql` |
| 학생 2 TOPCIT 변화 | 700→680, -20 | Q03 |
| 제1회 컴퓨터학과 1학년 | 3명, 평균 766.67 | Q04, `04_tests.sql` |
| 학생 수정 요청 로그 | 9건 | Q12, `04_tests.sql` |
| TOPCIT 회차 로그 | 2건 | Q12, `04_tests.sql` |
| TOPCIT 점수 로그 | 16건 | Q12, `04_tests.sql` |

## 필수 검증 시나리오 대응

| 범위 | 구현·검증 방식 |
|---|---|
| PK·FK·UNIQUE·CHECK | 오류 DML의 Oracle 오류 코드를 검증하고 SAVEPOINT로 복구함 |
| 중복 학번·로그인 ID | 등록 거부 후 기존 행 수가 같은지 검증함 |
| 수정 요청 | 승인 전·반려 후 기본정보 유지, 승인 후 갱신을 검증함 |
| 상태 전이 | `PENDING`이 아닌 요청의 재처리를 차단함 |
| 학적 변경 | 현재값·변경일시·전후 이력·공통로그를 함께 처리하고 동일 상태·잘못된 학생·코드·권한을 차단함 |
| TOPCIT 경계값 | 0·1000은 허용하고 -1·1001·680.1은 입력 전에 차단함 |
| 접근 범위 | 본인·일반관리자·마스터관리자는 허용, 다른 학생은 `-20001`로 차단함 |
| 로그 원자성 | 의도적 로그 실패 시 학생·요청·학적이력·TOPCIT 변경이 함께 롤백됨을 검증함 |

## 실행 판정 기준

- 2026-10-27에 Oracle AI Database 26ai Free 23.26.3.0.0 ARM64의 별도 빈 검증 사용자에서 `sql/run_demo.sql`을 실행함
- 최종 `run_demo.sql` 전체 실행에서 기존 마일리지·예산 검사와 학생·TOPCIT 보강 검사를 합해 PASS 137개 확인함
- `ALL TESTS PASSED`, `STUDENT/TOPCIT TESTS PASSED`, `DEMO COMPLETED` 출력 확인함
- 테이블 29개, 뷰 4개, 패키지 명세·본문 각 2개가 모두 VALID이며 `USER_ERRORS=0`임
- 한국어 시드는 컨테이너 SQL*Plus에 `NLS_LANG=KOREAN_KOREA.AL32UTF8`을 설정하여 보존함
- 최신 테스트 실행 원문은 `verification/student-topcit-audit-2026-10-27.txt`에 저장함

## 구현 중 보완 사항

- `IDENTITY` 컬럼이 Oracle 내부 시퀀스를 생성하므로 테스트 사용자에 `CREATE SEQUENCE` 권한을 추가함
- 한국어 권한명·코드명의 문자 손실을 방지하기 위해 SQL*Plus 클라이언트 문자셋을 AL32UTF8로 고정함
