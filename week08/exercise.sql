/*
# Models for Manufacturing Cost Analysis.
================================================================

| Business Process             | Batch | BatchProduct | Facility | Cost Category | Date | Material | Supplier | Shift | Labor Role | Test Type |
|------------------------------|-------|--------------|----------|---------------|------|----------|----------|-------|------------|-----------|
| Direct Materials Cost        |   X   |      X       |    X     |       X       |  X   |    X     |    X     |       |            |           |
| Direct Labor Cost            |   X   |      X       |    X     |       X       |  X   |          |          |   X   |     X      |           |
| Manufacturing Overhead Cost  |   X   |      X       |    X     |       X       |  X   |          |          |       |            |           |
| Quality Control Testing Cost |   X   |      X       |    X     |       X       |  X   |          |          |       |            |     X     |
| Batch Cost Summary           |   X   |      X       |    X     |       X       |  X   |    X     |    X     |   X   |     X      |     X     |

*/
--=============================================================
-- STAR SCHEMA FOR MANUFACTURING COST ANALYSIS

-- DIM_DATE
-- ============================================================
CREATE OR REPLACE TABLE TRAINING_DB.WEEK08.DIM_DATE (
    DATE_ID           INT          NOT NULL PRIMARY KEY,
    FULL_DATE         DATE         NOT NULL,
    YEAR              INT          NOT NULL,
    QUARTER           INT          NOT NULL,
    MONTH             INT          NOT NULL,
    MONTH_NAME        VARCHAR(20)  NOT NULL,
    DAY_OF_WEEK       INT          NOT NULL
);

-- ============================================================
-- DIM_PRODUCT
-- ============================================================
CREATE OR REPLACE TABLE TRAINING_DB.WEEK08.DIM_PRODUCT (
    PRODUCT_ID            INT AUTOINCREMENT PRIMARY KEY,
    PRODUCT_NAME          VARCHAR      NOT NULL,
    DOSAGE_FORM           VARCHAR      NOT NULL,
    STRENGTH              VARCHAR      NOT NULL,
    NDC_CODE              VARCHAR      NOT NULL,
    FORMULATION_VERSION   VARCHAR      NOT NULL,
    TARGET_BATCH_SIZE     INT          NOT NULL
);

-- ============================================================
-- DIM_MATERIAL
-- ============================================================
CREATE OR REPLACE TABLE TRAINING_DB.WEEK08.DIM_MATERIAL (
    MATERIAL_ID           INT AUTOINCREMENT PRIMARY KEY,
    MATERIAL_NAME         VARCHAR      NOT NULL,
    SUPPLIER_NAME         VARCHAR      NOT NULL,
    LOT_NUMBER            VARCHAR      NOT NULL,
    EXPIRATION_DATE       DATE
);

-- ============================================================
-- DIM_BATCH
-- ============================================================
CREATE OR REPLACE TABLE TRAINING_DB.WEEK08.DIM_BATCH (
    BATCH_ID              INT AUTOINCREMENT PRIMARY KEY,
    FACILITY_ID           INT          NOT NULL,
    PRODUCTION_ORDER_ID   VARCHAR      NOT NULL,
    BATCH_STATUS          VARCHAR      NOT NULL,
    PLANNED_QUANTITY      INT          NOT NULL,
    ACTUAL_QUANTITY       INT          NOT NULL
);

-- ============================================================
-- FACT_MATERIAL_COST
-- Grain: One row for each material used in a batch.
-- For example, if Batch B001 uses 3 different materials,
-- that batch will have 3 rows in this fact table.
-- ============================================================
CREATE OR REPLACE TABLE TRAINING_DB.WEEK08.FACT_MATERIAL_COST (
    MATERIAL_COST_ID      INT AUTOINCREMENT PRIMARY KEY,
    DATE_ID               INT          NOT NULL REFERENCES TRAINING_DB.WEEK08.DIM_DATE(DATE_ID),
    PRODUCT_ID            INT          NOT NULL REFERENCES TRAINING_DB.WEEK08.DIM_PRODUCT(PRODUCT_ID),
    MATERIAL_ID           INT          NOT NULL REFERENCES TRAINING_DB.WEEK08.DIM_MATERIAL(MATERIAL_ID),
    BATCH_ID              INT          NOT NULL REFERENCES TRAINING_DB.WEEK08.DIM_BATCH(BATCH_ID),
    QUANTITY_USED         NUMBER(18,4) NOT NULL,
    UNIT_COST             NUMBER(18,4) NOT NULL,
    TOTAL_MATERIAL_COST   NUMBER(18,4) NOT NULL
);

-- ============================================================
-- Flattened ML table: MATERIAL_COST_ML
-- Supports predicting TOTAL_MATERIAL_COST for a given
-- batch-material combination. A model trained on this table
-- could help forecast material spending for upcoming
-- production orders based on product type, supplier,
-- facility, and seasonal patterns.
-- ============================================================
CREATE OR REPLACE TABLE TRAINING_DB.WEEK08.MATERIAL_COST_ML (
    FULL_DATE             DATE             NOT NULL,
    YEAR                  INT              NOT NULL,
    QUARTER               INT              NOT NULL,
    MONTH                 INT              NOT NULL,
    MONTH_NAME            VARCHAR(20)      NOT NULL,
    DAY_OF_WEEK           INT              NOT NULL,
    PRODUCT_NAME          VARCHAR          NOT NULL,
    DOSAGE_FORM           VARCHAR          NOT NULL,
    STRENGTH              VARCHAR          NOT NULL,
    NDC_CODE              VARCHAR          NOT NULL,
    FORMULATION_VERSION   VARCHAR          NOT NULL,
    TARGET_BATCH_SIZE     INT              NOT NULL,
    MATERIAL_NAME         VARCHAR          NOT NULL,
    SUPPLIER_NAME         VARCHAR          NOT NULL,
    LOT_NUMBER            VARCHAR          NOT NULL,
    EXPIRATION_DATE       DATE,
    BATCH_ID              VARCHAR          NOT NULL,
    FACILITY_ID           INT              NOT NULL,
    BATCH_STATUS          VARCHAR          NOT NULL,
    PLANNED_QUANTITY      INT              NOT NULL,
    ACTUAL_QUANTITY       INT              NOT NULL,
    QUANTITY_USED         NUMBER(18,4)     NOT NULL,
    UNIT_COST             NUMBER(18,4)     NOT NULL,
    TOTAL_MATERIAL_COST   NUMBER(18,4)     NOT NULL
);
