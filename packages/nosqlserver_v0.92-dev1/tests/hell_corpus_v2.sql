-- ============================================================================
-- NoSQLServer HELL CORPUS v2
-- ============================================================================
-- Designed against a post-v0.27 surface where hell_corpus_v1 sits at
-- roughly 24/25 PASS. These queries assume RIGHT/FULL JOIN, EXISTS,
-- INTERSECT/EXCEPT, basic window SUM, recursive CTE, CAST, row-value IN,
-- ALL/ANY, correlated UPDATE/DELETE, and GROUP BY expressions already work.
--
-- Goal: force the next set of semantic and planner mistakes.
-- Tags: [FRONTIER] [COMPOSITE] [SEMANTIC] [MUTATION]
-- ============================================================================

-- --------------------------------------------------------------------------
-- SCHEMA (superset of v1; safe to load into a fresh database)
-- --------------------------------------------------------------------------

CREATE TABLE dept (
  dept_id     INTEGER PRIMARY KEY,
  dept_name   VARCHAR(40) NOT NULL UNIQUE,
  location    VARCHAR(40) NOT NULL
);

CREATE TABLE emp (
  emp_id      INTEGER PRIMARY KEY,
  full_name   VARCHAR(80) NOT NULL,
  dept_id     INTEGER NOT NULL,
  manager_id  INTEGER,
  salary      DECIMAL(10,2) NOT NULL,
  hire_date   DATE NOT NULL,
  active      BOOLEAN NOT NULL
);

CREATE TABLE project (
  project_id  INTEGER PRIMARY KEY,
  title       VARCHAR(80) NOT NULL,
  dept_id     INTEGER NOT NULL,
  budget      DECIMAL(12,2) NOT NULL,
  start_date  DATE NOT NULL,
  end_date    DATE
);

CREATE TABLE assignment (
  assignment_id INTEGER PRIMARY KEY,
  emp_id        INTEGER NOT NULL,
  project_id    INTEGER NOT NULL,
  role          VARCHAR(40) NOT NULL,
  hours_week    DECIMAL(5,1) NOT NULL,
  start_date    DATE NOT NULL
);

CREATE TABLE timesheet (
  entry_id    INTEGER PRIMARY KEY,
  emp_id      INTEGER NOT NULL,
  project_id  INTEGER NOT NULL,
  work_date   DATE NOT NULL,
  hours       DECIMAL(4,1) NOT NULL,
  billable    BOOLEAN NOT NULL
);

CREATE TABLE skill (
  skill_id    INTEGER PRIMARY KEY,
  skill_name  VARCHAR(40) NOT NULL UNIQUE
);

CREATE TABLE emp_skill (
  emp_id      INTEGER NOT NULL,
  skill_id    INTEGER NOT NULL,
  level_code  VARCHAR(10) NOT NULL,
  PRIMARY KEY (emp_id, skill_id)
);

CREATE TABLE pay_event (
  event_id    INTEGER PRIMARY KEY,
  emp_id      INTEGER NOT NULL,
  event_date  DATE NOT NULL,
  amount      DECIMAL(10,2) NOT NULL,
  kind        VARCHAR(20) NOT NULL
);

-- --------------------------------------------------------------------------
-- DATA
-- --------------------------------------------------------------------------

INSERT INTO dept (dept_id, dept_name, location) VALUES
  (10, 'Engineering', 'Glasgow'),
  (20, 'Research',    'Edinburgh'),
  (30, 'Sales',       'London'),
  (40, 'Operations',  'Manchester');

INSERT INTO emp (emp_id, full_name, dept_id, manager_id, salary, hire_date, active) VALUES
  (1,  'Ada Director',     10, NULL, 120000.00, '2015-01-15', TRUE),
  (2,  'Grace Lead',       10, 1,     95000.00, '2016-06-01', TRUE),
  (3,  'Alan Engineer',    10, 2,     72000.00, '2018-03-12', TRUE),
  (4,  'Katherine Eng',    10, 2,     71000.00, '2019-09-01', TRUE),
  (5,  'Dennis Research',  20, 1,     88000.00, '2017-02-20', TRUE),
  (6,  'Barbara Scientist',20, 5,     69000.00, '2020-11-11', TRUE),
  (7,  'Linus Sales',      30, 1,     80000.00, '2018-07-07', TRUE),
  (8,  'Margaret Ops',     40, 1,     78000.00, '2016-12-01', TRUE),
  (9,  'Ken Contractor',   10, 2,     0.00,     '2024-01-10', FALSE),
  (10, 'Empty Desk',       30, 7,     45000.00, '2023-05-05', TRUE);

