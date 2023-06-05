FROM al2base

RUN pip3 install gunicorn ddtrace

# Add demo app
COPY ./app /app
WORKDIR /app
USER nobody

CMD ["gunicorn"]