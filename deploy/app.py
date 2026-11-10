from contextlib import closing

import pymysql
from botocore.exceptions import BotoCoreError, ClientError
from flask import Flask, jsonify, request

from database import connect, get_secret

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 32 * 1024


@app.get("/")
def health():
    return jsonify(status="Flask is running")


@app.post("/submit")
def submit():
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return jsonify(message="Send the feedback fields as JSON."), 400

    fields = {"name": 100, "email": 100, "feedback": 4000}
    values = []
    for field, limit in fields.items():
        value = data.get(field)
        if not isinstance(value, str) or not value.strip() or len(value.strip()) > limit:
            return jsonify(message=f"Enter {field} with 1 to {limit} characters."), 400
        values.append(value.strip())

    try:
        with closing(connect(get_secret("WRITER_SECRET"))) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    "INSERT INTO feedback (name, email, feedback) VALUES (%s, %s, %s)",
                    values,
                )
            connection.commit()
    except (pymysql.MySQLError, BotoCoreError, ClientError):
        app.logger.exception("Feedback database write failed")
        return jsonify(message="Feedback could not be saved. Please try again."), 503

    return jsonify(message="Feedback submitted successfully!")
