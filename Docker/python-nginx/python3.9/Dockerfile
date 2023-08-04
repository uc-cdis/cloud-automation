FROM quay.io/cdis/amazonlinux:feat_GPE-788

RUN pip3 install gunicorn ddtrace

# Add demo app
COPY ./app /app
WORKDIR /app
USER nobody

CMD ["gunicorn"]