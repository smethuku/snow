CREATE OR REPLACE PROCEDURE get_all_role_grants()
RETURNS TABLE (
    role_name       STRING,
    privilege       STRING,
    object_type     STRING,
    object_name     STRING,
    grant_option    STRING,
    granted_by      STRING,
    created_on      TIMESTAMP_LTZ
)
LANGUAGE SQL
AS
$$
DECLARE
    role_name       STRING;
    sql_stmt        STRING;
BEGIN
    -- Create temp table to store results
    CREATE OR REPLACE TEMPORARY TABLE temp_role_grants (
        role_name       STRING,
        privilege       STRING,
        object_type     STRING,
        object_name     STRING,
        grant_option    STRING,
        granted_by      STRING,
        created_on      TIMESTAMP_LTZ
    );

    -- Step 1: Get all roles using SHOW ROLES (real-time)
    SHOW ROLES;

    -- Step 2: Loop through each role
    LET roles CURSOR FOR 
        SELECT "name" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

    FOR role_rec IN roles DO
        LET current_role STRING := role_rec."name";

        -- Step 3: Run SHOW GRANTS TO ROLE for each role
        LET show_grants_sql STRING := 'SHOW GRANTS OF ROLE IDENTIFIER(\'' || current_role || '\')';
        EXECUTE IMMEDIATE :show_grants_sql;

        -- Step 4: Insert results into temp table
        INSERT INTO temp_role_grants
        SELECT
            :current_role       AS role_name,
            "privilege"         AS privilege,
            "granted_on"        AS object_type,
            "name"              AS object_name,
            "grant_option"      AS grant_option,
            "granted_by"        AS granted_by,
            "created_on"        AS created_on
        FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

    END FOR;

    -- Step 5: Return all results
    LET res RESULTSET := (
        SELECT * FROM temp_role_grants
        ORDER BY role_name, object_type, privilege
    );

    RETURN TABLE(res);
END;
$$;
