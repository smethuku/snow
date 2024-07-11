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
