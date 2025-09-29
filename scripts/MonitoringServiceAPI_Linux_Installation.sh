#!/usr/bin/env bash

# MonitoringServiceAPI - Linux Installation Script
# This script installs prerequisites and sets up the MonitoringServiceAPI on Linux

set -e  # Exit on any error

# Default configuration
INSTALL_PATH="/opt/monitoringapi"
DATA_PATH=""
SERVICE_NAME="monitoringapi"
SERVICE_USER="monitoringapi"
SKIP_DOTNET=false
VERBOSE=false
INTERACTIVE=true
API_PORT=5000

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --install-path)
            INSTALL_PATH="$2"
            shift 2
            ;;
        --data-path)
            DATA_PATH="$2"
            shift 2
            ;;
        --api-port)
            API_PORT="$2"
            shift 2
            ;;
        --skip-dotnet)
            SKIP_DOTNET=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --non-interactive)
            INTERACTIVE=false
            shift
            ;;
        -h|--help)
            echo "MonitoringServiceAPI Linux Installation Script"
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --install-path PATH    Installation directory (default: /opt/monitoringapi)"
            echo "  --data-path PATH       Data directory (will prompt if not specified)"
            echo "  --api-port PORT        API port (default: 5000)"
            echo "  --skip-dotnet         Skip .NET installation"
            echo "  --verbose             Verbose output"
            echo "  --non-interactive     Skip user prompts (requires --data-path)"
            echo "  -h, --help            Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Logging functions
log_info() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_step() {
    echo -e "${BLUE}==>${NC} $1"
}

verbose_log() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    else
        log_error "Cannot detect Linux distribution"
        exit 1
    fi
    
    verbose_log "Detected distribution: $DISTRO $VERSION"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
    log_info "Running as root"
}

# Function to prompt for data path
prompt_data_path() {
    if [ -n "$DATA_PATH" ]; then
        log_info "Using specified data path: $DATA_PATH"
        return 0
    fi

    if [ "$INTERACTIVE" = false ]; then
        log_error "Data path must be specified when using --non-interactive mode"
        exit 1
    fi

    echo ""
    echo -e "${BLUE}=== Data Directory Configuration ===${NC}"
    echo "The data directory will store:"
    echo "  - Database files (SQLite)"
    echo "  - Application logs"
    echo "  - Configuration files"
    echo "  - Temporary files"
    echo ""
    echo "Recommended locations:"
    echo "  - /var/monitoringapi (system-wide, requires root)"
    echo "  - /home/\$USER/monitoringapi (user-specific)"
    echo "  - /opt/monitoringapi/data (alongside application)"
    echo ""

    while true; do
        read -p "Enter the data directory path: " DATA_PATH
        
        if [ -z "$DATA_PATH" ]; then
            log_error "Data path cannot be empty"
            continue
        fi

        # Expand tilde and make absolute
        DATA_PATH=$(eval echo "$DATA_PATH")
        if command -v realpath >/dev/null 2>&1; then
            DATA_PATH=$(realpath -m "$DATA_PATH")
        fi

        # Validate path
        if [[ "$DATA_PATH" =~ ^/ ]]; then
            log_info "Using data path: $DATA_PATH"
            break
        else
            log_error "Please provide an absolute path (starting with /)"
        fi
    done
}

# Function to validate and create data path
validate_data_path() {
    log_step "Validating data path..."
    
    # Check if path is writable by root
    if ! mkdir -p "$DATA_PATH" 2>/dev/null; then
        log_error "Cannot create data directory: $DATA_PATH"
        log_info "Please ensure you have write permissions to the parent directory"
        exit 1
    fi

    # Check if we can write to the directory
    if ! touch "$DATA_PATH/.test_write" 2>/dev/null; then
        log_error "Cannot write to data directory: $DATA_PATH"
        exit 1
    fi
    rm -f "$DATA_PATH/.test_write"

    log_info "Data path validated: $DATA_PATH"
}