INSERT INTO project (project_id, title, dept_id, budget, start_date, end_date) VALUES
  (100, 'Hyperdrive',      10, 500000.00, '2024-01-01', NULL),
  (101, 'Quantum Lens',    20, 320000.00, '2023-06-01', '2025-12-31'),
  (102, 'Sales Portal',    30,  90000.00, '2024-03-01', NULL),
  (103, 'Warehouse Bot',   40, 150000.00, '2022-01-01', '2024-06-30'),
  (104, 'Skunkworks',      10,  25000.00, '2025-01-01', NULL);

INSERT INTO assignment (assignment_id, emp_id, project_id, role, hours_week, start_date) VALUES
  (1, 1, 100, 'Sponsor',     4.0,  '2024-01-01'),
  (2, 2, 100, 'Lead',       30.0,  '2024-01-01'),
  (3, 3, 100, 'Engineer',   35.0,  '2024-01-15'),
  (4, 4, 100, 'Engineer',   20.0,  '2024-02-01'),
  (5, 4, 104, 'Engineer',   15.0,  '2025-01-01'),
  (6, 5, 101, 'Lead',       25.0,  '2023-06-01'),
  (7, 6, 101, 'Scientist',  40.0,  '2023-06-01'),
  (8, 7, 102, 'Owner',      20.0,  '2024-03-01'),
  (9, 8, 103, 'Owner',      10.0,  '2022-01-01'),
  (10,3, 104, 'Engineer',   10.0,  '2025-01-01');

INSERT INTO timesheet (entry_id, emp_id, project_id, work_date, hours, billable) VALUES
  (1,  3, 100, '2024-02-05', 8.0, TRUE),
  (2,  3, 100, '2024-02-06', 7.5, TRUE),
  (3,  3, 104, '2025-01-20', 4.0, FALSE),
  (4,  4, 100, '2024-02-05', 6.0, TRUE),
  (5,  4, 104, '2025-01-21', 5.0, FALSE),
  (6,  6, 101, '2024-07-01', 8.0, TRUE),
  (7,  6, 101, '2024-07-02', 8.0, TRUE),
  (8,  7, 102, '2024-04-10', 3.0, TRUE),
  (9,  2, 100, '2024-02-05', 2.0, TRUE),
  (10, 9, 100, '2024-02-06', 8.0, FALSE);

INSERT INTO skill (skill_id, skill_name) VALUES
  (1, 'SQL'), (2, 'Rexx'), (3, 'Physics'), (4, 'Sales'), (5, 'Robotics');

INSERT INTO emp_skill (emp_id, skill_id, level_code) VALUES
  (2, 1, 'EXPERT'), (2, 2, 'EXPERT'),
  (3, 1, 'SENIOR'), (3, 2, 'MID'),
  (4, 1, 'MID'),
  (5, 3, 'EXPERT'),
  (6, 3, 'SENIOR'), (6, 1, 'JUNIOR'),
  (7, 4, 'EXPERT'),
  (8, 5, 'SENIOR');

INSERT INTO pay_event (event_id, emp_id, event_date, amount, kind) VALUES
  (1, 3, '2024-01-31', 6000.00, 'SALARY'),
  (2, 3, '2024-02-29', 6000.00, 'SALARY'),
  (3, 3, '2024-03-15',  500.00, 'BONUS'),
  (4, 4, '2024-01-31', 5900.00, 'SALARY'),
  (5, 4, '2024-02-29', 5900.00, 'SALARY'),
  (6, 6, '2024-07-31', 5750.00, 'SALARY'),
  (7, 2, '2024-02-28', 8000.00, 'SALARY'),
  (8, 2, '2024-03-01', 1000.00, 'BONUS'),
  (9, 9, '2024-02-15', 2000.00, 'CONTRACT'),
  (10,7, '2024-04-30', 6666.67, 'SALARY');

-- ============================================================================
-- QUERIES
-- ============================================================================

-- [1] [FRONTIER] RANK / DENSE_RANK / ROW_NUMBER in one pass
SELECT e.full_name, e.dept_id, e.salary,
       ROW_NUMBER() OVER (PARTITION BY e.dept_id ORDER BY e.salary DESC) AS rn,
       RANK()       OVER (PARTITION BY e.dept_id ORDER BY e.salary DESC) AS rk,
       DENSE_RANK() OVER (PARTITION BY e.dept_id ORDER BY e.salary DESC) AS dr
