
docker-image:
	docker build -t phonetics:latest .

docker: docker-image
	exec docker run -it -v $$(pwd):/app phonetics:latest bash
