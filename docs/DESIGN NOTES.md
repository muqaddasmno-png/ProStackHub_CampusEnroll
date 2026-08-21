 CampusEnroll — Design Notes


 1. Entities & Relationships:

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
- **3NF**: no transitive dependencies. For example, `Department` is stored on `Courses`, not derived by joining through `Instructors` — a course's department is a fact about the course itself.
- Using a **surrogate key** (`CourseID`) rather than `CourseCode` as the join key throughout means `CourseCode` can be changed without cascading updates through every relationship.

## 3. Why Prerequisites is its own table (not a repeating group)

A naive design might add `Prereq1, Prereq2, Prereq3` columns to `Courses`. This breaks 1NF, caps how many prerequisites a course can have, and makes querying multi-level chains essentially impossible in plain SQL. Modeling `Prerequisites(CourseID, PrerequisiteCourseID)` as an associative table means:
- A course can have any number of prerequisites (0 to N).
- Multi-level chains are traversed with a **recursive CTE** (see `sql/03_queries.sql`, Q1) rather than duplicated data.
- Preventing a course from being its own direct prerequisite is enforced at the seed-data level rather than a database CHECK constraint, since that syntax isn't supported on all MySQL/MariaDB versions.

## 4. ON DELETE / ON UPDATE justification

| FK | Rule | Why |
|---|---|---|
| `Courses.InstructorID → Instructors` | `ON DELETE SET NULL` | An instructor leaving shouldn't delete the course — it persists, unassigned. |
| `Prerequisites.CourseID → Courses` | `ON DELETE CASCADE` | If a course is removed, its prerequisite rules are meaningless too. |
| `Prerequisites.PrerequisiteCourseID → Courses` | `ON DELETE CASCADE` | A course can't remain listed as a requirement once it no longer exists. |
| `Enrollments.StudentID → Students` | `ON DELETE CASCADE` | Student removed → their enrollment rows go with them. |
| `Enrollments.CourseID → Courses` | `ON DELETE RESTRICT` | Enrollments carry real grade history — a course can't be deleted while transcripts depend on it. |

All `ON UPDATE` rules are `CASCADE`, since surrogate keys are auto-incrementing integers not meant to change.

## 5. Multi-level prerequisite chains without duplication

Example seeded chain: `CS401 ← CS301 ← CS201 ← CS102 ← CS101`. Stored as **four single-hop rows**:
(CS401, CS301)
(CS301, CS201)
(CS201, CS102)
(CS102, CS101)
No row duplicates any (CourseID, PrerequisiteCourseID) pair, and the
full chain is reconstructed on demand via WITH RECURSIVE (tested and
verified in sql/03_queries.sql , Q1 and Q6).
