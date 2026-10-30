#!/usr/bin/env python3
"""
sql_torture_generator.py

Generates a single .sql/.txt file containing:

  1. CREATE TABLE statements for 5 related tables (with foreign keys).
  2. Randomly generated INSERT data, cross-referenced across tables,
     grown until the output file reaches roughly --target-mb megabytes.
  3. A set of deliberately convoluted / inefficient "unhelpful" queries
     that exercise joins, sorts, subqueries, aggregates, unions, etc.

Standard ANSI-ish SQL (INT / VARCHAR / DECIMAL / DATE), intended to be
portable across PostgreSQL / MySQL / SQLite-family engines. No external
dependencies.

Usage:
    python3 sql_torture_generator.py --target-mb 5 --outfile torture.sql
    python3 sql_torture_generator.py --target-mb 50 --outfile big.sql --seed 42
"""

import argparse
import random
from datetime import date, timedelta

# --------------------------------------------------------------------------
# data pools
# --------------------------------------------------------------------------

FIRST_NAMES = [
    "James", "Mary", "Robert", "Patricia", "John", "Jennifer", "Michael",
    "Linda", "William", "Elizabeth", "David", "Barbara", "Richard", "Susan",
    "Joseph", "Jessica", "Thomas", "Sarah", "Charles", "Karen", "Fiona",
    "Angus", "Morag", "Callum", "Isla", "Rory", "Aoife", "Declan", "Priya",
    "Wei", "Ahmed", "Sofia", "Lukas", "Ines", "Noor", "Bjorn", "Hana",
]

LAST_NAMES = [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller",
    "Davis", "Rodriguez", "Martinez", "MacLeod", "Campbell", "Stewart",
    "Robertson", "Murray", "Fraser", "Kowalski", "Nowak", "Rossi", "Muller",
    "Andersson", "Kim", "Nguyen", "Patel", "Okafor", "Haddad", "Larsen",
]

CITIES = [
    "Glasgow", "Edinburgh", "London", "Manchester", "Dublin", "Belfast",
    "Cardiff", "Bristol", "Leeds", "Aberdeen", "Inverness", "York",
    "Liverpool", "Newcastle", "Sheffield", "Southampton",
]

CATEGORIES = ["Electronics", "Kitchenware", "Outdoor", "Office", "Toys",
              "Books", "Automotive", "Garden", "Fitness", "Stationery"]

PRODUCT_ADJ = ["Compact", "Deluxe", "Portable", "Heavy-Duty", "Wireless",
               "Ergonomic", "Rapid", "Silent", "Rugged", "Classic",
               "Premium", "Budget", "Modular", "Foldable"]

PRODUCT_NOUN = ["Widget", "Kettle", "Drill", "Backpack", "Monitor", "Chair",
                "Notebook", "Charger", "Tent", "Blender", "Lamp", "Speaker",
                "Toolkit", "Organizer", "Cooler"]

DEPARTMENTS = ["Sales", "Warehouse", "Support", "Finance", "IT", "HR",
               "Procurement", "Logistics"]

STATUSES = ["PENDING", "SHIPPED", "DELIVERED", "CANCELLED", "RETURNED"]
TIERS = ["BRONZE", "SILVER", "GOLD", "PLATINUM"]


def rand_name():
    return f"{random.choice(FIRST_NAMES)} {random.choice(LAST_NAMES)}"


def rand_email(name, uid):
    local = name.lower().replace(" ", ".")
    return f"{local}{uid}@example.com"


def rand_product_name():
    return f"{random.choice(PRODUCT_ADJ)} {random.choice(PRODUCT_NOUN)}"


def rand_date(start, end):
    delta = (end - start).days
    return start + timedelta(days=random.randint(0, delta))


def sql_str(s):
    return "'" + str(s).replace("'", "''") + "'"


# --------------------------------------------------------------------------
# schema
# --------------------------------------------------------------------------

