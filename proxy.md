# Configure Nginx Reverse Proxy

This guide explains how to configure Nginx as a reverse proxy on the Web Tier EC2 instance to forward API requests to the Internal Application Load Balancer.

---

## Step 1: Edit the Nginx Configuration

Open the Nginx configuration file:

```bash
sudo nano /etc/nginx/nginx.conf
```

Replace the existing configuration or update the appropriate `server` block with the reverse proxy configuration.

> Ensure the configuration includes the frontend web content and the reverse proxy settings for the `/api/` endpoint.

---

## Step 2: Save the Configuration

After making the changes:

1. Press `CTRL + X`
2. Press `Y`
3. Press `ENTER`

to save and exit the editor.

---

## Step 3: Validate the Nginx Configuration

Test the configuration for syntax errors:

```bash
sudo nginx -t
```

### Expected Output

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

If errors are displayed, review the configuration and correct them before proceeding.

---

## Step 4: Restart Nginx

Apply the new configuration:

```bash
sudo systemctl restart nginx
```

Verify that Nginx is running:

```bash
sudo systemctl status nginx
```

### Expected Output

```text
Active: active (running)
```

---

## Step 5: Verify Reverse Proxy Functionality

Open the application using the Public Load Balancer DNS name:

```text
http://<PUBLIC-ALB-DNS>
```

Test the following:

* The frontend (`index.html`) loads successfully.
* API requests are forwarded through Nginx.
* Feedback submissions reach the Flask application.
* Feedback data is stored in Amazon RDS.

---

## Request Flow

```text
Browser
   │
   ▼
Public ALB
   │
   ▼
Web EC2 (Nginx Reverse Proxy)
   │
   ▼
Internal ALB
   │
   ▼
Flask Application EC2
   │
   ▼
Amazon RDS MySQL
```

---

## Troubleshooting

View Nginx logs:

```bash
sudo tail -f /var/log/nginx/error.log
```

Check service status:

```bash
sudo systemctl status nginx
```

Reload configuration without restarting:

```bash
sudo nginx -s reload
```

Retest configuration:

```bash
sudo nginx -t
```
