# Docker Registry Mirror

This is a Docker Registry mirror service for caching Docker images, particularly useful for users in China or regions with slow Docker Hub access.

## Features

- **Registry Mirror**: Cache Docker images from Docker Hub and other registries
- **Web UI**: Optional web interface for managing cached images
- **High Performance**: Local caching reduces pull times significantly
- **Storage Management**: Configurable storage cleanup and management
- **Health Monitoring**: Built-in health check endpoints

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Sufficient disk space for image caching (recommend 100GB+)

### Deployment

1. **Create data directory:**
   ```bash
   sudo mkdir -p /data/registry
   sudo chown -R $(whoami):$(whoami) /data/registry
   ```

2. **Start the service:**
   ```bash
   make up
   ```

3. **Check service status:**
   ```bash
   make status
   ```

4. **Test the registry:**
   ```bash
   # Test health
   make health
   
   # Configure Docker daemon to use the mirror
   # Add to /etc/docker/daemon.json:
   {
     "registry-mirrors": ["http://your-server-ip:5000"]
   }
   
   # Restart Docker
   sudo systemctl restart docker
   ```

### Usage Examples

#### Configure Docker to use the mirror

1. **Edit Docker daemon config:**
   ```bash
   sudo nano /etc/docker/daemon.json
   ```

2. **Add registry mirror:**
   ```json
   {
     "registry-mirrors": ["http://your-domain.com:5000"],
     "insecure-registries": ["your-domain.com:5000"]
   }
   ```

3. **Restart Docker:**
   ```bash
   sudo systemctl restart docker
   ```

#### Pull images through the mirror

Once configured, all `docker pull` commands will automatically use the mirror:

```bash
# These commands will now use your mirror
docker pull nginx:latest
docker pull redis:alpine
docker pull postgres:15
```

#### Direct registry access

You can also access the registry directly:

```bash
# Check registry health
curl http://your-domain.com:5000/v2/

# List cached repositories
curl http://your-domain.com:5000/v2/_catalog

# Check specific image tags
curl http://your-domain.com:5000/v2/nginx/tags/list
```

## Configuration

### Environment Variables

- `REGISTRY_DATA`: Data storage path (default: `/data/registry`)
- `REGISTRY_PORT`: Registry service port (default: `5000`)
- `REGISTRY_UI_PORT`: Web UI port (default: `5080`)

### Advanced Configuration

Edit `config.yml` to customize:

- **Storage backend**: Filesystem, S3, GCS, etc.
- **Cache TTL**: How long to cache images
- **Authentication**: Enable user authentication
- **Proxy settings**: Configure upstream registries

## Management Commands

```bash
# Service management
make up          # Start services
make down        # Stop services
make restart     # Restart services
make status      # Show status
make log         # Show logs

# Maintenance
make health      # Test health
make catalog     # Show cached images
make backup      # Backup data
make du          # Show disk usage
make prune       # Clean up unused data
make clean       # Remove all data
```

## Monitoring

### Health Check

The registry provides health endpoints:

- `GET /v2/` - Registry API version
- `GET /debug/health` - Detailed health status

### Web UI

Access the web interface at `http://your-domain.com:5080` to:

- Browse cached images
- View image details and tags
- Delete unused images
- Monitor storage usage

### Metrics

For production deployments, consider adding:

- Prometheus metrics collection
- Grafana dashboards
- Log aggregation
- Disk usage monitoring

## Nginx Reverse Proxy

For HTTPS and domain-based access, configure Nginx:

```nginx
server {
    listen 80;
    server_name registry.your-domain.com;
    
    # Redirect to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name registry.your-domain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    client_max_body_size 0;
    chunked_transfer_encoding on;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 900;
    }
}
```

## Troubleshooting

### Common Issues

1. **Permission denied:**
   ```bash
   sudo chown -R $(whoami):$(whoami) /data/registry
   ```

2. **Port already in use:**
   ```bash
   # Check what's using the port
   sudo netstat -tulpn | grep :5000
   
   # Modify port in docker-compose.yml
   ```

3. **Docker daemon not using mirror:**
   ```bash
   # Check Docker configuration
   docker info | grep -A5 "Registry Mirrors"
   
   # Restart Docker after config changes
   sudo systemctl restart docker
   ```

4. **Disk space issues:**
   ```bash
   # Check disk usage
   make du
   
   # Clean up unused images
   make prune
   ```

### Performance Tuning

- **Storage**: Use SSD storage for better performance
- **Memory**: Increase available memory for caching
- **Network**: Ensure good bandwidth to upstream registries
- **Cleanup**: Regular cleanup of unused images

## Security Considerations

- Use HTTPS in production
- Configure authentication if needed
- Restrict network access appropriately
- Regular security updates
- Monitor access logs

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

This project is licensed under the same license as Pigsty.