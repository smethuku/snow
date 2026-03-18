CREATE OR REPLACE PROCEDURE get_all_grants_of_roles()
RETURNS TABLE (
    role_name       STRING,
    grant_name    STRING    
)
LANGUAGE SQL
AS
$$
DECLARE
    role_name       STRING;
    sql_stmt        STRING;
BEGIN
    -- Create temp table to store results
    CREATE OR REPLACE TEMPORARY TABLE temp_grants_of_roles (
        role_name       STRING,
        grantee_name       STRING        
    );

    -- Step 1: Get all roles using SHOW ROLES (real-time)
    SHOW ROLES;

    -- Step 2: Loop through each role
    LET roles CURSOR FOR 
        SELECT "name" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) WHERE "name" like 'P_%';

    FOR role_rec IN roles DO
        LET current_role STRING := role_rec."name";

        -- Step 3: Run SHOW GRANTS TO ROLE for each role
        LET show_grants_sql STRING := 'SHOW GRANTS OF ROLE IDENTIFIER(\'' || current_role || '\')';
        EXECUTE IMMEDIATE :show_grants_sql;

        -- Step 4: Insert results into temp table
        INSERT INTO temp_grants_of_roles
        SELECT
            :current_role       AS role_name,
            "grantee_name"        AS grantee_name
        FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) WHERE "granted_to" = 'ROLE';

    END FOR;

    -- Step 5: Return all results
    LET res RESULTSET := (
        SELECT * FROM temp_grants_of_roles
        ORDER BY role_name
    );

    RETURN TABLE(res);
END;
$$;
