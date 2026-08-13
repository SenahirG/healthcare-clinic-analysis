USE HealthcareClinicDB;
GO

SELECT TOP 10 *
FROM dbo.PatientVisits_Raw;




USE HealthcareClinicDB;
GO

-- Dataset size and coverage
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT patient_id) AS unique_patients,
    COUNT(DISTINCT visit_id) AS unique_visit_ids,
    MIN(visit_date) AS earliest_visit,
    MAX(visit_date) AS latest_visit
FROM dbo.PatientVisits_Raw;

-- Missing-value check
SELECT
    SUM(CASE WHEN visit_id IS NULL THEN 1 ELSE 0 END) AS missing_visit_id,
    SUM(CASE WHEN patient_id IS NULL THEN 1 ELSE 0 END) AS missing_patient_id,
    SUM(CASE WHEN visit_date IS NULL THEN 1 ELSE 0 END) AS missing_visit_date,
    SUM(CASE WHEN date_of_birth IS NULL THEN 1 ELSE 0 END) AS missing_dob,
    SUM(CASE WHEN patient_age IS NULL THEN 1 ELSE 0 END) AS missing_age,
    SUM(CASE WHEN patient_sex IS NULL THEN 1 ELSE 0 END) AS missing_sex,
    SUM(CASE WHEN icd_code IS NULL THEN 1 ELSE 0 END) AS missing_icd,
    SUM(CASE WHEN cpt_code IS NULL THEN 1 ELSE 0 END) AS missing_cpt
FROM dbo.PatientVisits_Raw;

-- Confirm that leading-zero CPT codes were preserved
SELECT *
FROM dbo.PatientVisits_Raw
WHERE cpt_code LIKE '0%';



USE HealthcareClinicDB;
GO

CREATE OR ALTER VIEW dbo.vw_PatientVisits_Clean
AS
SELECT
    r.visit_id,
    r.patient_id,
    r.visit_date,
    r.date_of_birth,
    r.patient_age AS reported_age,
    r.patient_sex,
    r.icd_code,
    r.cpt_code,
    a.calculated_age,
    CASE
        WHEN a.calculated_age <= 17 THEN '0-17'
        WHEN a.calculated_age <= 39 THEN '18-39'
        WHEN a.calculated_age <= 64 THEN '40-64'
        ELSE '65+'
    END AS age_band,
    CASE
        WHEN r.patient_age = a.calculated_age THEN 'Match'
        ELSE 'Mismatch'
    END AS age_check
FROM dbo.PatientVisits_Raw AS r
CROSS APPLY
(
    SELECT
        DATEDIFF(YEAR, r.date_of_birth, r.visit_date)
        - CASE
            WHEN DATEADD(
                    YEAR,
                    DATEDIFF(YEAR, r.date_of_birth, r.visit_date),
                    r.date_of_birth
                 ) > r.visit_date
            THEN 1
            ELSE 0
          END AS calculated_age
) AS a;
GO




SELECT TOP 20 *
FROM dbo.vw_PatientVisits_Clean;

SELECT
    age_check,
    COUNT(*) AS row_count
FROM dbo.vw_PatientVisits_Clean
GROUP BY age_check;




ALTER TABLE dbo.PatientVisits_Raw
ADD source_row_id INT IDENTITY(1,1) NOT NULL;
GO




USE HealthcareClinicDB;
GO

CREATE OR ALTER VIEW dbo.vw_PatientVisits_Clean
AS
SELECT
    r.source_row_id,
    r.visit_id,
    r.patient_id,
    r.visit_date,
    r.date_of_birth,
    r.patient_age AS reported_age,
    r.patient_sex,
    r.icd_code,
    r.cpt_code,
    a.calculated_age,
    CASE
        WHEN a.calculated_age <= 17 THEN '0-17'
        WHEN a.calculated_age <= 39 THEN '18-39'
        WHEN a.calculated_age <= 64 THEN '40-64'
        ELSE '65+'
    END AS age_band,
    CASE
        WHEN r.patient_age = a.calculated_age THEN 'Match'
        ELSE 'Mismatch'
    END AS age_check
FROM dbo.PatientVisits_Raw AS r
CROSS APPLY
(
    SELECT
        DATEDIFF(YEAR, r.date_of_birth, r.visit_date)
        - CASE
            WHEN DATEADD(
                    YEAR,
                    DATEDIFF(YEAR, r.date_of_birth, r.visit_date),
                    r.date_of_birth
                 ) > r.visit_date
            THEN 1
            ELSE 0
          END AS calculated_age
) AS a;
GO



/*SELECT TOP 10 *
FROM dbo.vw_PatientVisits_Clean
ORDER BY source_row_id;
*/

SELECT COL_LENGTH(
    'dbo.PatientVisits_Raw',
    'source_row_id'
) AS column_length;



SELECT TOP 10
    source_row_id,
    visit_id,
    patient_id
FROM dbo.PatientVisits_Raw
ORDER BY source_row_id;




USE HealthcareClinicDB;
GO

