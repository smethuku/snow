-- Step 1: Get the list of users
SHOW USERS;

-- Step 2: Use RESULT_SCAN to process the results of the SHOW USERS command
WITH user_list AS (
    SELECT "name"
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
)
-- Step 3: Loop through each user and get RSA_PUBLIC_KEY_LAST_SET_TIME
SELECT 
    u.name AS username,
    p.property,
    p.value
FROM 
    user_list u,
    LATERAL (
        SELECT 
            property,
            value
        FROM 
            TABLE(RESULT_SCAN(LAST_QUERY_ID()))
        WHERE 
            property = 'RSA_PUBLIC_KEY_LAST_SET_TIME'
    ) p
ORDER BY 
    u.name;


-- Get list of users
SHOW USERS;

-- Store results in a temporary table
CREATE OR REPLACE TEMPORARY TABLE user_list AS
SELECT "name" AS username FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- Loop through users and get RSA_PUBLIC_KEY_LAST_SET_TIME
SELECT 
    u.username,
    (SELECT value::timestamp_ltz
     FROM TABLE(RESULT_SCAN(LAST_QUERY_ID(-1)))
     WHERE "property" = 'RSA_PUBLIC_KEY_LAST_SET_TIME') AS rsa_public_key_last_set_time,
    (SELECT value::timestamp_ltz
     FROM TABLE(RESULT_SCAN(LAST_QUERY_ID(-1)))
     WHERE "property" = 'RSA_PUBLIC_KEY_2_LAST_SET_TIME') AS rsa_public_key_2_last_set_time
FROM user_list u
WHERE EXISTS (
    SELECT 1 
    FROM TABLE(RESULT_SCAN(EXECUTE_IMMEDIATE('DESCRIBE USER ' || u.username)))
    WHERE "property" IN ('RSA_PUBLIC_KEY_LAST_SET_TIME', 'RSA_PUBLIC_KEY_2_LAST_SET_TIME')
)
ORDER BY u.username;

-- Clean up
DROP TABLE IF EXISTS user_list;

-----------------------------------

CREATE OR REPLACE PROCEDURE get_rsa_key_set_times()
RETURNS TABLE (username STRING, rsa_key_1_set_time TIMESTAMP_LTZ, rsa_key_2_set_time TIMESTAMP_LTZ)
LANGUAGE SQL
AS
$$
DECLARE
  cur CURSOR FOR SELECT name FROM information_schema.users WHERE deleted_on IS NULL;
  username VARCHAR;
  rsa_key_1_set_time TIMESTAMP_LTZ;
  rsa_key_2_set_time TIMESTAMP_LTZ;
BEGIN
  OPEN cur;
  
  LET results := (SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*)) FROM (
    LOOP
      FETCH cur INTO username;
      IF (SQLCODE = 100) THEN
        BREAK;
      END IF;
      
      EXECUTE IMMEDIATE 'DESCRIBE USER ' || username;
      
      SELECT value::timestamp_ltz INTO rsa_key_1_set_time
      FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
      WHERE property = 'RSA_PUBLIC_KEY_LAST_SET_TIME';
      
      SELECT value::timestamp_ltz INTO rsa_key_2_set_time
      FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
      WHERE property = 'RSA_PUBLIC_KEY_2_LAST_SET_TIME';
      
      SELECT :username AS username, 
             :rsa_key_1_set_time AS rsa_key_1_set_time, 
             :rsa_key_2_set_time AS rsa_key_2_set_time;
    END LOOP;
  ));
  
  CLOSE cur;
  
  RETURN TABLE(SELECT value:username::STRING, 
                      value:rsa_key_1_set_time::TIMESTAMP_LTZ, 
                      value:rsa_key_2_set_time::TIMESTAMP_LTZ 
               FROM TABLE(FLATTEN(input => :results)));
END;
$$
;
