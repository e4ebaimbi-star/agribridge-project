#First target is the default when you just type 'make'
help:
   @echo "Agribridge -Use:"
   @echo "make up    - Start with Compose"
   @echo "make down  - Stop Compose"
   @echo "make lint  - Helm lint ./chart"


up:
	docker compose up --build -d

down:
	docker compose down

logs:
	docker compose logs -f --tail 50

lint:
	helm lint ./chart