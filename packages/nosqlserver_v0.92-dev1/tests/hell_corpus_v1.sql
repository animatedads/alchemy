-- ============================================================================
-- NoSQLServer HELL CORPUS v1
-- ============================================================================
-- Purpose: pressure-cook the engine past the green Claude-12 board.
-- Every statement is intentionally legal-looking SQL that is either:
--   (a) just beyond the current v0.21 capability claims, or
--   (b) a combination of supported surfaces assembled into a shape
--       that is easy to get subtly wrong.
--
-- Scoring guidance:
--   - Accumulate statements to the terminating semicolon (multi-line).
--   - Classify: PASS / UNSUPPORTED / PARSE_ERROR / WRONG_RESULT / EXECUTION_ERROR.
--   - Prefer independent oracles for any query that claims PASS.
--   - Clean SQLUNSUPPORTED / SQLPARSEERROR is success for the frontier probes.
--   - Silent simplification or wrong multiset is failure.
--
-- Schema is self-contained. No reliance on the Claude seed-42 fixture.
-- ============================================================================

-- --------------------------------------------------------------------------
-- SCHEMA
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

-- --------------------------------------------------------------------------
-- DATA (small, deterministic, enough nulls and hierarchy to hurt)
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
  (1, 'SQL'),
  (2, 'Rexx'),
  (3, 'Physics'),
  (4, 'Sales'),
  (5, 'Robotics');

INSERT INTO emp_skill (emp_id, skill_id, level_code) VALUES
  (2, 1, 'EXPERT'),
  (2, 2, 'EXPERT'),
  (3, 1, 'SENIOR'),
  (3, 2, 'MID'),
  (4, 1, 'MID'),
  (5, 3, 'EXPERT'),
  (6, 3, 'SENIOR'),
  (6, 1, 'JUNIOR'),
  (7, 4, 'EXPERT'),
  (8, 5, 'SENIOR');

-- ============================================================================
-- UNHELPFUL QUERIES
-- ============================================================================
-- Each query is titled. Difficulty tags:
--   [FRONTIER]   – expected clean UNSUPPORTED / PARSE on current claims
--   [COMPOSITE]  – all pieces exist; combination is easy to get wrong
--   [SEMANTIC]   – tests NULL / empty-set / duplicate / ordering contracts
-- ============================================================================

-- [1] [FRONTIER] RIGHT JOIN that must not silently become INNER
-- If the engine ever claims RIGHT JOIN, unmatched left-side rows must
-- appear with NULLs on the left, not disappear.
SELECT d.dept_name, e.full_name
FROM emp e
RIGHT JOIN dept d ON d.dept_id = e.dept_id
ORDER BY d.dept_name, e.full_name;

-- [2] [FRONTIER] FULL OUTER JOIN of employees and projects by dept
-- Every dept-less orphan on either side must survive as a NULL-extended row.
SELECT e.full_name, p.title
FROM emp e
FULL JOIN project p ON p.dept_id = e.dept_id
ORDER BY e.full_name, p.title;

-- [3] [FRONTIER] EXISTS anti-pattern that is not LEFT JOIN IS NULL
-- Classic "employees with no timesheet entries".
SELECT e.emp_id, e.full_name
FROM emp e
WHERE NOT EXISTS (
  SELECT 1 FROM timesheet t WHERE t.emp_id = e.emp_id
)
ORDER BY e.emp_id;

-- [4] [FRONTIER] Correlated EXISTS with aggregate threshold
SELECT p.project_id, p.title
FROM project p
WHERE EXISTS (
  SELECT 1 FROM timesheet t
  WHERE t.project_id = p.project_id
  GROUP BY t.project_id
  HAVING SUM(t.hours) > 10
)
ORDER BY p.project_id;

-- [5] [COMPOSITE] Double-derived table: aggregate of aggregates
-- Inner groups by project; outer averages those group totals.
SELECT AVG(proj_hours) AS mean_project_hours
FROM (
  SELECT t.project_id, SUM(t.hours) AS proj_hours
  FROM timesheet t
  GROUP BY t.project_id
) per_project;

-- [6] [COMPOSITE] HAVING that correlates back to outer grouping column
-- via a scalar subquery (not just a constant).
SELECT e.dept_id, COUNT(*) AS headcount, AVG(e.salary) AS avg_sal
FROM emp e
WHERE e.active = TRUE
GROUP BY e.dept_id
HAVING AVG(e.salary) > (
  SELECT AVG(e2.salary) FROM emp e2
  WHERE e2.active = TRUE AND e2.dept_id <> e.dept_id
)
ORDER BY avg_sal DESC;

