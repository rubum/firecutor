# Stage 1: Build Elixir
FROM elixir:1.18-otp-26-alpine AS elixir-builder

# Install Python and other dependencies
RUN apk add --no-cache \
    python3 \
    py3-pip \
    build-base \
    py3-numpy \
    py3-pandas

# Stage 2: Create the final image
FROM alpine:latest

# Install Python in the final image
RUN apk add --no-cache \
    python3 \
    py3-numpy \
    py3-pandas

# Copy Elixir and its dependencies from the builder stage
COPY --from=elixir-builder /usr/local/lib/erlang /usr/lib/erlang
COPY --from=elixir-builder /usr/local/bin/elixir /usr/bin/elixir
COPY --from=elixir-builder /usr/local/bin/mix /usr/bin/mix
COPY --from=elixir-builder /usr/local/bin/iex /usr/bin/iex
COPY --from=elixir-builder /usr/local/lib/elixir /usr/lib/elixir

# Set up environment variables
ENV LANG=C.UTF-8
ENV PATH="/usr/bin:/usr/lib/erlang/bin:$PATH"
ENV ERLANG_ROOT_DIR="/usr/lib/erlang"
ENV ERL_LIBS="/usr/lib/elixir/lib"

# Set up symlinks for Python
RUN rm -f /usr/bin/python && \
    ln -sf /usr/bin/python3 /usr/bin/python

# Verify installations
RUN python --version && \
    elixir --version

# Set the working directory
WORKDIR /app

# Install SSH and init system
RUN apk add --no-cache openssh-server openrc && \
    rc-update add sshd && \
    mkdir -p /run/openrc && \
    touch /run/openrc/softlevel && \
    echo 'root:root' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Generate host keys
RUN ssh-keygen -A

# Default command
CMD ["/sbin/init"]