SCHEMA_SQL_TEMPLATE = """\
-- ==========================================================================
-- SCHEMA: 5 tables, deliberately under-indexed (see unhelpful queries below)
-- ==========================================================================

CREATE TABLE customers (
    customer_id   INTEGER PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(150) NOT NULL,
    city          VARCHAR(50)  NOT NULL,
    signup_date   DATE         NOT NULL,
    loyalty_tier  VARCHAR(20)  NOT NULL
);

CREATE TABLE employees (
    employee_id   INTEGER PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    hire_date     DATE         NOT NULL,
    manager_id    INTEGER      NULL{employees_fk},
    department    VARCHAR(50)  NOT NULL
);

CREATE TABLE products (
    product_id    INTEGER PRIMARY KEY,
    product_name  VARCHAR(100) NOT NULL,
    category      VARCHAR(50)  NOT NULL,
    unit_price    DECIMAL(10,2) NOT NULL,
    stock_qty     INTEGER      NOT NULL
);

CREATE TABLE orders (
    order_id      INTEGER PRIMARY KEY,
    customer_id   INTEGER NOT NULL{orders_customer_fk},
    employee_id   INTEGER NOT NULL{orders_employee_fk},
    order_date    DATE    NOT NULL,
    status        VARCHAR(20) NOT NULL
);

CREATE TABLE order_items (
    order_item_id INTEGER PRIMARY KEY,
    order_id      INTEGER NOT NULL{items_order_fk},
    product_id    INTEGER NOT NULL{items_product_fk},
    quantity      INTEGER NOT NULL,
    unit_price    DECIMAL(10,2) NOT NULL
);

"""


def schema_sql(with_foreign_keys=True):
    if with_foreign_keys:
        refs = {
            "employees_fk": " REFERENCES employees(employee_id)",
            "orders_customer_fk": " REFERENCES customers(customer_id)",
            "orders_employee_fk": " REFERENCES employees(employee_id)",
            "items_order_fk": " REFERENCES orders(order_id)",
            "items_product_fk": " REFERENCES products(product_id)",
        }
    else:
        refs = {
            "employees_fk": "",
            "orders_customer_fk": "",
            "orders_employee_fk": "",
            "items_order_fk": "",
            "items_product_fk": "",
        }
    return SCHEMA_SQL_TEMPLATE.format(**refs)


def write_batched_insert(f, table, cols, rows, batch=200):
    for i in range(0, len(rows), batch):
        chunk = rows[i:i + batch]
        f.write(f"INSERT INTO {table} ({cols}) VALUES\n")
        f.write(",\n".join(chunk))
        f.write(";\n")


# --------------------------------------------------------------------------
# fixed-size reference tables
# --------------------------------------------------------------------------

def write_customers(f, n):
    f.write(f"\n-- {n} customers\n")
    rows = []
    for i in range(1, n + 1):
        name = rand_name()
        email = rand_email(name, i)
        city = random.choice(CITIES)
        signup = rand_date(date(2019, 1, 1), date(2026, 8, 1))
        tier = random.choice(TIERS)
        rows.append(
            f"({i}, {sql_str(name)}, {sql_str(email)}, {sql_str(city)}, "
            f"{sql_str(signup)}, {sql_str(tier)})"
        )
    write_batched_insert(
        f, "customers",
        "customer_id, full_name, email, city, signup_date, loyalty_tier",
        rows,
    )
    return list(range(1, n + 1))


def write_employees(f, n):
    f.write(f"\n-- {n} employees\n")
    rows = []
    ids = []
    for i in range(1, n + 1):
        name = rand_name()
        hire = rand_date(date(2015, 1, 1), date(2026, 6, 1))
        dept = random.choice(DEPARTMENTS)
        if i <= 5 or not ids:
            manager = "NULL"
        else:
            manager = str(random.choice(ids))
        rows.append(
            f"({i}, {sql_str(name)}, {sql_str(hire)}, {manager}, {sql_str(dept)})"
        )
        ids.append(i)
    write_batched_insert(
        f, "employees",
        "employee_id, full_name, hire_date, manager_id, department",
        rows,
    )
    return ids


def write_products(f, n):
    f.write(f"\n-- {n} products\n")
    rows = []
    for i in range(1, n + 1):
        name = rand_product_name()
        cat = random.choice(CATEGORIES)
        price = round(random.uniform(3.99, 499.99), 2)
        stock = random.randint(0, 5000)
        rows.append(
            f"({i}, {sql_str(name)}, {sql_str(cat)}, {price}, {stock})"
        )
    write_batched_insert(
        f, "products",
        "product_id, product_name, category, unit_price, stock_qty",
        rows,
    )
    return list(range(1, n + 1))


# --------------------------------------------------------------------------
# orders / order_items — grown until the file hits the target size
# --------------------------------------------------------------------------

def grow_orders_and_items(f, customer_ids, employee_ids, product_ids,
                           target_bytes, orders_per_batch=100):
    f.write("\n-- orders + order_items, grown to fill target size\n")
    order_id = 1
    item_id = 1
    while f.tell() < target_bytes:
        order_rows = []
        item_rows = []
        for _ in range(orders_per_batch):
            cust = random.choice(customer_ids)
            emp = random.choice(employee_ids)
            odate = rand_date(date(2022, 1, 1), date(2026, 8, 15))
            status = random.choice(STATUSES)
            order_rows.append(
                f"({order_id}, {cust}, {emp}, {sql_str(odate)}, {sql_str(status)})"
            )
            for _ in range(random.randint(1, 6)):
                prod = random.choice(product_ids)
                qty = random.randint(1, 12)
                price = round(random.uniform(3.99, 499.99), 2)
                item_rows.append(
                    f"({item_id}, {order_id}, {prod}, {qty}, {price})"
                )
                item_id += 1
            order_id += 1

        write_batched_insert(
            f, "orders",
            "order_id, customer_id, employee_id, order_date, status",
            order_rows,
        )
        write_batched_insert(
            f, "order_items",
            "order_item_id, order_id, product_id, quantity, unit_price",
            item_rows,
        )
    return order_id - 1, item_id - 1


