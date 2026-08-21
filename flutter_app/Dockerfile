FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY aureon/pubspec.* ./
RUN flutter pub get
COPY aureon/ ./
RUN flutter create . --platforms web
RUN flutter build web

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
