-- Data Engineering - Assignment 02 - Data Profiling and Quality


SELECT
    donation_id,
    name,
    age,
    date_of_birth,
    street_address,
    city,
    state,
    zip,
    phone,
    category,
    organization,
    amount,
    
    -- DQ Issue 1: Various Punctuation (Name Format).
    -- Data is stored as "Last, First" in some records and "First Last" in others.
    -- It prevents the system from recognizing "LastName, FirstName" and "FirstName LastName" as the same entity.
    -- If the name has a comma, we can assume it is in Last, First format.
    -- Flag records where the 'Name' field contains a comma (name,',').
    
    CASE WHEN CONTAINS(name,',')THEN 1 ELSE 0 END AS dq_reversed_name,

    -- DQ Issue 2: Shifted Data (Age vs. DOB Mismatch).
    -- The "AGE" field does not align with the calculated age derived from 'DATE_OF_BIRTH'.
    -- It Leads to unreliable demographic profiling and potential compliance risks.
    -- Calculate age from DOB and flag if the difference from the AGE field exceeds 2 years.
    -- Assumed that current year is 2026.
    -- For 2-digit year parsing: Years > 26 refer to the 1900s,

    CASE
        WHEN ABS(
            age - (
                EXTRACT(YEAR FROM CURRENT_DATE()) - 
                CASE
                    WHEN EXTRACT(YEAR FROM TRY_TO_DATE(date_of_birth)) > EXTRACT(YEAR FROM CURRENT_DATE())
                    THEN EXTRACT(YEAR FROM TRY_TO_DATE(date_of_birth)) - 100
                    ELSE EXTRACT(YEAR FROM TRY_TO_DATE(date_of_birth))
                END 
            )
        ) > 2 THEN 1
        ELSE 0
    END AS dq_age_dob_mismatch,

    -- DQ Issue 3: Imprecise geography - center of ZIP, fake addresses.
    -- ZIP codes contain less than 5 digits in some records.
    -- It leads to prevent accurate mapping and delivery services.
    -- Assumed the ZIP code data should follow the standard US (5-digit) or (5+4) ZIP code format.
    -- Flag all records with ZIP < 5 digits.
    CASE 
        WHEN LENGTH(CAST(ZIP as VARCHAR)) < 5 THEN 1
        ELSE 0
    End AS dq_invalid_zip,

    -- DQ Issue 4: Mixture of code sets (Phone).
    -- Phone number is not a 10-digit numeric standard format.
    -- The presence of international codes, extensions, or missing area codes creates a "Mixture of code sets".
    -- It leads to break automated dialing and SMS system.
    -- Assumed the phone number data should follow the standard US (10-digit) standard format.
    -- Flag all records where the length is not exactly 10 digits.
    
    CASE
        WHEN LENGTH(REGEXP_REPLACE(phone, '[^0-9]', '')) != 10 THEN 1
        ELSE 0
    END AS dq_invalid_phone_format,

    -- DQ Issue 5: Missing personal identifiers.
    -- Records are missing the "Category" identifier, which defines the donor's relationship or interest area.
    -- It could Directly violates the completeness of the donor profile. Without this identifier, marketing cannot be   targeted, and the record cannot be segmented.
    -- Assumed any record without a category cannot be automatically assigned a default and must be flagged for manual review.
    -- Flag all records where the CATEGORY Field is NULL, and empty string, or contains only whitespace.

    CASE 
        WHEN category IS NULL OR TRIM(category) = '' THEN 1
        ELSE 0
    END AS dq_missing_category,

    -- TOTAL ISSUE SCORE
    
    (
        IFF(CONTAINS(name, ','), 1, 0) +
        CASE
            WHEN ABS(
                age - (
                    EXTRACT(YEAR FROM CURRENT_DATE()) - 
                    CASE
                        WHEN EXTRACT(YEAR FROM TRY_TO_DATE(date_of_birth)) > EXTRACT(YEAR FROM CURRENT_DATE())
                        THEN EXTRACT(YEAR FROM TRY_TO_DATE(date_of_birth)) - 100
                        ELSE EXTRACT(YEAR FROM TRY_TO_DATE(date_of_birth))
                    END 
                )
            ) > 2 THEN 1 ELSE 0 
        END +
        IFF(LENGTH(TRIM(CAST(zip AS VARCHAR))) < 5, 1, 0) +
        IFF(LENGTH(REGEXP_REPLACE(phone, '[^0-9]', '')) != 10, 1, 0) +
        IFF(category IS NULL OR TRIM(category) = '', 1, 0)
    ) AS dq_total_issues

FROM
    data5035.spring26.donations
ORDER BY
    dq_total_issues DESC,
    donation_id;


/**
Here’s my summary of what I learned.

I learned that we can't trust data to be perfect, Even simple things like names and phone numbers come in different formats.
My job isn't just to move data, but to "Clean" it so that the business can actually use it.

I learnd how to write safe code. using functions like TRY_TO_DATE is important because it tells the computer: "if you see a date that makes no sense, just skip it and move on," rather than letting one single error stop the entire project from running.

The hardest part wasn't the code. It was logic, like figuring out if a two-digit year(like "25") meant 1925 or 2025. I learned that as a Data Engineer, I have to make smart decisions about how to interpret confusing information.

Instead of just listing every error, I learned to create a "Total Issue Score." This helps the team see exactly which records are the messiest so they can fix the biggest problems first.
**/
