# WordPress Backup Script

This script creates a full backup of a WordPress site — including the database and `wp-content` directory — and compresses everything into a single archive.

## 📄 What It Does

- Extracts MySQL credentials from `wp-config.php`
- Backs up the `wp-content` directory
- Dumps the MySQL database
- Packages everything into a compressed `.tar.gz` archive
- Cleans up temporary files

## 📁 File Naming Convention

All output files are named using this pattern:

```
example.com-wp-YYYY-MM-DD_HHMM.tar.gz
├── example.com-db-YYYY-MM-DD_HHMM.sql
└── example.com-wp-content-YYYY-MM-DD_HHMM.tar.gz
```

## ⚙️ Configuration

You only need to set:

```bash
SITE_NAME="example.com"
```

The script will automatically derive:

- `WP_PATH`: `/sites/example.com/public`
- `BACKUP_DIR`: `/sites/example.com/backups`

## 🚀 How to Use

1. Save the file as `/sites/scripts/backup.sh`
2. Open the script and edit the `SITE_NAME` variable with your domain.
3. Run the script:

**Make the file executable once:**

```bash
chmod +x backup.sh
```

**Run the script:**

```bash
sudo ./backup.sh
```

3. The backup archive will be saved to:

```
/sites/example.com/backups/
```

## 🔐 Security Notes

- The script securely reads DB credentials from `wp-config.php`.
- Avoids hardcoded credentials.
- Uses a temporary `/tmp` directory during packaging.

## 🧹 Cleanup

Temporary working directory is deleted after the archive is created.

## 🧰 Requirements

- Bash shell
- `mysqldump`
- `tar`
- `grep`, `sed`, `date` (standard GNU tools)

## ✅ Sample Output

```bash
📦 Backing up wp-content...
🛢️ Backing up MySQL database...
🗜️ Creating final archive: /sites/example.com/backups/example.com-wp-2025-07-28_2145.tar.gz
✅ Backup created: /sites/example.com/backups/example.com-wp-2025-07-28_2145.tar.gz
```









```



```
## 🧪 Testing the Backup Archive

After creating a backup, verify that the archive is readable and contains valid `wp-content` and database backups before relying on it.

### 1. Go to the Backup Directory

Replace `example.com` with the configured site name:

```bash
cd /sites/example.com/backups
```

### 2. Test the Final Archive

Run:

```bash
tar -tzf example.com-wp-YYYY-MM-DD_HHMM.tar.gz > /dev/null
```

Check the exit status:

```bash
echo $?
```

A result of:

```text
0
```

means the `.tar.gz` archive can be read successfully.

Alternatively, use:

```bash
tar -tzf example.com-wp-YYYY-MM-DD_HHMM.tar.gz > /dev/null \
    && echo "Archive OK" \
    || echo "Archive FAILED"
```

> **Note:** This only verifies the integrity of the compressed archive. It does not prove that the database dump itself is complete.

### 3. Check the Contents of the Archive

List the files stored inside:

```bash
tar -tzf example.com-wp-YYYY-MM-DD_HHMM.tar.gz
```

You should see files similar to:

```text
./
./example.com-db-YYYY-MM-DD_HHMM.sql
./example.com-wp-content-YYYY-MM-DD_HHMM.tar.gz
```

Both the database dump and `wp-content` archive should be present.

### 4. Extract the Backup to a Temporary Directory

Create a temporary test directory:

```bash
mkdir -p /tmp/backup-test
```

Extract the backup:

```bash
tar -xzf example.com-wp-YYYY-MM-DD_HHMM.tar.gz \
    -C /tmp/backup-test
```

Check the extracted files:

```bash
ls -lh /tmp/backup-test/
```

### 5. Check the Database Backup

Verify that the SQL dump is not empty:

```bash
du -h /tmp/backup-test/*.sql
```

You can also inspect the beginning of the dump:

```bash
head -n 30 /tmp/backup-test/*.sql
```

The file should contain MySQL dump information and SQL statements.

> A database file being present does not necessarily mean `mysqldump` completed successfully. Always check the output of the backup script for database errors.

### 6. Test the `wp-content` Archive

Verify that the nested `wp-content` archive can be read:

```bash
tar -tzf /tmp/backup-test/*wp-content*.tar.gz > /dev/null \
    && echo "wp-content OK" \
    || echo "wp-content FAILED"
```

You can also inspect its contents:

```bash
tar -tzf /tmp/backup-test/*wp-content*.tar.gz | head -n 30
```

You should see WordPress directories such as:

```text
wp-content/
wp-content/plugins/
wp-content/themes/
wp-content/uploads/
```

### 7. Clean Up

After testing, remove the temporary files:

```bash
rm -rf /tmp/backup-test
```

### ✅ What a Successful Test Confirms

A backup should only be considered usable when:

* The final `.tar.gz` archive passes the integrity test.
* The database `.sql` file exists and is not empty.
* The `wp-content` archive exists and passes its integrity test.
* The database dump contains valid SQL content.
* No `mysqldump` or `tar` errors occurred while creating the backup.

For critical backups, periodically perform a full restoration on a test WordPress installation. A successful restore is the strongest confirmation that the backup is usable.


