# HexStrike AI — 랩 전용 컨테이너 (core 도구만)
# 공식 Docker 없음(v7 예정) → 직접 빌드.
# 베이스: debian:bookworm-slim. (Kali 미러는 이 환경에서 .deb HTTPS 인증서 검증이 깨짐 —
#  TLS 를 끄는 대신 CA 가 최신인 Debian 으로 교체. vuln-bank 빌드가 Debian+HTTPS 로 정상 동작 확인됨.)
# core 도구: nmap·sqlmap·gobuster·whatweb·dirb (apt) + nuclei (공식 릴리스 바이너리, HTTPS).
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-pip python3-venv \
      nmap sqlmap gobuster whatweb dirb \
      curl wget unzip git ca-certificates openssl dnsutils iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# nuclei: Debian 에 없음 → 최신 릴리스 zip 을 HTTPS 로 받아 설치(Debian CA 검증 정상).
# GitHub API rate-limit 등으로 실패해도 빌드는 계속(서버는 도구 없이도 기동, 해당 명령만 실패).
RUN set -eux; \
    url="$(curl -sL https://api.github.com/repos/projectdiscovery/nuclei/releases/latest \
      | grep -o 'https://[^\"]*nuclei_[^\"]*linux_amd64.zip' | head -n1)"; \
    if [ -n "$url" ]; then \
      curl -sL "$url" -o /tmp/n.zip && unzip -o /tmp/n.zip -d /usr/local/bin nuclei \
      && chmod +x /usr/local/bin/nuclei && rm -f /tmp/n.zip; \
    fi; \
    nuclei -version || echo "nuclei unavailable (non-fatal)"

WORKDIR /app
COPY requirements.txt /app/requirements.txt
# Debian bookworm pip = PEP668 externally-managed → --break-system-packages.
RUN pip3 install --no-cache-dir --break-system-packages -r /app/requirements.txt \
    || pip3 install --no-cache-dir --break-system-packages flask requests psutil fastmcp beautifulsoup4

COPY . /app

# 컨테이너 간 도달 위해 0.0.0.0 바인딩 (기본 127.0.0.1이면 격리망에서 접근 불가)
ENV HEXSTRIKE_HOST=0.0.0.0 \
    HEXSTRIKE_PORT=8888
EXPOSE 8888
CMD ["python3", "hexstrike_server.py"]
