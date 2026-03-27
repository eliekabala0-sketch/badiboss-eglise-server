FROM nginx:alpine

# Copy nginx config (uses envsubst via the templates/ mechanism — Railway injects $PORT at runtime)
COPY nginx.conf /etc/nginx/templates/default.conf.template

# Create a placeholder index.html so nginx has something to serve
# while the Flutter project sources are being added to the repo
RUN mkdir -p /usr/share/nginx/html && \
    cat > /usr/share/nginx/html/index.html <<'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>BadiBoss Église</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: #1a1a2e;
      color: #eee;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
    }
    .card {
      text-align: center;
      padding: 2.5rem 3rem;
      background: #16213e;
      border-radius: 12px;
      box-shadow: 0 8px 32px rgba(0,0,0,0.4);
      max-width: 480px;
    }
    h1 { font-size: 1.8rem; margin-bottom: 0.5rem; color: #e94560; }
    p  { font-size: 1rem; color: #aaa; margin-top: 0.75rem; line-height: 1.6; }
    .badge {
      display: inline-block;
      margin-top: 1.5rem;
      padding: 0.35rem 0.9rem;
      background: #e94560;
      border-radius: 999px;
      font-size: 0.8rem;
      font-weight: 600;
      letter-spacing: 0.05em;
      text-transform: uppercase;
    }
  </style>
</head>
<body>
  <div class="card">
    <h1>BadiBoss Église</h1>
    <p>Le déploiement est en cours de configuration.<br/>L'application Flutter sera disponible très prochainement.</p>
    <span class="badge">Bientôt disponible</span>
  </div>
</body>
</html>
EOF

EXPOSE 8080