# Function to install package manager packages
install_packages() {
    log_step "Installing required packages..."
    
    case $DISTRO in
        ubuntu|debian)
            apt-get update
            apt-get install -y curl wget gpg software-properties-common apt-transport-https nginx
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                dnf install -y curl wget gpg nginx
            else
                yum install -y curl wget gpg nginx
            fi
            ;;
        *)
            log_warn "Unsupported distribution: $DISTRO. Please install curl, wget, gpg, and nginx manually."
            ;;
    esac
    
    log_info "Required packages installed"
}

# Function to check .NET 8 installation
check_dotnet8() {
    if command -v dotnet &> /dev/null; then
        if dotnet --list-runtimes | grep -q "Microsoft.AspNetCore.App 8"; then
            log_info ".NET 8 ASP.NET Core Runtime found"
            return 0
        fi
    fi
    return 1
}

# Function to install .NET 8
install_dotnet8() {
    log_step "Installing .NET 8 Runtime..."
    
    case $DISTRO in
        ubuntu|debian)
            # Add Microsoft package repository
            wget https://packages.microsoft.com/config/$DISTRO/$VERSION/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
            dpkg -i packages-microsoft-prod.deb
            rm packages-microsoft-prod.deb
            
            apt-get update
            apt-get install -y aspnetcore-runtime-8.0
            ;;
        centos|rhel)
            # Add Microsoft package repository
            rpm --import https://packages.microsoft.com/keys/microsoft.asc
            wget -O /etc/yum.repos.d/microsoft-prod.repo https://packages.microsoft.com/config/$DISTRO/$VERSION/prod.repo
            
            if command -v dnf &> /dev/null; then
                dnf install -y aspnetcore-runtime-8.0
            else
                yum install -y aspnetcore-runtime-8.0
            fi
            ;;
        fedora)
            rpm --import https://packages.microsoft.com/keys/microsoft.asc
            wget -O /etc/yum.repos.d/microsoft-prod.repo https://packages.microsoft.com/config/fedora/$VERSION/prod.repo
            dnf install -y aspnetcore-runtime-8.0
            ;;
        *)
            log_error "Automatic .NET installation not supported for $DISTRO"
            log_info "Please install .NET 8 ASP.NET Core Runtime manually from:"
            log_info "https://docs.microsoft.com/en-us/dotnet/core/install/"
            exit 1
            ;;
    esac
    
    # Verify installation via package manager; if not found, fallback to dotnet-install.sh
    if check_dotnet8; then
        log_info ".NET 8 installed successfully"
        return 0
    fi

    log_warn "ASP.NET Core 8 runtime not found via package manager. Falling back to dotnet-install.sh"
    # Use Microsoft's install script to install ASP.NET Core runtime system-wide
    if command -v curl &> /dev/null; then
        curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
    else
        wget -q https://dot.net/v1/dotnet-install.sh -O /tmp/dotnet-install.sh
    fi
    chmod +x /tmp/dotnet-install.sh
    /tmp/dotnet-install.sh --runtime aspnetcore --channel 8.0 --install-dir /usr/share/dotnet
    ln -sf /usr/share/dotnet/dotnet /usr/bin/dotnet || true

    # Verify installation after fallback
    if check_dotnet8; then
        log_info ".NET 8 installed successfully (via dotnet-install.sh)"
    else
        log_error "Failed to verify .NET 8 installation after fallback"
        exit 1
    fi
}

# Function to create system user
create_service_user() {
    log_step "Creating service user..."
    
    if ! id "$SERVICE_USER" &>/dev/null; then
        useradd --system --home-dir "$INSTALL_PATH" --shell /bin/false "$SERVICE_USER"
        log_info "Created user: $SERVICE_USER"
    else
        log_info "User $SERVICE_USER already exists"
    fi
}

