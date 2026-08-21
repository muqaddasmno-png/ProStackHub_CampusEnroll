# CampusEnroll — Design Notes

## 1. Entities & Relationships

| Entity | Purpose |
|---|---|
| **Students** | One row per student. |
| **Instructors** | One row per instructor. |
| **Courses** | One row per course offering (catalog-level, not per-section). |
| **Enrollments** | Associative entity resolving the Students↔Courses M:N relationship, carrying attributes (Semester, Grade, EnrollmentDate). |
| **Prerequisites** | Associative entity resolving a **self-referencing** M:N relationship on Courses (a course can have many prerequisites; a course can be the prerequisite for many other courses). |

**Cardinalities**
- Students 1 — N Enrollments
- Courses 1 — N Enrollments
- Instructors 1 — N Courses (0..N — a course may have no instructor assigned yet)
- Courses N — N Courses (via Prerequisites)

## 2. Normalization (3NF)

- **1NF**: every column holds a single atomic value. Prerequisites are *not* stored as a comma-separated list on Courses — they're separate rows. GPA-style grades are computed, not stored as pre-joined text.
- **2NF**: `Enrollments` has a composite natural key (StudentID, CourseID, Semester), enforced as a UNIQUE constraint over a surrogate `EnrollmentID` PK. Every other column (Grade, EnrollmentDate) depends on the *whole* combination, not just StudentID or just CourseID alone.
- **3NF**: no transitive dependencies. For example, `Department` is stored on `Courses`, not derived by joining through `Instructors` — a course's department is a fact about the course itself (it doesn't change if the instructor changes, and some courses are cross-listed under a different department from their instructor's home department).
- Using a **surrogate key** (`CourseID`) rather than `CourseCode` as the join key throughout means `CourseCode` can be changed (e.g. catalog renumbering) without cascading updates through every relationship — `CourseCode` is just a natural/business key with a UNIQUE constraint.

## 3. Why Prerequisites is its own table (not a repeating group)

A naive design might add `Prereq1, Prereq2, Prereq3` columns to `Courses`. This breaks 1NF, caps how many prerequisites a course can have, and makes querying multi-level chains (A requires B, B requires A) essentially impossible in plain SQL. Modeling `Prerequisites(CourseID, PrerequisiteCourseID)` as an associative table means:
- A course can have any number of prerequisites (0 to N).
- Multi-level chains are traversed with a **recursive CTE** (see `sql/03_queries.sql`, Q1) rather than duplicated data.
- A `CHECK (CourseID <> PrerequisiteCourseID)` constraint prevents a course from being its own prerequisite at the direct level. (Longer cycles, e.g. A→B→A, are a data-integrity policy decision left to application logic / a periodic audit query, since a CHECK constraint can't see other rows.)

## 4. ON DELETE / ON UPDATE justification

| FK | Rule | Why |
|---|---|---|
| `Courses.InstructorID → Instructors` | `ON DELETE SET NULL` | An instructor leaving the university shouldn't delete the course they used to teach — the course persists, unassigned, until reallocated. |
| `Prerequisites.CourseID → Courses` | `ON DELETE CASCADE` | If a course is removed from the catalog entirely, any prerequisite rule *for* that course is meaningless and should go with it. |
| `Prerequisites.PrerequisiteCourseID → Courses` | `ON DELETE CASCADE` | Same logic in the other direction — a course can't remain listed as a requirement for something once it no longer exists. |
| `Enrollments.StudentID → Students` | `ON DELETE CASCADE` | If a student record is purged (e.g. GDPR-style deletion request), their enrollment history should go with them rather than leaving orphaned rows. |
| `Enrollments.CourseID → Courses` | `ON DELETE RESTRICT` | Enrollments carry **grade history** — real academic records. A course should never be deletable while it still has student transcripts attached; the registrar would need to archive/reassign those records first. This is the one relationship where "delete blocked" is the *safer* default. |

All `ON UPDATE` rules are `CASCADE`, since surrogate keys (`StudentID`, `CourseID`, `InstructorID`) are auto-incrementing integers that are never meant to change in practice — this is a defensive default rather than an expected code path.

## 5. Multi-level prerequisite chains without duplication

Example seeded chain: `CS401 ← CS301 ← CS201 ← CS102 ← CS101` (Distributed Systems transitively requires Intro to Programming, four levels down). This is stored as **four single-hop rows** in `Prerequisites`:

```
(CS401, CS301)
(CS301, CS201)
(CS201, CS102)
(CS102, CS101)
```

No row duplicates any (CourseID, PrerequisiteCourseID) pair, and the full chain is reconstructed on demand via `WITH RECURSIVE` (tested and verified in `sql/03_queries.sql`, Q1 and Q6).

