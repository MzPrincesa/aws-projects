FROM node:24.14.0

WORKDIR /app

COPY package*.json ./

RUN npm ci

COPY . .

ENV PORT=3000

EXPOSE 3000

CMD [ "npm", "start" ]