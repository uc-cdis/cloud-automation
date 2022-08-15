-- ========================================================
-- Populate atlas schema
-- ========================================================

insert into atlas.source
(source_id,source_name,source_connection,source_dialect,username,password)
values
    (1,'results_and_cdm_DATABASE', 'jdbc:postgresql://DB_HOSTNAME:DB_PORT;databaseName=DB_NAME;user=DB_USERNAME;password=DB_PASSWORD', 'DB_ENGINE', 'DB_USERNAME', 'DB_PASSWORD') -- pragma: allowlist secret
;

insert into atlas.source_daimon
(source_daimon_id,source_id,daimon_type,table_qualifier,priority)
values
    (1,1,0, 'OMOP', 1),
    (2,1,1, 'OMOP', 1),
    (3,1,2, 'RESULTS', 1),
    (4,1,5, 'TEMP', 1)
;

insert into atlas.cohort_definition
(id,name,description)
values
    (1,'Test cohort1','Small cohort'),
    (2,'Test cohort2','Medium cohort'),
    (3,'Test cohort3','Larger cohort')
;