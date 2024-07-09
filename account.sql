-- Note: Account creation usually requires Snowflake support or web interface
-- This is a conceptual representation of what would be done

-- 1. Create the account (this step is typically done by Snowflake)
-- CREATE ACCOUNT my_new_account;

-- 2. Connect to the new account (you would do this in your SnowSQL client)
-- USE ROLE ACCOUNTADMIN;

-- 3. Create the account admin user
CREATE USER account_admin
  PASSWORD = 'StrongPassword123!'
  DEFAULT_ROLE = ACCOUNTADMIN
  MUST_CHANGE_PASSWORD = TRUE;

-- 4. Grant the ACCOUNTADMIN role to the new user
GRANT ROLE ACCOUNTADMIN TO USER account_admin;

-- 5. Create a security admin user
CREATE USER security_admin
  PASSWORD = 'AnotherStrongPassword456!'
  DEFAULT_ROLE = SECURITYADMIN
  MUST_CHANGE_PASSWORD = TRUE;

-- 6. Grant the SECURITYADMIN role to the security admin user
GRANT ROLE SECURITYADMIN TO USER security_admin;

-- 7. Create a system admin user
CREATE USER system_admin
  PASSWORD = 'YetAnotherStrongPassword789!'
  DEFAULT_ROLE = SYSADMIN
  MUST_CHANGE_PASSWORD = TRUE;

-- 8. Grant the SYSADMIN role to the system admin user
GRANT ROLE SYSADMIN TO USER system_admin;

-- 9. Create a public warehouse for general use
CREATE WAREHOUSE IF NOT EXISTS public_wh
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 300
  AUTO_RESUME = TRUE;

-- 10. Grant usage on the public warehouse to the PUBLIC role
GRANT USAGE ON WAREHOUSE public_wh TO ROLE PUBLIC;

-- 11. Create a database for shared data
CREATE DATABASE IF NOT EXISTS shared_data;

-- 12. Grant usage on the shared database to the PUBLIC role
GRANT USAGE ON DATABASE shared_data TO ROLE PUBLIC;

-- 13. Create a schema in the shared database
CREATE SCHEMA IF NOT EXISTS shared_data.public;

-- 14. Grant usage on the public schema to the PUBLIC role
GRANT USAGE ON SCHEMA shared_data.public TO ROLE PUBLIC;
