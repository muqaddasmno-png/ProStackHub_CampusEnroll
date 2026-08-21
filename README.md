# CampusEnroll — University ERP Database

**ProStackHub SQL & DBMS Internship — Task 2**

A normalized (3NF) university enrollment database covering Students, Courses,
Instructors, Enrollments, and a self-referencing many-to-many Prerequisites
relationship supporting multi-level prerequisite chains.

## Repo structure

```
CampusEnroll/
├── sql/
│   ├── 01_schema.sql        -- CREATE TABLE statements (MySQL 8.0+)
│   ├── 02_seed_data.sql     -- 50 students, 20 courses, 6 instructors, 231 enrollments
│   └── 03_queries.sql       -- 9 demo/verification queries
├── diagrams/
│   ├── er_diagram.dot       -- Graphviz source
│   └── er_diagram.png       -- Rendered ER diagram
├── docs/
│   ├── DESIGN_NOTES.md      -- Normalization + ON DELETE/UPDATE justification
│   └── sample_query_output.txt
└── README.md
```

## How to run

```bash
mysql -u root -p < sql/01_schema.sql
mysql -u root -p < sql/02_seed_data.sql
mysql -u root -p < sql/03_queries.sql
```

Or open each file in MySQL Workbench / your client of choice and run in order:
schema → seed data → queries.

## What this demonstrates

- **Schema design**: 5 entities, normalized to 3NF (see `docs/DESIGN_NOTES.md` §2).
- **Self-referencing M:N relationship**: `Prerequisites(CourseID, PrerequisiteCourseID)`
  models course prerequisites without duplicating data, however deep the chain.
- **Multi-level chain traversal**: a `WITH RECURSIVE` CTE walks prerequisite
  chains of arbitrary depth (see `sql/03_queries.sql`, Q1 and Q6).
- **Justified referential integrity**: every foreign key's `ON DELETE` choice
  is explained in `docs/DESIGN_NOTES.md` §4 (CASCADE where dependent data is
  meaningless without the parent, RESTRICT where deleting would destroy real
  academic records, SET NULL where the relationship is optional).
- **Realistic seed scale**: 50 students, 20 courses across 4 departments,
  231 enrollment records, 16 prerequisite relationships including a 4-level
  deep chain.



