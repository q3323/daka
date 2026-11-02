# Huawei Cloud to Alibaba Cloud Migration

## Recommended Shape

- Alibaba Cloud ECS, Ubuntu 22.04 LTS
- 2 vCPU and 4 GB RAM recommended
- Node.js 20
- MySQL 8 on the same ECS for the MVP
- Nginx on 80/443
- PM2 for the Node process
- Alibaba Cloud OSS instead of Huawei Cloud OBS

Use RDS MySQL instead of self-hosted MySQL if backups and availability are
more important than cost.

## Prepare the New ECS

Install:

```bash
sudo apt update
sudo apt install -y nginx mysql-server certbot python3-certbot-nginx
```

Install Node.js 20 using the official NodeSource package or a Node 20 binary.
Do not copy `node_modules` from the old server.

Security group inbound rules:

- TCP 22 from your own public IP only
- TCP 80 from the internet
- TCP 443 from the internet
- Do not expose 3000 or 3306 publicly

## Back Up the Old Database

On the Huawei Cloud ECS, run the migration bundle script:

```bash
cd /opt/daka/server
sudo bash deploy/create_migration_bundle.sh
```

It creates a private bundle under `/root/daka-migration/` containing the MySQL
dump, backend code, and `.env`.

The equivalent manual database backup is:

```bash
mysqldump \
  --single-transaction \
  --routines \
  --triggers \
  --default-character-set=utf8mb4 \
  -u daka_app -p daka > /root/daka_backup.sql
```

Photos are stored as `LONGBLOB`, so the dump may be large.

## Transfer Files

From Windows PowerShell:

```powershell
scp root@119.3.191.174:/root/daka_backup.sql .
scp daka-server.tar.gz root@NEW_ALIYUN_IP:/root/
```

Transfer the old `.env` separately and securely. Do not send it through chat.

## Restore on Alibaba Cloud

```bash
sudo mkdir -p /opt/daka
sudo tar -xzf /root/daka-server.tar.gz -C /opt/daka
cd /opt/daka/server
npm install
```

Create the database and user, then restore:

```bash
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS daka CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -u root -p daka < /root/daka_backup.sql
```

Create `/opt/daka/server/.env` with the Alibaba Cloud database password,
`JWT_SECRET`, and:

```env
BIND_HOST=127.0.0.1
```

Start the API:

```bash
cd /opt/daka/server
pm2 start src/index.js --name daka-api --cwd /opt/daka/server
pm2 save
pm2 startup
curl http://127.0.0.1:3000/health
```

## Cutover

1. Test login, classes, tasks, and photos on the new server.
2. Take a final database backup while the old API is stopped.
3. Restore the final backup on Alibaba Cloud.
4. Update the domain A record to the Alibaba Cloud EIP.
5. Wait for DNS propagation.
6. Verify HTTPS and `/health`.
7. Keep the old ECS for 24 to 48 hours for rollback.

If the client uses a raw IP address instead of a domain, it must be rebuilt
with the new address. Use a domain to avoid this.

For mainland China regions, verify ICP filing and provider access filing before
switching DNS.
