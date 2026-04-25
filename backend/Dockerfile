# Stage 1: Build
FROM node:20-alpine AS builder

WORKDIR /app

# Install dependencies first (leverage Docker cache)
COPY package*.json ./
# prisma requires openssl
RUN apk add --no-cache openssl
RUN npm ci

# Copy source code and prisma schema
COPY . .

# Generate Prisma Client & Build NextJS app
RUN npx prisma generate
RUN npm run build

# Stage 2: Production
FROM node:20-alpine

WORKDIR /app

RUN apk add --no-cache openssl

# We only copy the `dist`, `prisma` schema (for migrations run), and node_modules
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma

EXPOSE 3000

CMD ["npm", "run", "start"]
