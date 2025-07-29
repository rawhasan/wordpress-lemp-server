## WordPress Backup Restoration Script (`restore-wp-backup.sh`)

This script restores a WordPress site from a previously created backup archive. It pulls the backup from a remote server, extracts its contents, restores the MySQL database, and reinstates the `wp-content` directory.

### :file_folder: What It Does

1. **Prompts for user input**:  
   - Domain name  
   - Old server IP address  
   - SSH username  
   - Backup archive filename

2. **Pulls the backup archive** from the old server using `scp`  
3. **Extracts the archive** into a migration directory  
4. **Restores the database**:  
   - Attempts to extract DB credentials from `wp-config.php`  
   - Falls back to manual input if not found  
5. **Restores `wp-content` directory** by extracting and moving it into the public directory  
6. **Cleans up** temporary files after completion

### :hammer_and_wrench: Configuration

The script uses the following directory structure by default:

```bash
/sites/<domain>/
  ├── backups/
  ├── migrate/
  └── public/
```

Make sure the destination structure exists or is writable by the user running the script.

### :arrow_forward: How to Use

1. **Place the script** in the following directory:
   ```bash
   /sites/example.com/shells/restore-wp-backup.sh
   ```

2. **Run the script:**

   ```bash
   bash wp-backup.sh
   ```

3. **Provide the required information when prompted**.

### :pushpin: Notes

- Ensure SSH access to the old server and that the backup file exists at the specified location.  
- The script expects the backup to include:
  - `wp-content.tar.gz`
  - A `.sql` file for the database  
- The restoration will overwrite any existing `wp-content` directory in the destination.  
- Requires `mysql`, `scp`, and `tar` to be available on the system.