CREATE OR ALTER VIEW dbo.vw_Patient_Profile
AS
WITH RankedPatients AS
(
    SELECT
        patient_id,
        visit_date,
        date_of_birth,
        patient_sex,
        calculated_age,
        age_band,
        ROW_NUMBER() OVER
        (
            PARTITION BY patient_id
            ORDER BY source_row_id
        ) AS row_num
    FROM dbo.vw_PatientVisits_Clean
)
SELECT
    patient_id,
    visit_date,
    date_of_birth,
    patient_sex,
    calculated_age,
    age_band
FROM RankedPatients
WHERE row_num = 1;
GO




-- Confirm one row per patient
SELECT COUNT(*) AS patient_count
FROM dbo.vw_Patient_Profile;

-- Patient population by age band
SELECT
    age_band,
    COUNT(*) AS patient_count
FROM dbo.vw_Patient_Profile
GROUP BY age_band
ORDER BY
    CASE age_band
        WHEN '0-17' THEN 1
        WHEN '18-39' THEN 2
        WHEN '40-64' THEN 3
        WHEN '65+' THEN 4
    END;




    USE HealthcareClinicDB;
GO

SELECT TOP 10
    icd_code,
    COUNT(*) AS diagnosis_events
FROM dbo.vw_PatientVisits_Clean
GROUP BY icd_code
ORDER BY
    diagnosis_events DESC,
    icd_code ASC;



WITH TopDiagnoses AS
(
    SELECT TOP 10
        icd_code,
        COUNT(*) AS diagnosis_events
    FROM dbo.vw_PatientVisits_Clean
    GROUP BY icd_code
    ORDER BY
        diagnosis_events DESC,
        icd_code ASC
)
SELECT
    c.icd_code,
    SUM(CASE WHEN c.age_band = '0-17' THEN 1 ELSE 0 END) AS age_0_17,
    SUM(CASE WHEN c.age_band = '18-39' THEN 1 ELSE 0 END) AS age_18_39,
    SUM(CASE WHEN c.age_band = '40-64' THEN 1 ELSE 0 END) AS age_40_64,
    SUM(CASE WHEN c.age_band = '65+' THEN 1 ELSE 0 END) AS age_65_plus,
    COUNT(*) AS total_events
FROM dbo.vw_PatientVisits_Clean AS c
INNER JOIN TopDiagnoses AS t
    ON c.icd_code = t.icd_code
GROUP BY c.icd_code
ORDER BY
    total_events DESC,
    c.icd_code ASC;




WITH TopDiagnoses AS
(
    SELECT TOP 10
        icd_code,
        COUNT(*) AS diagnosis_events
    FROM dbo.vw_PatientVisits_Clean
    GROUP BY icd_code
    ORDER BY
        diagnosis_events DESC,
        icd_code ASC
)
SELECT
    c.icd_code,
    SUM(CASE WHEN c.patient_sex = 'Female' THEN 1 ELSE 0 END) AS female_events,
    SUM(CASE WHEN c.patient_sex = 'Male' THEN 1 ELSE 0 END) AS male_events,
    COUNT(*) AS total_events
FROM dbo.vw_PatientVisits_Clean AS c
INNER JOIN TopDiagnoses AS t
    ON c.icd_code = t.icd_code
GROUP BY c.icd_code
ORDER BY
    total_events DESC,
    c.icd_code ASC;




-- Events per patient
WITH PatientUtilization AS
(
    SELECT
        patient_id,
        COUNT(*) AS visit_event_count
    FROM dbo.vw_PatientVisits_Clean
    GROUP BY patient_id
)
SELECT
    COUNT(*) AS total_patients,
    SUM(visit_event_count) AS total_visit_events,
    CAST(AVG(CAST(visit_event_count AS DECIMAL(10,2))) AS DECIMAL(10,2))
        AS average_events_per_patient,
    SUM(CASE WHEN visit_event_count >= 4 THEN 1 ELSE 0 END)
        AS high_utilizer_count
FROM PatientUtilization;





SELECT
    patient_id,
    COUNT(*) AS visit_event_count
FROM dbo.vw_PatientVisits_Clean
GROUP BY patient_id
HAVING COUNT(*) >= 4
ORDER BY
    visit_event_count DESC,
    patient_id ASC;



SELECT TOP 10 WITH TIES
    cpt_code,
    COUNT(*) AS procedure_events
FROM dbo.vw_PatientVisits_Clean
GROUP BY cpt_code
ORDER BY COUNT(*) DESC;



WITH RankedProcedures AS
(
    SELECT
        cpt_code,
        COUNT(*) AS procedure_events,
        DENSE_RANK() OVER (
            ORDER BY COUNT(*) DESC
        ) AS frequency_rank
    FROM dbo.vw_PatientVisits_Clean
    GROUP BY cpt_code
)
SELECT
    cpt_code,
    procedure_events,
    frequency_rank
FROM RankedProcedures
WHERE frequency_rank <= 4
ORDER BY
    procedure_events DESC,
    cpt_code ASC;