#!/bin/bash

# Database backup script for Supabase
# Usage: ./backup_database.sh [local|remote|both]

set -e

# Configuration
BACKUP_DIR="backups"
DATE=$(date +%Y%m%d_%H%M%S)
PROJECT_NAME="that-task-api"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to create local backup
backup_local() {
    echo "Creating local database backup..."
    
    # Check if Supabase is running
    if ! supabase status > /dev/null 2>&1; then
        echo "Starting Supabase local development..."
        supabase start
    fi
    
    # Schema backup
    echo "Backing up schema..."
    supabase db dump --schema-only > "$BACKUP_DIR/${PROJECT_NAME}_schema_local_${DATE}.sql"
    
    # Full backup
    echo "Backing up full database..."
    supabase db dump > "$BACKUP_DIR/${PROJECT_NAME}_full_local_${DATE}.sql"
    
    # Custom format backup (compressed)
    echo "Creating compressed backup..."
    supabase db dump --format custom > "$BACKUP_DIR/${PROJECT_NAME}_full_local_${DATE}.dump"
    
    echo "Local backup completed successfully!"
    echo "Files created:"
    echo "  - Schema: $BACKUP_DIR/${PROJECT_NAME}_schema_local_${DATE}.sql"
    echo "  - Full SQL: $BACKUP_DIR/${PROJECT_NAME}_full_local_${DATE}.sql"
    echo "  - Compressed: $BACKUP_DIR/${PROJECT_NAME}_full_local_${DATE}.dump"
}

# Function to create remote backup
backup_remote() {
    echo "Creating remote database backup..."
    
    # Check if project is linked
    if ! supabase projects list > /dev/null 2>&1; then
        echo "Error: No remote project linked. Run 'supabase link' first."
        exit 1
    fi
    
    # Schema backup
    echo "Backing up remote schema..."
    supabase db dump --remote --schema-only > "$BACKUP_DIR/${PROJECT_NAME}_schema_remote_${DATE}.sql"
    
    # Full backup
    echo "Backing up remote database..."
    supabase db dump --remote > "$BACKUP_DIR/${PROJECT_NAME}_full_remote_${DATE}.sql"
    
    # Custom format backup (compressed)
    echo "Creating compressed remote backup..."
    supabase db dump --remote --format custom > "$BACKUP_DIR/${PROJECT_NAME}_full_remote_${DATE}.dump"
    
    echo "Remote backup completed successfully!"
    echo "Files created:"
    echo "  - Schema: $BACKUP_DIR/${PROJECT_NAME}_schema_remote_${DATE}.sql"
    echo "  - Full SQL: $BACKUP_DIR/${PROJECT_NAME}_full_remote_${DATE}.sql"
    echo "  - Compressed: $BACKUP_DIR/${PROJECT_NAME}_full_remote_${DATE}.dump"
}

# Function to verify backup
verify_backup() {
    local backup_file="$1"
    echo "Verifying backup: $backup_file"
    
    if [[ "$backup_file" == *.sql ]]; then
        # Check if SQL file is valid
        if head -n 10 "$backup_file" | grep -q "PostgreSQL database dump"; then
            echo "✓ SQL backup appears valid"
        else
            echo "✗ SQL backup may be corrupted"
            return 1
        fi
    elif [[ "$backup_file" == *.dump ]]; then
        # Check if custom format file is valid
        if file "$backup_file" | grep -q "PostgreSQL custom database dump"; then
            echo "✓ Custom format backup appears valid"
        else
            echo "✗ Custom format backup may be corrupted"
            return 1
        fi
    fi
    
    # Check file size
    local size=$(stat -f%z "$backup_file" 2>/dev/null || stat -c%s "$backup_file" 2>/dev/null)
    if [ "$size" -gt 100 ]; then
        echo "✓ Backup file size: $(numfmt --to=iec $size)"
    else
        echo "✗ Backup file seems too small: $size bytes"
        return 1
    fi
}

# Main execution
case "${1:-local}" in
    "local")
        backup_local
        verify_backup "$BACKUP_DIR/${PROJECT_NAME}_full_local_${DATE}.sql"
        ;;
    "remote")
        backup_remote
        verify_backup "$BACKUP_DIR/${PROJECT_NAME}_full_remote_${DATE}.sql"
        ;;
    "both")
        backup_local
        backup_remote
        verify_backup "$BACKUP_DIR/${PROJECT_NAME}_full_local_${DATE}.sql"
        verify_backup "$BACKUP_DIR/${PROJECT_NAME}_full_remote_${DATE}.sql"
        ;;
    *)
        echo "Usage: $0 [local|remote|both]"
        echo "  local  - Backup local development database"
        echo "  remote - Backup remote production database"
        echo "  both   - Backup both local and remote databases"
        exit 1
        ;;
esac

echo ""
echo "Backup process completed!"
echo "Backup location: $BACKUP_DIR/"