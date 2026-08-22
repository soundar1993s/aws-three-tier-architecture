# Configure Amazon RDS Connection for Flask Application

This guide explains how to connect the Flask application running on the private EC2 instance to an Amazon RDS MySQL database.

---

## Step 1: Connect to the Amazon RDS Instance

From the private EC2 instance, connect to the MySQL database:

```bash
mysql -h <RDS-ENDPOINT> -u admin -p
```

Enter the RDS master password when prompted.

---

## Step 2: Create the Database

Inside the MySQL shell, create the application database:

```sql
CREATE DATABASE feedbackdb;
```

Select the database:

```sql
USE feedbackdb;
```

---

## Step 3: Create the Feedback Table

Create the table to store customer feedback:

```sql
CREATE TABLE feedback (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100),
    feedback TEXT,
    created TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## Step 4: Verify the Database

Check that the table has been created successfully:

```sql
SHOW TABLES;
```

View the table structure:

```sql
DESCRIBE feedback;
```

---

## Step 5: Configure the Flask Application

Open the Flask application:

```bash
nano ~/app.py
```

Locate the database configuration:

```python
'host': 'RDS-ENDPOINT',
```

Replace it with your actual Amazon RDS details:

```python
db = pymysql.connect(
    host='YOUR-RDS-ENDPOINT',
    user='admin',
    password='YourPassword123!',
    database='feedbackdb'
)
```

> Replace **YOUR-RDS-ENDPOINT** with the endpoint of your Amazon RDS instance.

---

## Step 6: Restart the Flask Application

Stop the currently running Flask application:

```bash
pkill -f "python3 app.py"
```

Start the application again:

```bash
python3 ~/app.py &
```

---

## Step 7: Test Database Connectivity

Send a test request to the Flask API:

```bash
curl -X POST http://localhost:5000/submit \
-H "Content-Type: application/json" \
-d '{
      "name":"Test",
      "email":"t@t.com",
      "feedback":"Hello RDS!"
    }'
```

---

## Expected Response

```json
{
  "message": "Feedback submitted successfully!"
}
```

---

## Step 8: Verify the Data in Amazon RDS

Reconnect to the database:

```bash
mysql -h <RDS-ENDPOINT> -u admin -p
```

Select the database:

```sql
USE feedbackdb;
```

View the stored feedback:

```sql
SELECT * FROM feedback;
```

If the record appears, the Flask application is successfully connected to the Amazon RDS database.

---

## Architecture Flow

```text
Flask Application (Private EC2)
          │
          │  INSERT Feedback
          ▼
Amazon RDS MySQL (Private Subnet)
          │
          ▼
      feedbackdb.feedback
```
