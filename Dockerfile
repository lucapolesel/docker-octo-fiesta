# syntax=docker/dockerfile:1-labs
FROM public.ecr.aws/docker/library/alpine:3.23.2 AS base
ENV TZ=UTC
WORKDIR /src

# source stage =================================================================
FROM base AS source

# get and extract source from git
ARG VERSION
ADD https://github.com/V1ck3s/octo-fiesta.git#$VERSION ./

# normalize arch ===============================================================
FROM base AS base-arm64
ENV RUNTIME=linux-musl-arm64
FROM base AS base-amd64
ENV RUNTIME=linux-musl-x64

# build ========================================================================
FROM base-$TARGETARCH AS build-backend

# dependencies
RUN apk add --no-cache dotnet9-sdk

# dotnet source
COPY --from=source /src/ ./src

# build backend
ARG BRANCH
ARG VERSION
RUN CLEAN_VERSION=$(echo ${VERSION} | sed 's/^v//') && \
    mkdir /build && \
    dotnet publish ./src/octo-fiesta.sln \
        -p:RuntimeIdentifiers=$RUNTIME \
        -p:Configuration=Release \
        -p:Version=$CLEAN_VERSION \
        -p:PublishDir=/build/bin

# versioning (runtime)
ARG COMMIT=$CLEAN_VERSION
COPY <<EOF /build/package_info
PackageAuthor=[lucapolesel](https://github.com/lucapolesel/docker-octo-fiesta)
UpdateMethod=Docker
Branch=$BRANCH
PackageVersion=$COMMIT
EOF

# runtime stage ================================================================
FROM base

ARG VERSION
ENV S6_VERBOSITY=0 S6_BEHAVIOUR_IF_STAGE2_FAILS=2 PUID=65534 PGID=65534 UMASK=002 ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# copy files
COPY --from=build-backend /build /app
COPY ./rootfs/. /

# runtime dependencies
RUN apk add --no-cache tzdata s6-overlay aspnetcore9-runtime sqlite-libs curl

# run using s6-overlay
ENTRYPOINT ["/init"]
