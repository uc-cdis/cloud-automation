/* Entrypoint script for postgres container to set up databases and users for 
docker-compose setup */

CREATE DATABASE metadata_db;
CREATE DATABASE fence_db;
CREATE DATABASE indexd_db;

CREATE USER fence_user;
ALTER USER fence_user WITH PASSWORD 'fence_pass';
ALTER USER fence_user WITH SUPERUSER;

CREATE USER peregrine_user;
ALTER USER peregrine_user WITH PASSWORD 'peregrine_pass';
ALTER USER peregrine_user WITH SUPERUSER;

CREATE USER sheepdog_user;
ALTER USER sheepdog_user WITH PASSWORD 'sheepdog_pass';
ALTER USER sheepdog_user WITH SUPERUSER;

CREATE USER indexd_user;
ALTER USER indexd_user WITH PASSWORD 'indexd_pass';
ALTER USER indexd_user WITH SUPERUSER;
