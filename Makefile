
docker-image:
	docker build -t jackdanger/phonetics:latest .

docker-push: docker-image
	docker push jackdanger/phonetics:latest

docker: docker-image
	exec docker run -it -v $$(pwd):/app jackdanger/phonetics:latest bash

pry:
	pry -I ./lib -r phonetics
