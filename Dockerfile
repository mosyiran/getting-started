# Install the base requirements for the app.
# This stage is to support development.
FROM python:alpine@sha256:1a5c14626ca7911ae16465aa338ed3f5c1bc0212a3eb16263d0d476bf3d0132d AS base
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

FROM node:12-alpine@sha256:d4b15b3d48f42059a15bd659be60afe21762aae9d6cbea6f124440895c27db68 AS app-base
WORKDIR /app
COPY app/package.json app/yarn.lock ./
COPY app/spec ./spec
COPY app/src ./src

# Run tests to validate app
FROM app-base AS test
RUN apk add --no-cache python3 g++ make
RUN yarn install
RUN yarn test

# Clear out the node_modules and create the zip
FROM app-base AS app-zip-creator
COPY app/package.json app/yarn.lock ./
COPY app/spec ./spec
COPY app/src ./src
RUN apk add zip && \
    zip -r /app.zip /app

# Dev-ready container - actual files will be mounted in
FROM base AS dev
CMD ["mkdocs", "serve", "-a", "0.0.0.0:8000"]

# Do the actual build of the mkdocs site
FROM base AS build
COPY . .
RUN mkdocs build

# Extract the static content from the build
# and use a nginx image to serve the content
FROM nginx:alpine@sha256:207332a7d1d17b884b5a0e94bcf7c0f67f1a518b9bf8da6c2ea72c83eec889b8
COPY --from=app-zip-creator /app.zip /usr/share/nginx/html/assets/app.zip
COPY --from=build /app/site /usr/share/nginx/html
