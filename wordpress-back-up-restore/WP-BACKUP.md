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

After creating a backup, verify that the final archive, database dump, and `wp-content` archive are readable before relying on the backup.

The commands below are formatted as **complete copy-pasteable command blocks**. Run each block separately.

> Replace `example.com-wp-YYYY-MM-DD_HHMM.tar.gz` with the actual filename of your backup.

### 1. Go to the Backup Directory

```bash
cd /sites/example.com/backups
```

### 2. Test the Final Backup Archive

Copy and paste this entire block:

```bash
if tar -tzf example.com-wp-YYYY-MM-DD_HHMM.tar.gz > /dev/null; then
    echo "✅ Archive OK"
else
    echo "❌ Archive FAILED"
fi
```

If the archive is readable, you should see:

```text
✅ Archive OK
```

> This verifies that the `.tar.gz` archive can be read. It does not by itself prove that the database dump is valid.

### 3. Check What Is Inside the Archive

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

### 4. Create a Temporary Test Directory

This removes any previous test directory and creates a clean one:

```bash
rm -rf /tmp/backup-test
mkdir -p /tmp/backup-test
```

### 5. Extract the Backup

```bash
tar -xzf example.com-wp-YYYY-MM-DD_HHMM.tar.gz -C /tmp/backup-test
```

Then check the extracted files:

```bash
ls -lh /tmp/backup-test
```

You should see both files:

```text
example.com-db-YYYY-MM-DD_HHMM.sql
example.com-wp-content-YYYY-MM-DD_HHMM.tar.gz
```

### 6. Check the Database Backup Size

```bash
du -h /tmp/backup-test/*.sql
```

The SQL file should have a reasonable non-zero size.

You can also check it directly:

```bash
if [ -s /tmp/backup-test/*.sql ]; then
    echo "✅ Database file is not empty"
else
    echo "❌ Database file is empty"
fi
```

### 7. Inspect the Database Dump

View the beginning of the SQL file:

```bash
head -n 30 /tmp/backup-test/*.sql
```

You should see MySQL dump information and SQL statements.

You can also inspect the end:

```bash
tail -n 30 /tmp/backup-test/*.sql
```

A database file being present does **not** guarantee that `mysqldump` completed successfully. The backup script should also finish without any `mysqldump` errors.

### 8. Test the `wp-content` Archive

Copy and paste this complete block:

```bash
if tar -tzf /tmp/backup-test/*wp-content*.tar.gz > /dev/null; then
    echo "✅ wp-content OK"
else
    echo "❌ wp-content FAILED"
fi
```

A successful result should show:

```text
✅ wp-content OK
```

### 9. Inspect the `wp-content` Archive

```bash
tar -tzf /tmp/backup-test/*wp-content*.tar.gz | head -n 30
```

You should see content similar to:

```text
wp-content/
wp-content/plugins/
wp-content/themes/
wp-content/uploads/
```

### 10. Run a Combined Verification

After extracting the backup, you can run these basic checks together:

```bash
echo "Testing database..."

if [ -s /tmp/backup-test/*.sql ]; then
    echo "✅ Database file is not empty"
else
    echo "❌ Database file is empty"
fi

echo ""
echo "Testing wp-content..."

if tar -tzf /tmp/backup-test/*wp-content*.tar.gz > /dev/null; then
    echo "✅ wp-content archive OK"
else
    echo "❌ wp-content archive FAILED"
fi
```

A healthy backup should report:

```text
Testing database...
✅ Database file is not empty

Testing wp-content...
✅ wp-content archive OK
```

### 11. Clean Up

After testing is complete:

```bash
rm -rf /tmp/backup-test
```

This only removes the temporary extracted copy. It does **not** delete the original backup.

## ✅ Backup Verification Checklist

A backup should only be considered usable when:

* The final `.tar.gz` archive passes the archive test.
* The archive contains both the `.sql` and `wp-content.tar.gz` files.
* The database `.sql` file is not empty.
* The SQL file contains database dump content.
* The nested `wp-content` archive passes its archive test.
* The `wp-content` archive contains the expected WordPress directories.
* The original backup process completed without `mysqldump` or `tar` errors.

> **Important:** These checks verify the structure and basic integrity of the backup. For critical backups, periodically perform a complete restoration on a test WordPress installation. A successful restore is the strongest verification that the backup is usable.







```



```
## 🧪 Downloading the Backup Archive

```bash
scp user@YOUR_SERVER_IP:/sites/dev.nijhoom.com/backups/* .
```