# --------------------------------------------------------------------------
# the unhelpful queries
# --------------------------------------------------------------------------

UNHELPFUL_QUERIES = [
    (
        "The Kitchen Sink",
        "Five-way join, zero filters, ORDER BY six columns using mixed "
        "ascending/descending sorts nobody asked for.",
        """SELECT c.full_name, c.city, o.order_id, o.order_date, p.product_name,
       oi.quantity, (oi.quantity * oi.unit_price) AS line_total,
       e.full_name AS handled_by
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p ON p.product_id = oi.product_id
JOIN employees e ON e.employee_id = o.employee_id
ORDER BY c.city, c.full_name, o.order_date DESC, p.category,
         p.product_name, oi.quantity DESC;"""
    ),
    (
        "Correlated Subqueries Instead Of A Join",
        "Every column is its own round trip. Classic N+1-in-SQL.",
        """SELECT o.order_id,
       (SELECT c.full_name FROM customers c
         WHERE c.customer_id = o.customer_id) AS customer_name,
       (SELECT SUM(oi.quantity * oi.unit_price) FROM order_items oi
         WHERE oi.order_id = o.order_id) AS order_total,
       (SELECT COUNT(*) FROM order_items oi2
         WHERE oi2.order_id = o.order_id) AS item_count
FROM orders o
ORDER BY order_total DESC;"""
    ),
    (
        "Function-Wrapped WHERE, Wildcards Both Ends",
        "UPPER()/LOWER()/SUBSTR() on every row guarantees no index could "
        "ever help, even if one existed.",
        """SELECT * FROM customers
WHERE UPPER(city) LIKE '%ON%'
  AND LOWER(SUBSTR(email,1,1)) BETWEEN 'a' AND 'm';"""
    ),
    (
        "Old-Style Comma Join With Bolted-On DISTINCT",
        "No explicit JOIN syntax, implicit cross product cleaned up "
        "after the fact with DISTINCT.",
        """SELECT DISTINCT c.customer_id, c.full_name, c.city, p.category
FROM customers c, orders o, order_items oi, products p
WHERE o.customer_id = c.customer_id
  AND oi.order_id = o.order_id
  AND oi.product_id = p.product_id;"""
    ),
    (
        "Three-Level Self-Join Org Chart",
        "Employee, manager, and manager's manager, purely for the "
        "pleasure of three LEFT JOINs on one table.",
        """SELECT e1.full_name AS employee, e2.full_name AS manager,
       e3.full_name AS director
FROM employees e1
LEFT JOIN employees e2 ON e2.employee_id = e1.manager_id
LEFT JOIN employees e3 ON e3.employee_id = e2.manager_id
ORDER BY director, manager, employee;"""
    ),
    (
        "HAVING Threshold Recomputed Per Group",
        "The 'average category revenue' should be one constant. Instead "
        "it's a derived subquery re-evaluated against every group.",
        """SELECT p.category, COUNT(*) AS items_sold,
       SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category
HAVING SUM(oi.quantity * oi.unit_price) > (
    SELECT AVG(sub.cat_revenue) FROM (
        SELECT p2.category, SUM(oi2.quantity * oi2.unit_price) AS cat_revenue
        FROM order_items oi2 JOIN products p2 ON p2.product_id = oi2.product_id
        GROUP BY p2.category
    ) sub
)
ORDER BY revenue DESC;"""
    ),
    (
        "Anti-Join Via LEFT JOIN / IS NULL",
        "Finds customers with no non-cancelled order, the long way "
        "round instead of NOT EXISTS.",
        """SELECT c.customer_id, c.full_name
FROM customers c
LEFT JOIN orders o
  ON o.customer_id = c.customer_id AND o.status <> 'CANCELLED'
WHERE o.order_id IS NULL
ORDER BY c.full_name;"""
    ),
    (
        "UNION Where UNION ALL (Or Just OR) Would Do",
        "Forces a full dedup/sort across three overlapping row sets.",
        """SELECT * FROM orders WHERE status = 'PENDING'
UNION
SELECT * FROM orders WHERE status = 'SHIPPED'
UNION
SELECT * FROM orders
WHERE customer_id IN (SELECT customer_id FROM customers WHERE loyalty_tier = 'GOLD')
ORDER BY order_date;"""
    ),
    (
        "Four-Deep Nested IN Subqueries",
        "Each level re-scans instead of joining once.",
        """SELECT * FROM products
WHERE product_id IN (
    SELECT product_id FROM order_items WHERE order_id IN (
        SELECT order_id FROM orders WHERE customer_id IN (
            SELECT customer_id FROM customers WHERE city IN (
                SELECT city FROM customers WHERE loyalty_tier = 'PLATINUM'
            )
        )
    )
);"""
    ),
    (
        "CASE-Expression Sort Plus String-Concat Sort Key",
        "Sorts by a computed CASE, then by a concatenated string nobody "
        "indexed because you can't.",
        """SELECT o.order_id, o.status, c.full_name, o.order_date
FROM orders o JOIN customers c ON c.customer_id = o.customer_id
ORDER BY
  CASE o.status
    WHEN 'CANCELLED' THEN 3
    WHEN 'RETURNED' THEN 2
    ELSE 1
  END,
  c.city || '-' || c.full_name,
  o.order_date DESC;"""
    ),
    (
        "The Accidental Cross Join",
        "customers and employees share no relationship whatsoever. "
        "This joins everyone to everyone and hopes WHERE saves it.",
        """SELECT c.full_name, e.full_name, e.department
FROM customers c, employees e
WHERE c.city = 'Glasgow'
ORDER BY e.department;"""
    ),
    (
        "SELECT-List Full Of Aggregate Subqueries",
        "Three independent aggregate subqueries per customer row instead "
        "of one GROUP BY.",
        """SELECT c.customer_id, c.full_name,
  (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.customer_id) AS order_count,
  (SELECT COALESCE(SUM(oi.quantity*oi.unit_price),0)
     FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
     WHERE o.customer_id = c.customer_id) AS lifetime_value,
  (SELECT MAX(o.order_date) FROM orders o WHERE o.customer_id = c.customer_id) AS last_order
FROM customers c
ORDER BY lifetime_value DESC;"""
    ),
]


