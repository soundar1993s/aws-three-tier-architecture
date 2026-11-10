import argparse
import json
import os
from contextlib import closing
from functools import lru_cache

import boto3
import pymysql


@lru_cache
def get_secret(variable):
    client = boto3.client("secretsmanager", region_name=os.environ["AWS_REGION"])
    response = client.get_secret_value(SecretId=os.environ[variable])
    return json.loads(response["SecretString"])


def connect(credentials, database="feedbackdb"):
    return pymysql.connect(
        host=os.environ["DB_HOST"],
        user=credentials["username"],
        password=credentials["password"],
        database=database,
        charset="utf8mb4",
        connect_timeout=5,
        read_timeout=5,
        write_timeout=5,
        ssl_ca="/opt/feedback/rds-ca.pem",
        ssl_verify_cert=True,
        ssl_verify_identity=True,
    )


def initialize():
    writer_password = get_secret("WRITER_SECRET")["password"]
    with closing(connect(get_secret("MASTER_SECRET"), database=None)) as connection:
        with connection.cursor() as cursor:
            cursor.execute("CREATE DATABASE IF NOT EXISTS feedbackdb CHARACTER SET utf8mb4")
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS feedbackdb.feedback (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(100) NOT NULL,
                    email VARCHAR(100) NOT NULL,
                    feedback TEXT NOT NULL,
                    created TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
                """
            )
            cursor.execute(
                "CREATE USER IF NOT EXISTS 'feedback_writer'@'%%' IDENTIFIED BY %s REQUIRE SSL",
                (writer_password,),
            )
            cursor.execute(
                "ALTER USER 'feedback_writer'@'%%' IDENTIFIED BY %s REQUIRE SSL",
                (writer_password,),
            )
            cursor.execute("GRANT INSERT ON feedbackdb.feedback TO 'feedback_writer'@'%'")
            cursor.execute("DESCRIBE feedbackdb.feedback")
            for column in cursor.fetchall():
                print(column[0], column[1])
    print("Schema initialized and application INSERT permission configured.")


def verify(feedback):
    query = "SELECT id, name, email, feedback, created FROM feedbackdb.feedback WHERE feedback = %s"
    with closing(connect(get_secret("MASTER_SECRET"))) as connection:
        with connection.cursor() as cursor:
            print(cursor.mogrify(query, (feedback,)))
            cursor.execute(query, (feedback,))
            print(" | ".join(column[0] for column in cursor.description))
            rows = cursor.fetchall()
            if not rows:
                raise SystemExit("No feedback record matched the evidence marker.")
            for row in rows:
                print(" | ".join(map(str, row)))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("initialize")
    verification = commands.add_parser("verify")
    verification.add_argument("feedback")
    args = parser.parse_args()
    if args.command == "initialize":
        initialize()
    else:
        verify(args.feedback)
