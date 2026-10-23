FROM node:22-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev --no-audit --no-fund
COPY . .
EXPOSE 3000
# Dentro de un contenedor 127.0.0.1 es el propio contenedor: pasa DB_HOST=host.docker.internal (u otra IP) al ejecutarlo.
CMD ["node", "app.js"]