def write_queries(f):
    f.write("\n\n-- ==========================================================================\n")
    f.write("-- UNHELPFUL QUERIES\n")
    f.write("-- Every one of these is a legitimate question answered the worst way\n")
    f.write("-- the schema and SQL allow. Use them to make a planner cry.\n")
    f.write("-- ==========================================================================\n")
    for n, (title, blurb, sql) in enumerate(UNHELPFUL_QUERIES, 1):
        f.write(f"\n-- [{n}] {title}\n-- {blurb}\n")
        f.write(sql.rstrip())
        if not sql.rstrip().endswith(";"):
            f.write(";")
        f.write("\n")


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--outfile", default="sql_torture_test.txt")
    ap.add_argument("--target-mb", type=float, default=5.0,
                     help="approximate size of the data section, in MB")
    ap.add_argument("--customers", type=int, default=2000)
    ap.add_argument("--employees", type=int, default=120)
    ap.add_argument("--products", type=int, default=600)
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument(
        "--no-fk",
        action="store_true",
        help="omit REFERENCES clauses so DDL/data loading can be tested before FK support",
    )
    args = ap.parse_args()

    if args.seed is not None:
        random.seed(args.seed)

    target_bytes = int(args.target_mb * 1024 * 1024)

    with open(args.outfile, "w") as f:
        f.write("-- Generated by sql_torture_generator.py\n")
        f.write(
            f"-- target size: {args.target_mb} MB | seed: {args.seed} | "
            f"foreign keys: {'off' if args.no_fk else 'on'}\n\n"
        )
        f.write(schema_sql(with_foreign_keys=not args.no_fk))

        customer_ids = write_customers(f, args.customers)
        employee_ids = write_employees(f, args.employees)
        product_ids = write_products(f, args.products)

        n_orders, n_items = grow_orders_and_items(
            f, customer_ids, employee_ids, product_ids, target_bytes
        )

        write_queries(f)

    import os
    final_size = os.path.getsize(args.outfile)
    print(f"wrote {args.outfile}")
    print(f"  customers   : {args.customers}")
    print(f"  employees   : {args.employees}")
    print(f"  products    : {args.products}")
    print(f"  orders      : {n_orders}")
    print(f"  order_items : {n_items}")
    print(f"  foreign keys: {'off' if args.no_fk else 'on'}")
    print(f"  queries     : {len(UNHELPFUL_QUERIES)}")
    print(f"  final size  : {final_size / (1024*1024):.2f} MB")


if __name__ == "__main__":
    main()
