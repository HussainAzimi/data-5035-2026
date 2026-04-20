USE SCHEMA data5035.COYOTE;
USE ROLE coyote_data5035_role;

/*
# Models for Manufacturing Cost Analysis.
================================================================

| Metric                   | Description                                     | Batch | Product | Facility | Cost Category | Date |
|------------------------- |-------------------------------------------------|-------|---------|----------|---------------|------|
| Actual Cost              | Total actual cost incurred                      |   X   |   X     |    X     |       X       |  X   |
| Standard Cost            | Expected cost                                   |   X   |   X     |    X     |       X       |  X   |
| Cost Variance            | Actual - Standard                               |   X   |   X     |    X     |       X       |  X   |
| Variance Percentage      | % difference from standard                      |   X   |   X     |    X     |       X       |  X   |
| Cost Per Unit            | Cost per unit produced                          |   X   |   X     |    X     |               |  X   |


# Business Processes
- Direct Materials Cost
- Direct Labor Cost
- Manufacturing Overhead Cost
- Quality Control Testing Cost

*/
--=============================================================
-- DIM_DATE
-- ============================================================
CREATE OR REPLACE TABLE DATA5035.COYOTE.DIM_DATE (
    DATE_ID           INT          NOT NULL PRIMARY KEY,
    FULL_DATE         DATE         NOT NULL,
    YEAR              INT          NOT NULL,
    QUARTER           INT          NOT NULL,
    MONTH             INT          NOT NULL,
    MONTH_NAME        VARCHAR(20)  NOT NULL,
    DAY_OF_WEEK       INT          NOT NULL
);

-- ============================================================
-- DIM_FACILITY
-- ============================================================
CREATE OR REPLACE TABLE DATA5035.COYOTE.DIM_FACILITY (
    FACILITY_ID        INT AUTOINCREMENT PRIMARY KEY,
    FACILITY_NAME      VARCHAR NOT NULL,
    CITY               VARCHAR NOT NULL,
    STATE              VARCHAR NOT NULL,
    OVERHEAD_RATE      NUMBER(10,2) NOT NULL,
    IS_STERILE         BOOLEAN NOT NULL
);

-- ============================================================
-- DIM_PRODUCT
-- ============================================================
CREATE OR REPLACE TABLE DATA5035.COYOTE.DIM_PRODUCT (
    PRODUCT_ID            INT AUTOINCREMENT PRIMARY KEY,
    PRODUCT_NAME          VARCHAR      NOT NULL,
    DOSAGE_FORM           VARCHAR      NOT NULL,
    PRODUCT_LINE          VARCHAR      NOT NULL,
    FORMULATION_VERSION   VARCHAR      NOT NULL,
    TARGET_BATCH_SIZE     INT          NOT NULL
);

-- ============================================================
-- DIM_BATCH
-- ============================================================
CREATE OR REPLACE TABLE DATA5035.COYOTE.DIM_BATCH (
    BATCH_ID              INT AUTOINCREMENT PRIMARY KEY,
    FACILITY_ID           INT          NOT NULL,
    BATCH_STATUS          VARCHAR      NOT NULL,
    PLANNED_QUANTITY      INT          NOT NULL,
    ACTUAL_QUANTITY       INT          NOT NULL,
    QA_HOLD_DAYS          INT          NOT NULL,
    REWORK_HOURSE         NUMBER(10,2)
);

-- ============================================================
-- DIM_COST_CATEGORY
-- ============================================================
CREATE OR REPLACE TABLE DATA5035.COYOTE.DIM_COST_CATEGORY (
    COST_CATEGORY_ID   INT AUTOINCREMENT PRIMARY KEY,
    COST_CATEGORY_NAME VARCHAR NOT NULL,  
    COST_TYPE          VARCHAR NOT NULL   
);

-- ============================================================
-- FACT_BATCH_COST
-- Grain: One row per batch per cost category per date.
-- ============================================================
CREATE OR REPLACE TABLE DATA5035.COYOTE.FACT_BATCH_COST (
    MATERIAL_COST_ID      INT AUTOINCREMENT PRIMARY KEY,
    
    DATE_ID               INT          NOT NULL REFERENCES DATA5035.COYOTE.DIM_DATE(DATE_ID),
    PRODUCT_ID            INT          NOT NULL REFERENCES DATA5035.COYOTE.DIM_PRODUCT(PRODUCT_ID),
    BATCH_ID              INT          NOT NULL REFERENCES DATA5035.COYOTE.DIM_BATCH(BATCH_ID),
    FACILITY_ID           INT          NOT NULL REFERENCES DATA5035.COYOTE.DIM_FACILITY(FACILITY_ID),
    COST_CATEGORY_ID      INT          NOT NULL REFERENCES DATA5035.COYOTE.DIM_COST_CATEGORY(COST_CATEGORY_ID),
    ACTUAL_COST          NUMBER(12,2) NOT NULL,
    STANDARD_COST        NUMBER(12,2) NOT NULL,
    COST_VARIANCE        NUMBER(12,2) NOT NULL,
    VARIANCE_PERCENT     NUMBER(8,2) NOT NULL,
    UNITS_PRODUCED       INT,
    LABOR_HOURS          NUMBER(10,2),
    LINE_HOURS           NUMBER(10,2)
    
);

-- ============================================================
-- FLATTENED ML TABLE
-- ============================================================

CREATE OR REPLACE TABLE DATA5035.COYOTE.BATCH_COST_ML (
    
    -- Batch info
    BATCH_ID              INT NOT NULL,
    BATCH_STATUS          VARCHAR NOT NULL,
    ACTUAL_QUANTITY       INT NOT NULL,

    -- Date features
    YEAR                  INT NOT NULL,
    MONTH                 INT NOT NULL,

    -- Facility
    FACILITY_NAME         VARCHAR NOT NULL,
    IS_STERILE            BOOLEAN NOT NULL,
    OVERHEAD_RATE         NUMBER(10,2) NOT NULL,

    -- Product
    PRODUCT_NAME          VARCHAR NOT NULL,
    DOSAGE_FORM           VARCHAR NOT NULL,
    PRODUCT_LINE          VARCHAR NOT NULL,

    -- Operational features
    QA_HOLD_DAYS          INT,
    REWORK_HOURS          NUMBER(10,2),

    -- Cost features
    MATERIAL_COST         NUMBER(12,2),
    LABOR_COST            NUMBER(12,2),
    OVERHEAD_COST         NUMBER(12,2),
    QC_COST               NUMBER(12,2),

    TOTAL_ACTUAL_COST     NUMBER(12,2),
    TOTAL_STANDARD_COST   NUMBER(12,2),
    TOTAL_VARIANCE        NUMBER(12,2),
    VARIANCE_PERCENT      NUMBER(8,2),

    COST_PER_UNIT         NUMBER(10,2),
    EXCEEDS_15_PERCENT    BOOLEAN
);

/*
✅ ML PURPOSE


This table is used to predict if a batch will cost more than expected.

With this table, we can:
1. Find batches that might go over budget early.
2. See what causes high costs (like extra labor or QC failures).
3. Estimate the total cost and cost per unit for each batch.

This helps the company control costs and make better decisions.

*/