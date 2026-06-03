# Multi-stage Dockerfile for {{SERVICE_NAME}}
# Supports both Node.js and .NET — remove the unused stage

# ─────────────────────────────────────────────
# Node.js build stage
# ─────────────────────────────────────────────
FROM node:20-alpine AS node-builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build --if-present

# ─────────────────────────────────────────────
# .NET build stage
# ─────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS dotnet-builder
WORKDIR /app
COPY src/*.csproj ./src/
RUN dotnet restore ./src/
COPY . .
RUN dotnet publish ./src/ -c Release -o /out

# ─────────────────────────────────────────────
# Runtime image (Node.js)
# ─────────────────────────────────────────────
FROM node:20-alpine AS node-runtime
WORKDIR /app
ENV NODE_ENV=production
COPY --from=node-builder /app/node_modules ./node_modules
COPY --from=node-builder /app/dist ./dist
COPY --from=node-builder /app/package.json .
EXPOSE 3000
USER node
CMD ["node", "dist/index.js"]

# ─────────────────────────────────────────────
# Runtime image (.NET)
# ─────────────────────────────────────────────
# FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS dotnet-runtime
# WORKDIR /app
# COPY --from=dotnet-builder /out .
# EXPOSE 8080
# USER app
# ENTRYPOINT ["dotnet", "{{SERVICE_NAME}}.dll"]