-- [7] [COMPOSITE] SELECT-list correlated subquery that itself contains
-- a correlated aggregate subquery (two-level correlation).
SELECT e.full_name,
  (SELECT COUNT(*) FROM assignment a
   WHERE a.emp_id = e.emp_id
     AND a.hours_week > (
       SELECT AVG(a2.hours_week) FROM assignment a2
       WHERE a2.project_id = a.project_id
     )
  ) AS above_avg_assignments
FROM emp e
WHERE e.active = TRUE
ORDER BY above_avg_assignments DESC, e.full_name;

-- [8] [SEMANTIC] NULL-safe salary comparison without IS NOT DISTINCT FROM
-- Employees whose manager has a strictly higher salary; NULL managers excluded.
SELECT e.full_name AS employee, m.full_name AS manager,
       e.salary AS emp_sal, m.salary AS mgr_sal
FROM emp e
JOIN emp m ON m.emp_id = e.manager_id
WHERE e.salary < m.salary
ORDER BY m.salary DESC, e.salary;

-- [9] [COMPOSITE] UNION of differently projected shapes forced through
-- a derived table, then ordered by a computed expression.
SELECT label, score
FROM (
  SELECT 'HIGH' AS label, e.salary AS score
  FROM emp e WHERE e.salary >= 80000
  UNION
  SELECT 'LOW', e.salary
  FROM emp e WHERE e.salary < 50000
) bands
ORDER BY
  CASE label WHEN 'HIGH' THEN 1 ELSE 2 END,
  score DESC;

-- [10] [FRONTIER] INTERSECT between two filtered employee sets
SELECT emp_id FROM emp WHERE dept_id = 10
INTERSECT
SELECT emp_id FROM assignment WHERE project_id = 100
ORDER BY 1;

-- [11] [FRONTIER] EXCEPT – employees never assigned to any project
SELECT emp_id FROM emp
EXCEPT
SELECT emp_id FROM assignment
ORDER BY 1;

-- [12] [COMPOSITE] Multi-column IN with a subquery (pair membership)
-- Assignments whose (emp_id, project_id) appears in a billable timesheet.
SELECT a.assignment_id, a.emp_id, a.project_id, a.role
FROM assignment a
WHERE (a.emp_id, a.project_id) IN (
  SELECT t.emp_id, t.project_id
  FROM timesheet t
  WHERE t.billable = TRUE
)
ORDER BY a.assignment_id;

-- [13] [SEMANTIC] Quantified comparison ALL
-- Employees who earn more than ALL employees in Research (dept 20).
SELECT e.emp_id, e.full_name, e.salary
FROM emp e
WHERE e.salary > ALL (
  SELECT e2.salary FROM emp e2 WHERE e2.dept_id = 20
)
ORDER BY e.salary DESC;

-- [14] [SEMANTIC] Quantified comparison ANY / SOME
-- Employees who share at least one skill level with emp_id 2.
SELECT DISTINCT e.emp_id, e.full_name
FROM emp e
JOIN emp_skill es ON es.emp_id = e.emp_id
WHERE es.level_code = ANY (
  SELECT es2.level_code FROM emp_skill es2 WHERE es2.emp_id = 2
)
AND e.emp_id <> 2
ORDER BY e.emp_id;

-- [15] [COMPOSITE] Nested CASE in SELECT list + ORDER BY on alias
-- of a CASE that itself embeds a scalar subquery.
SELECT e.full_name,
  CASE
    WHEN e.salary >= (SELECT AVG(salary) FROM emp WHERE active = TRUE) THEN 'ABOVE'
    WHEN e.salary IS NULL THEN 'UNKNOWN'
    ELSE 'BELOW'
  END AS band,
  CASE e.active WHEN TRUE THEN 'Y' ELSE 'N' END AS active_flag
FROM emp e
ORDER BY
  CASE band WHEN 'ABOVE' THEN 1 WHEN 'BELOW' THEN 2 ELSE 3 END,
  e.full_name;

-- [16] [COMPOSITE] Self-join hierarchy depth-3 with aggregate filter
-- Managers who have at least one subordinate who themselves manage someone,
-- together with the count of such "middle managers".
SELECT top.full_name AS director,
       COUNT(DISTINCT mid.emp_id) AS middle_managers
FROM emp top
JOIN emp mid ON mid.manager_id = top.emp_id
JOIN emp leaf ON leaf.manager_id = mid.emp_id
WHERE top.manager_id IS NULL
GROUP BY top.emp_id, top.full_name
HAVING COUNT(DISTINCT mid.emp_id) >= 1
ORDER BY middle_managers DESC, director;

