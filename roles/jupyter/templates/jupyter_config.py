# {{ ansible_managed }}
c = get_config()

# Server settings
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = {{ jupyter_port }}
c.ServerApp.open_browser = False
c.ServerApp.root_dir = '{{ jupyter_home }}'
c.ServerApp.base_url = '/jupyter/'
c.ServerApp.allow_root = True

# Authentication - use token-based auth
c.IdentityProvider.token = '{{ jupyter_password }}'

# Allow remote access through reverse proxy
c.ServerApp.allow_remote_access = True
c.ServerApp.allow_origin = '*'

# Disable XSRF for reverse proxy compatibility
c.ServerApp.disable_check_xsrf = True

# Trust all notebooks
c.ServerApp.trust_xheaders = True
