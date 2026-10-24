# PBL2 마일리지 · 예산 및 지출 관리 — 지선 담당

Oracle AI Database 26ai Free **23.26.3.0.0**, SQL Developer **26.2** 기준.
이 브랜치는 마일리지·예산 및 지출 관리의 **단독 구현/검증본**이다. 팀 전체 통합 완료본이 아니다.
공통 테이블 최종안은 포함하지 않았다. `sql/fixtures/`는 이 파트만 실행하기 위한 최소 실습 데이터 구조다.

## 제출 범위

- 마일리지 신청·승인·반려·취소·전액 회수와 유효 적립 집계
- 예산·지출 승인·반려·취소, 한도 초과 차단과 잔액/집행률 조회
- Q05~Q09, 담당 업무의 Q12 로그 조회
- 정상 데이터, 오류/상태 변경/실패 롤백 검증, 정책·설계 변경 문서

## 파일과 실행 순서

| 파일 | 내용 |
|---|---|
| `sql/fixtures/00_common_fixture.sql` | 단독 실습용 공통 DDL. 팀 통합 시 교체 |
| `sql/01_schema.sql` | 담당 테이블·제약조건·뷰·승인 패키지 |
| `sql/fixtures/01_common_seed.sql` | 단독 실습용 사용자/학생/프로그램/교수 |
| `sql/02_domain_seed.sql` | 마일리지·예산 담당 정상 데이터 |
| `sql/02_seed.sql` | 위 공통 실습 시드와 담당 시드를 순서대로 실행하는 진입점 |
| `sql/03_queries.sql` | Q05~Q09와 담당 Q12, 입력값·예상값 |
| `sql/04_tests.sql` | 57개 자동 검사, 각 테스트 변경 롤백 |
| `sql/05_workflow_examples.sql` | 승인·회수·취소 전후 시연, 마지막 롤백 |
| `sql/run_demo.sql` | 새 빈 실습 스키마에서 전체 실행 |
| `docs/정책및설계.md` | 업무 정책·상태 전이·테이블/관계·PBL1 대비 변경 |
| `docs/검증보고서.md` | 예상값과 실제값 비교·검증 방법·미구현 범위 |
| `verification/oracle-validation.txt` | Oracle 전체 실행 결과 원문 |
| `verification/workflow-demo.txt` | 승인 전후 시연 결과 |

### SQL Developer에서 실행

1. 빈 전용 실습 계정에 접속한다. SYS/SYSTEM에 업무 테이블을 만들지 않는다.
2. 계정에 CREATE SESSION, TABLE, VIEW, SEQUENCE, PROCEDURE, TRIGGER 권한과 USERS 할당량이 필요하다.
3. `sql/run_demo.sql`을 **파일로 열어 F5**를 누른다. `@@` 상대경로를 사용하므로 파일 내용을 다른 탭에 복사하지 않는다.
4. `ALL TESTS PASSED`, `DEMO COMPLETED`를 확인한다.
5. 이후에는 `03_queries.sql`, `04_tests.sql`, `05_workflow_examples.sql`만 개별 재실행한다.

전체 생성 스크립트/시드는 한 번만 실행한다. 기존 계정에 중복 실행하지 않는다.
초기화가 필요하면 본인이 만든 전용 실습 스키마임을 확인한 후 관리자에게 해당 계정 재생성을 요청하거나 다른 빈 계정을 사용한다.
Oracle DDL은 암묵적으로 커밋되므로 미확정 업무 작업을 먼저 정리한다. 공동 스키마 자동 삭제는 제공하지 않는다.
패키지는 COMMIT하지 않는다. 실제 처리 확정은 호출자가 COMMIT하고, 실패 시 업무 단위로 ROLLBACK한다.
SQL*Plus 실행 시 UTF-8 파일을 위해 클라이언트 `NLS_LANG=AMERICAN_AMERICA.AL32UTF8`을 설정한다.
SQL Developer 파일 인코딩은 UTF-8, 세션 시간대는 +09:00이다.

## 확인한 결과

- 단독 실습: 공통 fixture5개 + 담당 테이블12개 = 17개, 뷰/패키지 컴파일 오류0건.
- 자동 검사57개 통과. 유효 마일리지810점, 승인 지출1,500,000원.
- 시연: 학생5 0→100→0점, 연구활동비 승인 지출100,000→150,000→100,000원.
- 테스트 종료 후 데이터는 시드 상태로 복원하며 TEST_FAIL_LOG 트리거는 제거된다.
- 검증 기록은 실행 당시 결과다. 팀 데이터가 달라지면 예상값을 다시 계산한다.

## 팀 통합 시 남은 작업

공통 STUDENT/USER_ACCOUNT/PROGRAM/PROFESSOR/CHANGE_LOG의 실제 컬럼·FK·권한 구조와 테스트 ID에 맞춰 연결한 후 재검증한다.
팀 공통 DDL을 사용한다면 fixtures를 실행하지 않고, 팀 공통 시드 뒤 `02_domain_seed.sql`을 사용한다.
학생정보·TOPCIT·만족도 담당 구현과 전체 Q01~Q12 통합은 별도다.
정책은 담당 구현안이며 팀 합의가 필요하다.

권한은 전달받은 actor ID의 사용자 유형을 검사한다. 실제 로그인 신원 연계·actor 사칭 방지·직접 DML 차단은 미구현이다.
시험 중 쓰는 가상 계정 정보는 실제 사용자 개인정보가 아니다. 비밀번호·접속 설정은 저장소에 포함하지 않는다.
