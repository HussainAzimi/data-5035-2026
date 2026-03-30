--- Scenario C: Manufacturing Quality.

--- Q1: Show all batches and their quality test results.
--- Join type: INNER JOIN.
--- Assumptions: Only batches with at least one test are returned, unmatched batches are excluded
SELECT batches.batch_id, quality_tests.test_type, quality_tests.result_type
FROM EXERCISE9.PUBLIC.BATCHES AS batches
JOIN EXERCISE9.PUBLIC.QUALITY_TESTS AS quality_tests 
ON batches.batch_id = quality_tests.batch_id;

--- Q2: Show all batches, including those without tests.
--- Join type: LEFT JOIN.
--- Assumptions: All batches appear, TEST_TYPE and RESULT_TYPE are NULL for batches with no tests.
SELECT batches.batch_id, quality_tests.test_type, quality_tests.result_type
FROM EXERCISE9.PUBLIC.BATCHES AS batches
LEFT JOIN EXERCISE9.PUBLIC.QUALITY_TESTS AS quality_tests
ON batches.batch_id =  quality_tests.batch_id;

--- Q3: Find batches with both failed tests and deviations.
--- Join type: INNER JOIN (chained) + WHERE filter.
--- Assumptions: RESULT_TYPE = 'Fail' indicates a failed test, batch must exist in both QUALITY_TESTS and DEVIATIONS.
SELECT DISTINCT batches.batch_id
FROM EXERCISE9.PUBLIC.BATCHES AS batches
JOIN EXERCISE9.PUBLIC.QUALITY_TESTS AS quality_tests ON batches.batch_id = quality_tests.batch_id
JOIN EXERCISE9.PUBLIC.DEVIATIONS AS deviations ON batches.batch_id = deviations.batch_id 
WHERE quality_tests.result_type = 'Fail';

--- Q4: Show batch-level counts of tests and deviations.
--- Join type: LEFT JOIN (chained) + GROUP BY aggregation.
--- Assumptions: COUNT(DISTINCT) avoids inflated counts from many-to-many join, batches with no tests/deviations show 0.
SELECT batches.batch_id,
       COUNT(DISTINCT quality_tests.test_id) AS TEST_COUNT,
       COUNT(DISTINCT deviations.deviation_id) AS DEVIATION_COUNT
FROM EXERCISE9.PUBLIC.BATCHES batches
LEFT JOIN EXERCISE9.PUBLIC.QUALITY_TESTS quality_tests ON batches.batch_id = quality_tests.batch_id
LEFT JOIN EXERCISE9.PUBLIC.DEVIATIONS deviations ON batches.batch_id = deviations.batch_id
GROUP BY batches.batch_id;

--- Q5: Find batches with no deviations
--- Join type: LEFT JOIN + WHERE IS NULL (Anti-join pattern)
--- Assumptions: A NULL DEVIATION_ID after LEFT JOIN means the batch has zero deviations
SELECT batches.batch_id
FROM EXERCISE9.PUBLIC.BATCHES batches
LEFT JOIN EXERCISE9.PUBLIC.DEVIATIONS as deviations ON batches.batch_id = deviations.batch_id
WHERE deviations.deviation_id IS NULL;