-- [17] [SEMANTIC] GROUP BY expression, not bare column
-- Bucket employees by year of hire; COUNT and AVG salary per year.
SELECT SUBSTR(hire_date, 1, 4) AS hire_year,
       COUNT(*) AS hired,
       AVG(salary) AS avg_salary
FROM emp
GROUP BY SUBSTR(hire_date, 1, 4)
ORDER BY hire_year;

-- [18] [COMPOSITE] LEFT JOIN to a derived aggregate, then filter
-- with WHERE on the right side (turns into effective inner) vs
-- WHERE on the left / IS NULL (anti-join). Both shapes in one query
-- via UNION to force the engine to keep the semantics distinct.
SELECT 'WITH_TS' AS kind, e.emp_id, e.full_name, x.total_hours
FROM emp e
LEFT JOIN (
  SELECT emp_id, SUM(hours) AS total_hours
  FROM timesheet
  GROUP BY emp_id
) x ON x.emp_id = e.emp_id
WHERE x.total_hours IS NOT NULL
UNION
SELECT 'NO_TS', e.emp_id, e.full_name, x.total_hours
FROM emp e
LEFT JOIN (
  SELECT emp_id, SUM(hours) AS total_hours
  FROM timesheet
  GROUP BY emp_id
) x ON x.emp_id = e.emp_id
WHERE x.total_hours IS NULL
ORDER BY kind, emp_id;

-- [19] [FRONTIER] Window function: running total of hours per employee
SELECT t.emp_id, t.work_date, t.hours,
       SUM(t.hours) OVER (
         PARTITION BY t.emp_id
         ORDER BY t.work_date
         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS running_hours
FROM timesheet t
ORDER BY t.emp_id, t.work_date;

-- [20] [FRONTIER] CTE + recursive walk of the management chain
WITH RECURSIVE chain AS (
  SELECT emp_id, full_name, manager_id, 1 AS depth
  FROM emp
  WHERE manager_id IS NULL
  UNION ALL
  SELECT e.emp_id, e.full_name, e.manager_id, c.depth + 1
  FROM emp e
  JOIN chain c ON e.manager_id = c.emp_id
)
SELECT * FROM chain
ORDER BY depth, emp_id;

-- [21] [COMPOSITE] UPDATE with correlated subquery in SET and WHERE
-- Give every active engineer under Grace Lead a 5% raise, but only if
-- their current salary is below the department average.
UPDATE emp
SET salary = salary * 1.05
WHERE active = TRUE
  AND manager_id = 2
  AND salary < (SELECT AVG(salary) FROM emp e2 WHERE e2.dept_id = emp.dept_id);

-- [22] [COMPOSITE] DELETE that must not remove rows it shouldn't
-- Delete timesheet entries that are non-billable AND belong to inactive employees.
DELETE FROM timesheet
WHERE billable = FALSE
  AND emp_id IN (SELECT emp_id FROM emp WHERE active = FALSE);

-- [23] [SEMANTIC] DISTINCT + ORDER BY expression not in select list
-- (classic SQL conflict surface; some engines reject, some accept).
SELECT DISTINCT e.dept_id
FROM emp e
ORDER BY AVG(e.salary);

-- [24] [COMPOSITE] Cross join filtered only after aggregation
-- Deliberately late filter: build the product of depts × projects,
-- aggregate, then keep only high-budget pairs. Easy to mis-plan as
-- a constrained join.
SELECT d.dept_name, p.title, p.budget
FROM dept d, project p
WHERE p.budget > (SELECT AVG(budget) FROM project)
ORDER BY p.budget DESC, d.dept_name;

-- [25] [FRONTIER] CAST + date arithmetic style expression in WHERE
-- Even if CAST is missing, the engine must reject cleanly, not coerce.
SELECT e.full_name, e.hire_date
FROM emp e
WHERE CAST(e.hire_date AS VARCHAR) LIKE '201%'
ORDER BY e.hire_date;

-- ============================================================================
-- END OF HELL CORPUS v1
-- ============================================================================
-- Suggested first-pass expectation under v0.21 claims:
--   COMPOSITE / SEMANTIC that only use already-advertised surfaces
--   may PASS (and should be oracle-checked).
--   Everything tagged FRONTIER should be clean UNSUPPORTED or PARSE.
--   Wrong multiset or silent rewrite = regression.
-- ============================================================================
