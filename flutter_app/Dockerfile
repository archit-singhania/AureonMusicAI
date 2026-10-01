FROM ghcr.io/cirruslabs/flutter:3.47.3 AS build
WORKDIR /app
COPY aureon/ ./
RUN flutter pub get && flutter build web --release --dart-define=API_BASE_URL=
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
