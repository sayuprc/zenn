FROM node:20-bookworm

USER node

WORKDIR /app

CMD ["yarn", "preview"]
