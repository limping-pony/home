FROM node:22-alpine
WORKDIR /app
COPY package.json server.js ./
COPY public ./public
ENV HOST=0.0.0.0 PORT=8788 DATA_DIR=/data
VOLUME /data
EXPOSE 8788
USER node
CMD ["node", "server.js"]
