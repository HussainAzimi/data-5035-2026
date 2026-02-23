
-- DATA QUALITY TEST SCENARIOS (20+ Tests)

USE SCHEMA data5035.spring26;

-- TEST 1: dq_reversed_name (10 test cases)
CREATE OR REPLACE TEMPORARY TABLE test_reversed_name (name VARCHAR, expected INT NOT NULL);
INSERT INTO test_reversed_name VALUES
    ('Smith, John', 1),
    ('Doe, Jane', 1),
    ('John Smith', 0),
    ('Jane Doe', 0),
    ('O''Connor, Mary', 1),
    ('Mary O''Connor', 0),
    ('Van Der Berg, Jan', 1),
    ('Jan Van Der Berg', 0),
    ('', 0),
    (NULL, 0);

SELECT
    'dq_reversed_name' AS test_name,
    name AS input_value,
    CASE WHEN CONTAINS(name, ',') THEN 1 ELSE 0 END AS actual,
    expected,
    actual = expected AS match
FROM test_reversed_name;

-- TEST 2: dq_invalid_phone_format (11 test cases)
CREATE OR REPLACE TEMPORARY TABLE test_phone_format (phone VARCHAR, expected INT NOT NULL);
INSERT INTO test_phone_format VALUES
    ('5551234567', 0),
    ('555-123-4567', 0),
    ('(555) 123-4567', 0),
    ('555.123.4567', 0),
    ('555 123 4567', 0),
    ('123456789', 1),
    ('12345678901', 1),
    ('+1-555-123-4567', 1),
    ('555-1234', 1),
    ('', 1),
    ('555-123-4567 ext 123', 1);

SELECT
    'dq_invalid_phone_format' AS test_name,
    phone AS input_value,
    CASE WHEN LENGTH(REGEXP_REPLACE(phone, '[^0-9]', '')) != 10 THEN 1 ELSE 0 END AS actual,
    expected,
    actual = expected AS match
FROM test_phone_format;

-- TEST 3: dq_invalid_zip (9 test cases)
CREATE OR REPLACE TEMPORARY TABLE test_zip (zip VARCHAR, expected INT NOT NULL);
INSERT INTO test_zip VALUES
    ('12345', 0),
    ('12345-6789', 0),
    ('00501', 0),
    ('99999', 0),
    ('1234', 1),
    ('123', 1),
    ('12', 1),
    ('1', 1),
    ('0', 1);

SELECT
    'dq_invalid_zip' AS test_name,
    zip AS input_value,
    CASE WHEN LENGTH(CAST(zip AS VARCHAR)) < 5 THEN 1 ELSE 0 END AS actual,
    expected,
    actual = expected AS match
FROM test_zip;

-- COMBINED RESULTS: All 30 tests in one result set
SELECT 'dq_reversed_name' AS test_name, name AS input_value, 
       CASE WHEN CONTAINS(name, ',') THEN 1 ELSE 0 END AS actual, expected, 
       actual = expected AS match 
FROM test_reversed_name
UNION ALL
SELECT 'dq_invalid_phone_format', phone, 
       CASE WHEN LENGTH(REGEXP_REPLACE(phone, '[^0-9]', '')) != 10 THEN 1 ELSE 0 END, expected, 
       CASE WHEN LENGTH(REGEXP_REPLACE(phone, '[^0-9]', '')) != 10 THEN 1 ELSE 0 END = expected 
FROM test_phone_format
UNION ALL
SELECT 'dq_invalid_zip', zip, 
       CASE WHEN LENGTH(CAST(zip AS VARCHAR)) < 5 THEN 1 ELSE 0 END, expected, 
       CASE WHEN LENGTH(CAST(zip AS VARCHAR)) < 5 THEN 1 ELSE 0 END = expected 
FROM test_zip
ORDER BY test_name, match, input_value;
