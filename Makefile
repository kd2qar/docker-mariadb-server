
all: run

build:
	docker compose --pull

run: build
	docker compose up -d --remove-orphans

shell:
	docker compose exec -it mariadb /bin/bash

