# Flask Application Setup on Ubuntu EC2

This guide explains how to set up and run the Flask application on an Ubuntu EC2 instance.

Execute All this command once you start Step 3 in Assesment document 

## Step 1: Update the System

```bash
sudo apt update
```

---

## Step 2: Install Python and Required Packages

Install `pip`:

```bash
sudo apt install python3-pip -y
```

Install Python virtual environment support:

```bash
sudo apt update
sudo apt install python3-venv python3-full -y
```

---

## Step 3: Create and Activate a Virtual Environment

Create a virtual environment:

```bash
python3 -m venv venv
```

Activate the virtual environment:

```bash
source venv/bin/activate
```

---

## Step 4: Install Python Dependencies

Install the required Python packages:

```bash
pip install Flask PyMySQL gunicorn
```

---

## Step 5: Install MySQL Client

Install the MySQL client to connect to the Amazon RDS database:

```bash
sudo apt install default-mysql-client -y
```

Verify the installation:

```bash
mysql --version
```

---

## Step 6: Create the Flask Application

Create a file named:

```text
app.py
```

Add your Flask application code to this file.

---

## Step 7: Run the Flask Application

Start the application in the background:

```bash
python3 app.py &
```

---

## Step 8: Verify the Application

Test the application locally:

```bash
curl localhost:5000
```

### Expected Output

```json
{"status": "Flask is running"}
```

---


## Notes

* Ensure the virtual environment is activated before running the application.
* Replace the database connection details in `app.py` with your Amazon RDS endpoint, username, password, and database name.
* For production deployments, it is recommended to run the application using Gunicorn behind Nginx instead of Flask's built-in development server.
