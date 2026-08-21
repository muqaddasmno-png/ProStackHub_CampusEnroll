USE campus_enroll;
 Q1: Full multi-level prerequisite chain for a given course
-- (Recursive CTE — handles chains of any depth: A <- B <- C <- D ...)
-- Example: everything CS401 (Distributed Systems) transitively requires
-- ---------------------------------------------------------------------
WITH RECURSIVE PrereqChain AS (
    SELECT CourseID, PrerequisiteCourseID, 1 AS Depth
    FROM Prerequisites
    WHERE CourseID = (SELECT CourseID FROM Courses WHERE CourseCode = 'CS401')

    UNION ALL

    SELECT p.CourseID, p.PrerequisiteCourseID, pc.Depth + 1
    FROM Prerequisites p
    JOIN PrereqChain pc ON p.CourseID = pc.PrerequisiteCourseID
)
SELECT
    pc.Depth,
    c1.CourseCode AS ForCourse,
    c2.CourseCode AS RequiresPrereq,
    c2.CourseName AS PrereqName
FROM PrereqChain pc
JOIN Courses c1 ON c1.CourseID = pc.CourseID
JOIN Courses c2 ON c2.CourseID = pc.PrerequisiteCourseID
ORDER BY pc.Depth;


 Q2: Direct prerequisites for every course (flat listing)
-- ---------------------------------------------------------------------
SELECT
    c.CourseCode        AS Course,
    GROUP_CONCAT(p_c.CourseCode SEPARATOR ', ') AS DirectPrerequisites
FROM Courses c
LEFT JOIN Prerequisites p ON p.CourseID = c.CourseID
LEFT JOIN Courses p_c ON p_c.CourseID = p.PrerequisiteCourseID
GROUP BY c.CourseID, c.CourseCode
ORDER BY c.CourseCode;


Q3: Enrollment-integrity check — students taking a course without
 having previously completed (grade != F, non-null) its prerequisite.
 Useful as a data-quality audit query for the registrar.
-- ---------------------------------------------------------------------
SELECT
    s.StudentID, s.FirstName, s.LastName,
    c.CourseCode         AS EnrolledIn,
    pc.CourseCode         AS MissingPrerequisite
FROM Enrollments e
JOIN Students s   ON s.StudentID = e.StudentID
JOIN Courses c    ON c.CourseID  = e.CourseID
JOIN Prerequisites p ON p.CourseID = e.CourseID
JOIN Courses pc   ON pc.CourseID = p.PrerequisiteCourseID
WHERE NOT EXISTS (
    SELECT 1 FROM Enrollments e2
    WHERE e2.StudentID = e.StudentID
      AND e2.CourseID  = p.PrerequisiteCourseID
      AND e2.Grade IS NOT NULL
      AND e2.Grade <> 'F'
)
ORDER BY s.LastName, c.CourseCode;


 Q4: Course load and average grade-points per student (GPA-style view)
(Uses a CASE-based grade-to-point mapping; adjust scale as needed)
-- ---------------------------------------------------------------------
SELECT
    s.StudentID,
    s.FirstName, s.LastName,
    COUNT(e.EnrollmentID) AS CoursesTaken,
    ROUND(AVG(
        CASE e.Grade
            WHEN 'A'  THEN 4.0  WHEN 'A-' THEN 3.7
            WHEN 'B+' THEN 3.3  WHEN 'B'  THEN 3.0  WHEN 'B-' THEN 2.7
            WHEN 'C+' THEN 2.3  WHEN 'C'  THEN 2.0
            WHEN 'D'  THEN 1.0  WHEN 'F'  THEN 0.0
            ELSE NULL
        END
    ), 2) AS GPA
FROM Students s
JOIN Enrollments e ON e.StudentID = s.StudentID
GROUP BY s.StudentID, s.FirstName, s.LastName
HAVING COUNT(e.EnrollmentID) > 0
ORDER BY GPA DESC;


Q5: Instructor course-load — how many courses & students each
 instructor is responsible for this catalog
-- ---------------------------------------------------------------------
SELECT
    i.InstructorID,
    CONCAT(i.FirstName, ' ', i.LastName) AS Instructor,
    i.Department,
    COUNT(DISTINCT c.CourseID) AS CoursesTaught,
    COUNT(e.EnrollmentID)      AS TotalStudentEnrollments
FROM Instructors i
LEFT JOIN Courses c ON c.InstructorID = i.InstructorID
LEFT JOIN Enrollments e ON e.CourseID = c.CourseID
GROUP BY i.InstructorID, Instructor, i.Department
ORDER BY TotalStudentEnrollments DESC;


 Q6: Courses with the most "prerequisite depth" (hardest to reach)
 Ranks courses by how many transitive prerequisites they require
-- ---------------------------------------------------------------------
WITH RECURSIVE AllChains AS (
    SELECT CourseID, PrerequisiteCourseID
    FROM Prerequisites

    UNION

    SELECT ac.CourseID, p.PrerequisiteCourseID
    FROM AllChains ac
    JOIN Prerequisites p ON p.CourseID = ac.PrerequisiteCourseID
)
SELECT
    c.CourseCode,
    c.CourseName,
    COUNT(DISTINCT ac.PrerequisiteCourseID) AS TransitivePrereqCount
FROM Courses c
JOIN AllChains ac ON ac.CourseID = c.CourseID
GROUP BY c.CourseID, c.CourseCode, c.CourseName
ORDER BY TransitivePrereqCount DESC;


 Q7: Semester-by-semester enrollment headcount per department
 (aggregation across three linked tables)
-- ---------------------------------------------------------------------
SELECT
    e.Semester,
    c.Department,
    COUNT(e.EnrollmentID) AS Enrollments
FROM Enrollments e
JOIN Courses c ON c.CourseID = e.CourseID
GROUP BY e.Semester, c.Department
ORDER BY e.Semester, Enrollments DESC;


 Q8: Students who have NOT completed any prerequisite chain fully
 (i.e. only ever enrolled in "entry-level" courses — no prereqs)
-- ---------------------------------------------------------------------
SELECT s.StudentID, s.FirstName, s.LastName
FROM Students s
WHERE NOT EXISTS (
    SELECT 1
    FROM Enrollments e
    JOIN Prerequisites p ON p.CourseID = e.CourseID
    WHERE e.StudentID = s.StudentID
)
ORDER BY s.LastName;
