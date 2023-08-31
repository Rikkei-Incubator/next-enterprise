
# Install dependencies only when needed
FROM node:16-alpine AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat curl make python3 git
WORKDIR /app

ENV HUSKY=0
ENV CI=true

# Install dependencies based on the preferred package manager
COPY package.json .npmrc pnpm-lock.yaml* ./
RUN if [ -f pnpm-lock.yaml ]; then yarn global add pnpm && pnpm i; \
  else echo "Lockfile not found." && exit 1; \
  fi

# Rebuild the source code only when needed
FROM node:16-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

ARG APP_ENV
ARG NEXT_PUBLIC_BASE_URL
ARG NEXT_PUBLIC_API_ENDPOINT
ARG NEXT_PUBLIC_BASE_STORAGE
ARG NEXT_PUBLIC_CLIENT_ID_GOOGLE
ARG NEXT_PUBLIC_SCOPE_GOOGLE
ARG NEXT_PUBLIC_APP_ID_FACEBOOK
ARG APP_SECRET_FACEBOOK

ENV APP_ENV=$APP_ENV
ENV NEXT_PUBLIC_BASE_URL=$NEXT_PUBLIC_BASE_URL
ENV NEXT_PUBLIC_API_ENDPOINT=$NEXT_PUBLIC_API_ENDPOINT
ENV NEXT_PUBLIC_BASE_STORAGE=$NEXT_PUBLIC_BASE_STORAGE
ENV NEXT_PUBLIC_CLIENT_ID_GOOGLE=$NEXT_PUBLIC_CLIENT_ID_GOOGLE
ENV NEXT_PUBLIC_SCOPE_GOOGLE=$NEXT_PUBLIC_SCOPE_GOOGLE
ENV NEXT_PUBLIC_APP_ID_FACEBOOK=$NEXT_PUBLIC_APP_ID_FACEBOOK
ENV APP_SECRET_FACEBOOK=$APP_SECRET_FACEBOOK

ENV NEXT_TELEMETRY_DISABLED 1

RUN yarn build

# Production image, copy all the files and run next
FROM node:16-alpine AS runner
WORKDIR /app

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/next.config.js ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 7001

ENV PORT 7001

CMD ["node", "server.js"]