FROM emp e
WHERE e.active = TRUE
ORDER BY e.dept_id, rn;

-- [2] [FRONTIER] LAG / LEAD with explicit offsets and defaults
SELECT t.emp_id, t.work_date, t.hours,
       LAG(t.hours, 1, 0)  OVER (PARTITION BY t.emp_id ORDER BY t.work_date) AS prev_hours,
       LEAD(t.hours, 1, 0) OVER (PARTITION BY t.emp_id ORDER BY t.work_date) AS next_hours
FROM timesheet t
ORDER BY t.emp_id, t.work_date;

-- [3] [FRONTIER] NTILE + multiple window clauses on same SELECT
SELECT e.emp_id, e.salary,
       NTILE(4) OVER (ORDER BY e.salary) AS salary_quartile,
       SUM(e.salary) OVER () AS company_total,
       SUM(e.salary) OVER (PARTITION BY e.dept_id) AS dept_total
FROM emp e
WHERE e.active = TRUE
ORDER BY salary_quartile, e.salary;

-- [4] [FRONTIER] Window FILTER clause (SQL:2003)
SELECT e.dept_id,
       COUNT(*) AS all_emps,
       COUNT(*) FILTER (WHERE e.salary >= 80000) AS high_earners,
       SUM(e.salary) FILTER (WHERE e.active = TRUE) AS active_payroll
FROM emp e
GROUP BY e.dept_id
ORDER BY e.dept_id;

-- [5] [FRONTIER] Named window definition reused
SELECT t.emp_id, t.work_date, t.hours,
       SUM(t.hours) OVER w AS running,
       AVG(t.hours) OVER w AS running_avg
