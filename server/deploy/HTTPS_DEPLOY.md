# Domain and HTTPS Deployment

## 1. DNS

Create an `A` record for the API hostname and point it to the ECS public IP.
Example:

```text
YOUR_DOMAIN -> 101.37.237.234
```

Wait for DNS propagation:

```bash
getent hosts api.example.com
```

If the ECS is in mainland China, confirm the domain has completed ICP filing
for web access.

## 2. Security Group

- Open inbound TCP `80` and `443`.
- Remove public inbound TCP `3000`.
- Keep SSH `22` restricted to your own public IP.
- Keep MySQL port closed to the public internet.

## 3. Bind Node to localhost

Edit `/opt/daka/server/.env`:

```env
BIND_HOST=127.0.0.1
```

Restart:

```bash
cd /opt/daka/server
pm2 restart daka-api --update-env
pm2 save
```

Confirm Nginx can reach it locally:

```bash
curl http://127.0.0.1:3000/health
```

Direct public access to `http://ECS_IP:3000` should no longer work.

## 4. Install Nginx and Certbot

Ubuntu:

```bash
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx
```

Huawei Cloud EulerOS / openEuler:

```bash
sudo dnf install -y nginx certbot python3-certbot-nginx
```

## 5. Install the Nginx site

```bash
cd /opt/daka/server
sudo cp deploy/nginx/daka-api.conf /etc/nginx/conf.d/daka-api.conf
sudo sed -i 's/api.example.com/YOUR_DOMAIN/g' /etc/nginx/conf.d/daka-api.conf
sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl reload nginx
```

For Debian/Ubuntu, if `/etc/nginx/conf.d/` is not included, use:

```bash
sudo mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
sudo cp deploy/nginx/daka-api.conf /etc/nginx/sites-available/daka-api
sudo sed -i 's/api.example.com/YOUR_DOMAIN/g' /etc/nginx/sites-available/daka-api
sudo ln -sf /etc/nginx/sites-available/daka-api /etc/nginx/sites-enabled/daka-api
sudo nginx -t
sudo systemctl reload nginx
```

Test HTTP first:

```bash
curl http://YOUR_DOMAIN/health
```

Expected:

```json
{"status":"ok"}
```

## 6. Enable HTTPS

```bash
sudo certbot --nginx -d YOUR_DOMAIN
```

Choose the redirect option so HTTP redirects to HTTPS.

Test:

```bash
curl -I http://YOUR_DOMAIN
curl https://YOUR_DOMAIN/health
```

Expected:

```text
HTTP/1.1 301 Moved Permanently
{"status":"ok"}
```

Certbot installs its renewal timer automatically. Verify:

```bash
sudo systemctl status certbot.timer --no-pager
sudo certbot renew --dry-run
```

## 7. Update the app

Set `ApiConfig.baseUrl` to:

```text
https://YOUR_DOMAIN
```

Rebuild and reinstall the app. Do not keep the raw IP address or port `3000`
in the release build.
