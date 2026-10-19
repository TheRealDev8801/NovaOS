# NovaOS Website

Static landing page for NovaOS — no build step, no dependencies.

## Preview locally

```bash
cd website
python3 -m http.server 8080
# open http://localhost:8080
```

## Deploy to novaos.aibotv2-hosting.biz

Copy the contents of this directory to the web root of the host serving that
subdomain (nginx, Caddy, Apache, or any static host):

```bash
rsync -av --delete website/ user@host:/var/www/novaos/
```

Minimal nginx server block:

```nginx
server {
    listen 80;
    server_name novaos.aibotv2-hosting.biz;
    root /var/www/novaos;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

Then point the DNS `A`/`AAAA` record for `novaos.aibotv2-hosting.biz` at the
host, and add TLS (e.g. `certbot --nginx` or Caddy's automatic HTTPS).

## Files

- `index.html` — single-page site
- `styles.css` — dark "nova" theme
- `favicon.svg` — logo / favicon
