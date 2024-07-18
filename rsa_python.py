import snowflake.connector

# Establish a connection to Snowflake
conn = snowflake.connector.connect(
    user='<your_username>',
    password='<your_password>',
    account='<your_account>.snowflakecomputing.com',
    warehouse='<your_warehouse>',
    database='<your_database>',
    schema='<your_schema>'
)

# Create a cursor object
cur = conn.cursor()

# Step 1: Get the list of users
cur.execute("SHOW USERS")
users = cur.fetchall()

# Step 2: Loop through each user and get RSA_PUBLIC_KEY_LAST_SET_TIME
user_rsa_times = []

for user in users:
    username = user[0]
    cur.execute(f"DESCRIBE USER {username}")
    user_details = cur.fetchall()
    
    rsa_public_key_last_set_time = None
    rsa_public_key_2_last_set_time = None
    
    for detail in user_details:
        if detail[0] == 'RSA_PUBLIC_KEY_LAST_SET_TIME':
            rsa_public_key_last_set_time = detail[1]
        elif detail[0] == 'RSA_PUBLIC_KEY_2_LAST_SET_TIME':
            rsa_public_key_2_last_set_time = detail[1]
    
    user_rsa_times.append((username, rsa_public_key_last_set_time, rsa_public_key_2_last_set_time))

# Print the results
for user_rsa_time in user_rsa_times:
    print(f"User: {user_rsa_time[0]}, RSA_PUBLIC_KEY_LAST_SET_TIME: {user_rsa_time[1]}, RSA_PUBLIC_KEY_2_LAST_SET_TIME: {user_rsa_time[2]}")

# Close the cursor and connection
cur.close()
conn.close()
