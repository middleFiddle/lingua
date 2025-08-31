# Demo React App + Lingua Integration Test
FROM node:18-alpine

# Install system dependencies 
RUN apk add --no-cache \
    curl \
    bash \
    tar \
    gzip \
    sudo

# Set working directory  
WORKDIR /app

# Create demo React app
RUN npx create-react-app@latest demo-react-i18n --template typescript
WORKDIR /app/demo-react-i18n

# Install i18n dependencies with legacy peer deps to handle TypeScript conflicts
RUN npm install react-i18next i18next i18next-browser-languagedetector --legacy-peer-deps

# Copy demo source files with i18n patterns
COPY demo-src/ src/

# Copy and run Lingua installer
COPY install.sh /tmp/install.sh
COPY lingua-0.1.0.tar.gz /tmp/lingua-release.tar.gz
RUN chmod +x /tmp/install.sh && \
    LINGUA_RELEASE_FILE=/tmp/lingua-release.tar.gz /tmp/install.sh

# Create demo workflow script
COPY demo-workflow.sh /app/demo-workflow.sh
RUN chmod +x /app/demo-workflow.sh

# Expose port for React dev server
EXPOSE 3000

# Default command runs the demo workflow
CMD ["/app/demo-workflow.sh"]