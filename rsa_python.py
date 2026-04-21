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

# Get the list of users
cur.execute("SELECT NAME FROM SNOWFLAKE.ACCOUNT_USAGE.USERS WHERE DELETED_ON IS NULL AND HAS_RSA_PUBLIC_KEY = TRUE AND DISABLED = FALSE;")
users = cur.fetchall()

# Loop through each user and get RSA_PUBLIC_KEY_LAST_SET_TIME
user_rsa_times = []
for user in users:
    username = user[0]
    cur.execute(f"DESCRIBE USER {username}")
    user_details  = cur.fetchall()

    rsa_public_key_last_set_time = None

    for detail in user_details:
        if detail[0] == 'RSA_PUBLIC_KEY_LAST_SET_TIME':
            rsa_public_key_last_set_time = pd.to_datetime(detail[1]) 

    config_value = ''
    cur.execute(f"SELECT CONFIG_ITEM_VALUE FROM ADMIN.MONITORING.ALERTS_CONFIG WHERE ALERT_NAME = 'Key/Pair Alert' AND CONFIG_ITEM = '{username}';")
    config_value = cur.fetchone()

    

    if config_value:
        #split the string into timeunit and value
        unit, value_str = config_value[0].split('=')
        value = int(value_str)

        try: 
            if unit == "hours":
                time_delta = timedelta(hours = value)
            elif unit == "days":
                time_delta = timedelta(days = value)
        except Exception as e:
            email_subject = F'Snowflake Account {account_name}:  Key/Pair Alert'
            message = f"Unsupported time units: {unit} in ADMIN.MONITORING.ALERTS_CONFIG for ServiceAccount' : '{username}'"
            email.send_email(email_subject, message, sender_email, email_recipients)

        time_difference = pd.Timestamp.now() - rsa_public_key_last_set_time
        
        if time_difference > time_delta:
            user_rsa_times.append({'ServiceAccount' : username, 'RSA_PUBLIC_KEY_LAST_SET_TIME' : rsa_public_key_last_set_time})
               

    elif rsa_public_key_last_set_time < last_hour:          
        user_rsa_times.append({'ServiceAccount' : username, 'RSA_PUBLIC_KEY_LAST_SET_TIME' : rsa_public_key_last_set_time})

if  user_rsa_times:
    df_user_rsa_times = pd.DataFrame(user_rsa_times)
    email_subject = f"Snowflake Account {account_name} Alert: Key/Pair greater than 1 hour"
    email_df.email_dataframe(df_user_rsa_times, email_subject, sender_email, email_recipients)
