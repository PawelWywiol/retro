.PHONY: init up up-all down logs pull ps

init:
	./scripts/init.sh

up:
	docker compose up -d

up-all:
	docker compose --profile minerva up -d

down:
	docker compose --profile minerva down

logs:
	docker compose --profile minerva logs -f --tail=100

pull:
	docker compose --profile minerva pull

ps:
	docker compose --profile minerva ps
