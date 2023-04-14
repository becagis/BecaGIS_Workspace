pull:
	docker compose pull

up:
	docker compose up -d

build:
	docker compose build

down:
	docker compose down

shell:
	docker compose exec -u laradock workspace zsh

root-shell:
	docker compose exec -u root workspace zsh