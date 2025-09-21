#!/bin/bash

# Database restore script for Supabase
# Usage: ./restore_database.sh <backup_file> [local|remote]

set -e

# Check if backup file is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <backup_file> [local|remote]"
    echo "Example: $0 backups/that-task-api_full_local_20241220_143022.sql local"
    exit 1
fi

BACKUP_FILE="$1"
TARGET="${2:-local}"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file '$BACKUP_FILE' not found!"
    exit 1
fi

echo "Restoring database from: $BACKUP_FILE"
echo "Target: $TARGET"

# Function to restore to local database
restore_local() {
    echo "Restoring to local database..."
    
    # Check if Supabase is running
    if ! supabase status > /dev/null 2>&1; then
        echo "Starting Supabase local development..."
        supabase start
    fi
    
    # Reset local database first
    echo "Resetting local database..."
    supabase db reset --no-seed
    
    # Restore from backup
    echo "Restoring from backup..."
    if [[ "$BACKUP_FILE" == *.sql ]]; then
        # SQL format
        psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" < "$BACKUP_FILE"
    elif [[ "$BACKUP_FILE" == *.dump ]]; then
        # Custom format
        pg_restore -d "postgresql://postgres:postgres@127.0.0.1:54322/postgres" "$BACKUP_FILE"
    else
        echo "Error: Unsupported backup file format. Use .sql or .dump files."
        exit 1
    fi
    
    echo "Local database restored successfully!"
}

# Function to restore to remote database
restore_remote() {
    echo "Restoring to remote database..."
    
    # Check if project is linked
    if ! supabase projects list > /dev/null 2>&1; then
        echo "Error: No remote project linked. Run 'supabase link' first."
        exit 1
    fi
    
    echo "WARNING: This will overwrite your remote production database!"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Restore cancelled."
        exit 0
    fi
    
    # Get remote database connection string
    echo "Getting remote database connection..."
    # Note: This would require additional setup for remote restore
    echo "Error: Direct remote restore requires additional configuration."
    echo "Please use Supabase Dashboard or contact support for production restores."
    exit 1
}

# Verify backup file before restore
echo "Verifying backup file..."
if [[ "$BACKUP_FILE" == *.sql ]]; then
    if head -n 10 "$BACKUP_FILE" | grep -q "PostgreSQL database dump"; then
        echo "✓ SQL backup file appears valid"
    else
        echo "✗ SQL backup file may be corrupted"
        exit 1
    fi
elif [[ "$BACKUP_FILE" == *.dump ]]; then
    if file "$BACKUP_FILE" | grep -q "PostgreSQL custom database dump"; then
        echo "✓ Custom format backup file appears valid"
    else
        echo "✗ Custom format backup file may be corrupted"
        exit 1
    fi
fi

# Execute restore based on target
case "$TARGET" in
    "local")
        restore_local
        ;;
    "remote")
        restore_remote
        ;;
    *)
        echo "Error: Invalid target '$TARGET'. Use 'local' or 'remote'."
        exit 1
        ;;
esac

echo "Restore process completed!"