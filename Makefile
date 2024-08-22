# Parameters
DOCKER_USERNAME=diva

VECTOR_NAME=vector
VECTOR_VERSION=v23.8.0

JAEGER_NAME=jaeger
JAEGER_VERSION=v23.8.0

build: build-reloader build-vector build-jaeger

build-vector:
	docker buildx build --platform linux/amd64 -f .docker/vector/Dockerfile --tag $(DOCKER_USERNAME)/$(VECTOR_NAME):$(VECTOR_VERSION) .

build-jaeger:
	docker buildx build --platform linux/amd64 -f .docker/jaeger/Dockerfile --tag $(DOCKER_USERNAME)/$(JAEGER_NAME):$(JAEGER_VERSION) .

run:
	docker compose up -d

stop:
	docker compose down

clean-vector:
	docker ps --filter name="$(VECTOR_NAME)*" --filter status=running -aq | xargs docker stop
	docker ps --filter name="$(VECTOR_NAME)*" -aq | xargs docker rm
	docker network ls --filter name="$(VECTOR_NAME)*" -q | xargs docker network rm
	docker image rm $(DOCKER_USERNAME)/$(VECTOR_NAME) -f

clean-jaeger:
	docker ps --filter name="$(JAEGER_NAME)*" --filter status=running -aq | xargs docker stop
	docker ps --filter name="$(JAEGER_NAME)*" -aq | xargs docker rm
	docker network ls --filter name="$(JAEGER_NAME)*" -q | xargs docker network rm
	docker image rm $(DOCKER_USERNAME)/$(JAEGER_NAME) -f

push-vector:
	docker push $(DOCKER_USERNAME)/$(VECTOR_NAME):$(VECTOR_VERSION)

push-jaeger:
	docker push $(DOCKER_USERNAME)/$(JAEGER_NAME):$(JAEGER_VERSION)