FROM timesheet t
WINDOW w AS (PARTITION BY t.emp_id ORDER BY t.work_date
             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
ORDER BY t.emp_id, t.work_date;

-- [6] [FRONTIER] GROUPING SETS
SELECT e.dept_id, e.active, COUNT(*) AS n, SUM(e.salary) AS payroll
FROM emp e
GROUP BY GROUPING SETS (
  (e.dept_id, e.active),
  (e.dept_id),
  ()
)
ORDER BY e.dept_id, e.active;

-- [7] [FRONTIER] ROLLUP
SELECT d.location, e.dept_id, COUNT(*) AS n
FROM emp e
JOIN dept d ON d.dept_id = e.dept_id
GROUP BY ROLLUP (d.location, e.dept_id)
ORDER BY d.location, e.dept_id;

-- [8] [FRONTIER] CUBE
SELECT e.dept_id, e.active, COUNT(*) AS n
FROM emp e
GROUP BY CUBE (e.dept_id, e.active)
ORDER BY e.dept_id, e.active;

-- [9] [COMPOSITE] Window over a derived aggregate relation
SELECT x.emp_id, x.total_hours,
       RANK() OVER (ORDER BY x.total_hours DESC) AS hours_rank
FROM (
  SELECT emp_id, SUM(hours) AS total_hours
  FROM timesheet
  GROUP BY emp_id
) x
ORDER BY hours_rank, x.emp_id;

-- [10] [FRONTIER] LATERAL join – per-employee top project by hours
SELECT e.emp_id, e.full_name, top.project_id, top.hours
FROM emp e
JOIN LATERAL (
  SELECT t.project_id, SUM(t.hours) AS hours
  FROM timesheet t
  WHERE t.emp_id = e.emp_id
  GROUP BY t.project_id
  ORDER BY SUM(t.hours) DESC
  FETCH FIRST 1 ROW ONLY
) top ON TRUE
ORDER BY e.emp_id;

-- [11] [FRONTIER] LEFT JOIN LATERAL that must NULL-extend
SELECT e.emp_id, e.full_name, b.bonus_total
FROM emp e
LEFT JOIN LATERAL (
  SELECT SUM(p.amount) AS bonus_total
  FROM pay_event p
  WHERE p.emp_id = e.emp_id AND p.kind = 'BONUS'
) b ON TRUE
ORDER BY e.emp_id;

-- [12] [FRONTIER] MERGE (UPSERT) assignment hours
MERGE INTO assignment a
USING (
  SELECT 3 AS emp_id, 100 AS project_id, 40.0 AS hours_week
) src
ON a.emp_id = src.emp_id AND a.project_id = src.project_id
WHEN MATCHED THEN
  UPDATE SET hours_week = src.hours_week
WHEN NOT MATCHED THEN
  INSERT (assignment_id, emp_id, project_id, role, hours_week, start_date)
  VALUES (11, src.emp_id, src.project_id, 'Engineer', src.hours_week, '2025-02-01');

-- [13] [COMPOSITE] Recursive CTE with cycle guard (same hierarchy, deeper claim)
WITH RECURSIVE chain AS (
  SELECT emp_id, full_name, manager_id, 1 AS depth,
         CAST(emp_id AS VARCHAR) AS path
  FROM emp
  WHERE manager_id IS NULL
  UNION ALL
  SELECT e.emp_id, e.full_name, e.manager_id, c.depth + 1,
         c.path || '/' || CAST(e.emp_id AS VARCHAR)
  FROM emp e
  JOIN chain c ON e.manager_id = c.emp_id
  WHERE c.path NOT LIKE '%' || CAST(e.emp_id AS VARCHAR) || '%'
)
SELECT emp_id, full_name, depth, path
FROM chain
ORDER BY depth, emp_id;

-- [14] [FRONTIER] Recursive CTE with SEARCH / CYCLE clauses (SQL:1999)
WITH RECURSIVE chain AS (
  SELECT emp_id, full_name, manager_id, 1 AS depth
  FROM emp
  WHERE manager_id IS NULL
  UNION ALL
  SELECT e.emp_id, e.full_name, e.manager_id, c.depth + 1
  FROM emp e
  JOIN chain c ON e.manager_id = c.emp_id
)
SEARCH DEPTH FIRST BY emp_id SET seq
CYCLE emp_id SET is_cycle TO TRUE DEFAULT FALSE
SELECT emp_id, full_name, depth, seq, is_cycle
FROM chain
ORDER BY seq;

-- [15] [SEMANTIC] NULLS FIRST / NULLS LAST in ORDER BY
SELECT e.full_name, e.manager_id, e.salary
FROM emp e
ORDER BY e.manager_id NULLS FIRST, e.salary DESC;

-- [16] [FRONTIER] FETCH FIRST WITH TIES
SELECT e.full_name, e.salary
FROM emp e
WHERE e.active = TRUE
ORDER BY e.salary DESC
FETCH FIRST 3 ROWS WITH TIES;

-- [17] [COMPOSITE] VALUES constructor as a table source
SELECT v.emp_id, v.note, e.full_name
FROM (
  VALUES
    (3, 'review'),
    (4, 'promote'),
    (99, 'missing')
) AS v(emp_id, note)
LEFT JOIN emp e ON e.emp_id = v.emp_id
ORDER BY v.emp_id;

-- [18] [FRONTIER] NATURAL JOIN (dangerous by design)
SELECT *
FROM emp
NATURAL JOIN assignment
ORDER BY emp_id, assignment_id;

-- [19] [FRONTIER] UNION CORRESPONDING
SELECT emp_id, full_name FROM emp WHERE dept_id = 10
UNION CORRESPONDING
SELECT emp_id, full_name FROM emp WHERE salary > 90000
ORDER BY emp_id;

-- [20] [COMPOSITE] Subquery in JOIN ON condition
SELECT e.full_name, p.title, a.role
FROM emp e
JOIN assignment a ON a.emp_id = e.emp_id
JOIN project p ON p.project_id = a.project_id
  AND p.budget > (
    SELECT AVG(budget) FROM project p2 WHERE p2.dept_id = p.dept_id
  )
ORDER BY e.full_name, p.title;

-- [21] [MUTATION] UPDATE … FROM (multi-table assignment)
UPDATE emp e
SET salary = salary * 1.10
FROM dept d
WHERE d.dept_id = e.dept_id
  AND d.location = 'Glasgow'
  AND e.active = TRUE;

-- [22] [MUTATION] DELETE USING
DELETE FROM timesheet t
USING emp e
WHERE t.emp_id = e.emp_id
  AND e.active = FALSE
  AND t.billable = FALSE;

-- [23] [SEMANTIC] DISTINCT + ORDER BY non-projected expression (v1 survivor)
-- Still the classic conflict surface. Must not silently drop ORDER BY
-- or invent a projection.
SELECT DISTINCT e.dept_id
FROM emp e
ORDER BY AVG(e.salary);

-- [24] [COMPOSITE] Ordered-set style percentile via window + filter
-- (manual PERCENTILE_CONT approximation without the ordered-set aggregate)
SELECT dept_id, salary AS median_salary
FROM (
  SELECT e.dept_id, e.salary,
         ROW_NUMBER() OVER (PARTITION BY e.dept_id ORDER BY e.salary) AS rn,
         COUNT(*)    OVER (PARTITION BY e.dept_id) AS n
  FROM emp e
  WHERE e.active = TRUE
) x
WHERE rn = (n + 1) / 2
ORDER BY dept_id;

-- [25] [COMPOSITE] Mutual-looking recursive shape via two CTEs
-- (billable hours per employee, then employees above department mean)
WITH per_emp AS (
  SELECT t.emp_id, SUM(t.hours) AS billable_hours
  FROM timesheet t
  WHERE t.billable = TRUE
  GROUP BY t.emp_id
),
dept_mean AS (
  SELECT e.dept_id, AVG(p.billable_hours) AS mean_hours
  FROM emp e
  JOIN per_emp p ON p.emp_id = e.emp_id
  GROUP BY e.dept_id
)
SELECT e.full_name, e.dept_id, p.billable_hours, d.mean_hours
FROM emp e
JOIN per_emp p ON p.emp_id = e.emp_id
JOIN dept_mean d ON d.dept_id = e.dept_id
WHERE p.billable_hours > d.mean_hours
ORDER BY p.billable_hours DESC;

-- [26] [FRONTIER] FILTER on aggregate inside HAVING
SELECT e.dept_id,
       COUNT(*) AS n,
       COUNT(*) FILTER (WHERE e.salary >= 80000) AS high_n
FROM emp e
GROUP BY e.dept_id
HAVING COUNT(*) FILTER (WHERE e.salary >= 80000) >= 1
ORDER BY e.dept_id;

-- [27] [COMPOSITE] Window function result used in outer WHERE via derived table
SELECT full_name, salary, dept_rank
FROM (
  SELECT e.full_name, e.salary,
         RANK() OVER (PARTITION BY e.dept_id ORDER BY e.salary DESC) AS dept_rank
  FROM emp e
  WHERE e.active = TRUE
) ranked
WHERE dept_rank = 1
ORDER BY salary DESC;

-- [28] [SEMANTIC] Set operation with different column names + CORRESPONDING BY
SELECT emp_id AS id, full_name AS name FROM emp WHERE dept_id = 10
EXCEPT CORRESPONDING BY (id)
SELECT manager_id AS id, full_name AS name FROM emp WHERE manager_id IS NOT NULL
ORDER BY id;

-- [29] [COMPOSITE] Deeply nested scalar subquery in SELECT list
-- (4 levels: emp → assignment count → avg hours on those projects →
--  timesheet total compared to that avg)
SELECT e.full_name,
  (SELECT COUNT(*) FROM assignment a WHERE a.emp_id = e.emp_id) AS assignments,
  (SELECT AVG(a.hours_week) FROM assignment a WHERE a.emp_id = e.emp_id) AS avg_awarded,
  (SELECT COALESCE(SUM(t.hours),0) FROM timesheet t WHERE t.emp_id = e.emp_id) AS logged
FROM emp e
WHERE e.active = TRUE
ORDER BY logged DESC, e.full_name;

-- [30] [FRONTIER] PIVOT-style crosstab via conditional aggregation
SELECT emp_id,
       SUM(CASE WHEN kind = 'SALARY'   THEN amount ELSE 0 END) AS salary_paid,
       SUM(CASE WHEN kind = 'BONUS'    THEN amount ELSE 0 END) AS bonus_paid,
       SUM(CASE WHEN kind = 'CONTRACT' THEN amount ELSE 0 END) AS contract_paid
FROM pay_event
GROUP BY emp_id
ORDER BY emp_id;

-- ============================================================================
-- END HELL CORPUS v2
-- ============================================================================
-- Suggested expectation bands under a strong post-v0.27 engine:
--   Already-likely PASS : 9, 13, 17, 20, 23(still?), 25, 27, 29, 30
--   COMPOSITE stretch   : 5, 24, 26
--   FRONTIER (new)      : 1-4, 6-8, 10-12, 14-16, 18-19, 21-22, 28
-- Promote only with independent oracles. Silent wrong multisets = regression.
-- ============================================================================
