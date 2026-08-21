CREATE DATABASE campus_enroll CHARACTER SET utf8mb4;
USE campus_enroll;

CREATE TABLE Students (
    StudentID       INT AUTO_INCREMENT PRIMARY KEY,
    FirstName       VARCHAR(50)  NOT NULL,
    LastName        VARCHAR(50)  NOT NULL,
    Email           VARCHAR(100) NOT NULL UNIQUE,
    EnrollmentYear  YEAR         NOT NULL,
    Major           VARCHAR(80)  NOT NULL,
    CreatedAt       TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
CREATE TABLE Instructors (
    InstructorID    INT AUTO_INCREMENT PRIMARY KEY,
    FirstName       VARCHAR(50)  NOT NULL,
    LastName        VARCHAR(50)  NOT NULL,
    Email           VARCHAR(100) NOT NULL UNIQUE,
    Department      VARCHAR(80)  NOT NULL
) ENGINE=InnoDB;
CREATE TABLE Courses (
    CourseID        INT AUTO_INCREMENT PRIMARY KEY,
    CourseCode      VARCHAR(10)  NOT NULL UNIQUE,   -- e.g. 'CS101'
    CourseName      VARCHAR(120) NOT NULL,
    Credits         TINYINT      NOT NULL, 
    Department      VARCHAR(80)  NOT NULL,
    InstructorID    INT          NULL,
    FOREIGN KEY (InstructorID) REFERENCES Instructors(InstructorID)
        ON DELETE SET NULL   -- an instructor leaving shouldn't delete the course;
        ON UPDATE CASCADE    -- it just becomes unassigned pending reallocation
) ENGINE=InnoDB;
CREATE TABLE Prerequisites (
    CourseID             INT NOT NULL,
    PrerequisiteCourseID INT NOT NULL,
    PRIMARY KEY (CourseID, PrerequisiteCourseID),
    FOREIGN KEY (CourseID) REFERENCES Courses(CourseID)
        ON DELETE CASCADE   
        ON UPDATE CASCADE,
    FOREIGN KEY (PrerequisiteCourseID) REFERENCES Courses(CourseID)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Enrollments (
    EnrollmentID    INT AUTO_INCREMENT PRIMARY KEY,
    StudentID       INT         NOT NULL,
    CourseID        INT         NOT NULL,
    Semester        VARCHAR(20) NOT NULL,   
    EnrollmentDate  DATE        NOT NULL,
    Grade           CHAR(2)     NULL,       
    UNIQUE KEY uq_student_course_semester (StudentID, CourseID, Semester),
    FOREIGN KEY (StudentID) REFERENCES Students(StudentID)
        ON DELETE CASCADE    
        ON UPDATE CASCADE,
    FOREIGN KEY (CourseID) REFERENCES Courses(CourseID)
        ON DELETE RESTRICT 
        ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_enrollments_course ON Enrollments(CourseID);
CREATE INDEX idx_enrollments_student ON Enrollments(StudentID);
CREATE INDEX idx_courses_department ON Courses(Department);