# Function to create directory structure
create_directories() {
    log_step "Creating directory structure..."
    
    directories=(
        "$INSTALL_PATH"
        "$INSTALL_PATH/logs"
        "$DATA_PATH"
        "$DATA_PATH/database"
        "$DATA_PATH/logs"
        "$DATA_PATH/config"
        "$DATA_PATH/temp"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        verbose_log "Created directory: $dir"
    done
    
    # Set ownership
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_PATH"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$DATA_PATH"
    
    # Set permissions
    chmod 755 "$INSTALL_PATH"
    chmod 755 "$DATA_PATH"
    chmod 755 "$DATA_PATH/database"
    chmod 755 "$DATA_PATH/logs"
    chmod 755 "$DATA_PATH/config"
    chmod 755 "$DATA_PATH/temp"
    
    log_info "Directory structure created with proper permissions"
}

# Function to update configuration files
update_config_files() {
    log_step "Updating configuration files..."
    
    local config_files=("$INSTALL_PATH/appsettings.json" "$INSTALL_PATH/appsettings.Development.json")
    
    for config_file in "${config_files[@]}"; do
        if [ -f "$config_file" ]; then
            verbose_log "Updating $config_file"
            
            # Create backup
            cp "$config_file" "$config_file.backup"
            
            # Update database path using sed
            sed -i "s|\"Data Source=.*\"|\"Data Source=$DATA_PATH/database/monitoringapi.db\"|g" "$config_file"
            
            # Update API port if needed
            if grep -q "Urls" "$config_file"; then
                sed -i "s|\"Urls\":.*|\"Urls\": \"http://localhost:$API_PORT\"|g" "$config_file"
            fi
            
            log_info "Updated $config_file"
        fi
    done
}

# Function to create systemd service
create_systemd_service() {
    log_step "Creating systemd service..."
    
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=MonitoringServiceAPI - Monitoring and Management API Service
After=network.target

[Service]
Type=simple
TimeoutStartSec=120
TimeoutStopSec=30
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_PATH
ExecStart=/usr/bin/dotnet $INSTALL_PATH/MonitoringServiceAPI.dll
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=$SERVICE_NAME
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=ASPNETCORE_URLS=http://localhost:$API_PORT

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=false
ReadWritePaths=$INSTALL_PATH $DATA_PATH
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    
    log_info "Systemd service created and enabled"
}

# Function to configure Nginx reverse proxy
configure_nginx() {
    log_step "Configuring Nginx reverse proxy..."
    
    # Create Nginx configuration
    cat > "/etc/nginx/sites-available/$SERVICE_NAME" << EOF
server {
    listen 80;
    server_name localhost;
    
    # API endpoints
    location /api/ {
        proxy_pass http://localhost:$API_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://localhost:$API_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # SignalR hub
    location /hubs/ {
        proxy_pass http://localhost:$API_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;
}
EOF

    # Enable the site and disable default
    ln -sfn /etc/nginx/sites-available/$SERVICE_NAME /etc/nginx/sites-enabled/$SERVICE_NAME
    rm -f /etc/nginx/sites-enabled/default
    
    # Test and reload Nginx
    nginx -t && systemctl reload nginx
    systemctl enable nginx
    
    log_info "Nginx configured successfully"
}

# Function to create deployment guide
create_deployment_guide() {
    cat > "$INSTALL_PATH/DEPLOYMENT_GUIDE.txt" << EOF
MonitoringServiceAPI - Deployment Guide

1) Publish application on a build machine:
   dotnet publish -c Release -o publish

2) Copy published files to the target machine:
   sudo cp -r publish/* "$INSTALL_PATH/"
   sudo chown -R $SERVICE_USER:$SERVICE_USER "$INSTALL_PATH"

3) Configure application:
   - Update database connection in appsettings.json
   - Database path is set to: $DATA_PATH/database/monitoringapi.db
   - Configure Azure Storage connection strings
   - API runs on port: $API_PORT

4) Manage systemd service:
   sudo systemctl daemon-reload
   sudo systemctl enable $SERVICE_NAME
   sudo systemctl start $SERVICE_NAME
   sudo systemctl status $SERVICE_NAME

5) Monitor logs:
   sudo journalctl -u $SERVICE_NAME -f

6) Configuration:
   - Service runs as user: $SERVICE_USER
   - Database: $DATA_PATH/database/monitoringapi.db
   - Logs: $DATA_PATH/logs/
   - Configuration: $DATA_PATH/config/
   - API URL: http://localhost:$API_PORT
   - Nginx proxy: http://localhost/api/

7) API Endpoints:
   - Health: http://localhost/health
   - API: http://localhost/api/
   - Swagger: http://localhost:$API_PORT/swagger (direct access)
EOF
    log_info "Deployment guide written to: $INSTALL_PATH/DEPLOYMENT_GUIDE.txt"
}

# Function to create startup script
create_startup_script() {
    cat > "$INSTALL_PATH/start.sh" << EOF
#!/bin/bash
cd "$INSTALL_PATH"
echo "Starting MonitoringServiceAPI..."
dotnet MonitoringServiceAPI.dll
EOF

    chmod +x "$INSTALL_PATH/start.sh"
    chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_PATH/start.sh"
    
    log_info "Startup script created: $INSTALL_PATH/start.sh"
}

# Function to setup log rotation
setup_log_rotation() {
    log_step "Setting up log rotation..."
    
    cat > "/etc/logrotate.d/$SERVICE_NAME" << EOF
$INSTALL_PATH/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $SERVICE_USER $SERVICE_USER
    postrotate
        systemctl reload $SERVICE_NAME || true
    endscript
}

$DATA_PATH/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $SERVICE_USER $SERVICE_USER
}
EOF

    log_info "Log rotation configured"
}

# Main installation process
main() {
    echo -e "${GREEN}=== MonitoringServiceAPI Linux Installation ===${NC}"
    echo "Install Path: $INSTALL_PATH"
    echo "Service Name: $SERVICE_NAME"
    echo "API Port: $API_PORT"
    echo ""

    # Check prerequisites
    check_root
    detect_distro
    
    # Prompt for data path if not specified
    prompt_data_path
    validate_data_path
    
    echo "Data Path: $DATA_PATH"
    echo ""

    # Install packages
    install_packages

    # Install .NET 8 if needed
    if [ "$SKIP_DOTNET" = false ]; then
        if ! check_dotnet8; then
            install_dotnet8
        else
            log_info ".NET 8 is already installed"
        fi
    fi

    # Create user and directories
    create_service_user
    create_directories

    # Check if application files exist
    if [ ! -f "$INSTALL_PATH/MonitoringServiceAPI.dll" ]; then
        log_warn "Application files not found in $INSTALL_PATH"
        log_info "Please publish the application to this directory:"
        echo "  cd path/to/MonitoringServiceAPI"
        echo "  dotnet publish -c Release -o \"$INSTALL_PATH\""
        echo "  sudo chown -R $SERVICE_USER:$SERVICE_USER \"$INSTALL_PATH\""
        echo ""
        log_info "Creating deployment guide..."
        create_deployment_guide
        log_info "Run this script again after copying the application files"
        exit 0
    fi

    # Configure application
    update_config_files
    create_systemd_service
    configure_nginx
    create_startup_script
    setup_log_rotation
    create_deployment_guide

    echo ""
    echo -e "${GREEN}=== Installation Complete ===${NC}"
    echo "Application Path: $INSTALL_PATH"
    echo "Data Path: $DATA_PATH"
    echo "Database: $DATA_PATH/database/monitoringapi.db"
    echo "Service: $SERVICE_NAME"
    echo "API Port: $API_PORT"
    echo "Nginx Proxy: http://localhost/api/"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Configure Azure Storage connection string in appsettings.json"
    echo "2. Start the service: sudo systemctl start $SERVICE_NAME"
    echo "3. Check status: sudo systemctl status $SERVICE_NAME"
    echo "4. Monitor logs: sudo journalctl -u $SERVICE_NAME -f"
    echo "5. Test API: curl http://localhost/health"
    echo ""
    echo "For detailed instructions, see: $INSTALL_PATH/DEPLOYMENT_GUIDE.txt"
}

# Run main function
main "$@"


