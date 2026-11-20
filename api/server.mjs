import http from 'node:http';
import oracledb from 'oracledb';

const requiredEnv = ['DB_USER', 'DB_PASSWORD', 'DB_CONNECT_STRING'];
for (const key of requiredEnv) {
  if (!process.env[key]) {
    console.error(`Missing required environment variable: ${key}`);
    process.exit(1);
  }
}

const port = Number(process.env.PORT || 8787);
const allowedOrigin = process.env.CORS_ORIGIN || 'http://127.0.0.1:43127';
oracledb.outFormat = oracledb.OUT_FORMAT_OBJECT;

const pool = await oracledb.createPool({
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  connectString: process.env.DB_CONNECT_STRING,
  poolMin: 1,
  poolMax: 4,
  poolIncrement: 1
});

function send(res, status, payload) {
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'access-control-allow-origin': allowedOrigin,
    'access-control-allow-methods': 'GET,OPTIONS',
    'access-control-allow-headers': 'content-type'
  });
  res.end(JSON.stringify(payload));
}

function asNumber(value, name) {
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) {
    throw new Error(`${name} must be a positive integer`);
  }
  return parsed;
}

function dateOrNull(value, name) {
  if (!value) return null;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) throw new Error(`${name} must be YYYY-MM-DD`);
  return value;
}

async function query(sql, binds = {}) {
  let connection;
  try {
    connection = await pool.getConnection();
    const result = await connection.execute(sql, binds);
    return result.rows;
  } finally {
    if (connection) await connection.close();
  }
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') return send(res, 204, {});
  if (req.method !== 'GET') return send(res, 405, { error: 'Method not allowed' });

  try {
    const url = new URL(req.url, `http://${req.headers.host}`);
    if (url.pathname === '/health') {
      await query('SELECT 1 AS ok FROM dual');
      return send(res, 200, { status: 'ok' });
    }

    if (url.pathname === '/api/budget/items') {
      const projectId = url.searchParams.get('projectId');
      const binds = { project_id: projectId ? asNumber(projectId, 'projectId') : null };
      const rows = await query(`
        SELECT project_id,project_budget_id,item_code,item_name,current_amount,
               approved_expense,budget_balance,pending_expense_count,execution_rate,total_income,
               actual_paid,actual_cash_balance,income_data_count,payment_data_count
        FROM v_budget_cash_summary
        WHERE (:project_id IS NULL OR project_id=:project_id)
        ORDER BY project_id,project_budget_id
      `, binds);
      return send(res, 200, { items: rows });
    }

    const match = url.pathname.match(/^\/api\/budget\/items\/(\d+)\/transactions$/);
    if (match) {
      const projectBudgetId = asNumber(match[1], 'projectBudgetId');
      const type = (url.searchParams.get('type') || 'ALL').toUpperCase();
      const status = (url.searchParams.get('status') || 'ALL').toUpperCase();
      const fromDate = dateOrNull(url.searchParams.get('from'), 'from');
      const toDate = dateOrNull(url.searchParams.get('to'), 'to');
      const searchText = (url.searchParams.get('q') || '').trim().toUpperCase();
      if (!['ALL', 'INCOME', 'EXPENSE'].includes(type)) throw new Error('Invalid type');
      if (!['ALL', 'APPROVED', 'PENDING', 'REJECTED', 'PAID'].includes(status)) {
        throw new Error('Invalid status');
      }

      const rows = await query(`
        SELECT transaction_id,project_budget_id,transaction_date,transaction_type,
               detail_item,manager_name,transaction_description,income_amount,
               expense_amount,approval_status,payment_status
        FROM v_budget_transaction
        WHERE project_budget_id=:project_budget_id
          AND (:transaction_type='ALL' OR transaction_type=:transaction_type)
          AND (:status_filter='ALL' OR approval_status=:status_filter OR payment_status=:status_filter)
          AND (:from_date IS NULL OR transaction_date>=TO_DATE(:from_date,'YYYY-MM-DD'))
          AND (:to_date IS NULL OR transaction_date<TO_DATE(:to_date,'YYYY-MM-DD')+1)
          AND (:search_text IS NULL
               OR UPPER(transaction_id) LIKE :search_like
               OR UPPER(detail_item) LIKE :search_like
               OR UPPER(manager_name) LIKE :search_like
               OR UPPER(transaction_description) LIKE :search_like)
        ORDER BY transaction_date DESC,transaction_id DESC
      `, {
        project_budget_id: projectBudgetId,
        transaction_type: type,
        status_filter: status,
        from_date: fromDate,
        to_date: toDate,
        search_text: searchText || null,
        search_like: `%${searchText}%`
      });
      return send(res, 200, { transactions: rows });
    }

    return send(res, 404, { error: 'Not found' });
  } catch (error) {
    const clientError = /must be|Invalid/.test(error.message);
    console.error(error);
    return send(res, clientError ? 400 : 500, {
      error: clientError ? error.message : 'Database query failed'
    });
  }
});

server.listen(port, '127.0.0.1', () => {
  console.log(`Budget API listening on http://127.0.0.1:${port}`);
});

async function shutdown() {
  server.close();
  await pool.close(10);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

