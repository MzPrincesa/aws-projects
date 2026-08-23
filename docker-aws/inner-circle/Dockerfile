# ---- Build stage ----
FROM node:24.19.0-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .

# ---- Runtime stage ----
FROM node:24.19.0-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000
COPY --from=build --chown=node:node /app /app
USER node
EXPOSE 3000
CMD ["npm", "start"]