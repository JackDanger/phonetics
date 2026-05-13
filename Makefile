
CORPUS ?= ../madgab/data/common_ipa_transcriptions.json

site: rust/target/release/site-gen
	rust/target/release/site-gen $(CORPUS) _site

rust/target/release/site-gen:
	cd rust && cargo build --release --bin site-gen

site-clean:
	rm -rf _site

docker-image:
	docker build -t jackdanger/phonetics:latest .

docker-push: docker-image
	docker push jackdanger/phonetics:latest

docker: docker-image
	exec docker run -it -v $$(pwd):/app jackdanger/phonetics:latest bash

pry:
	pry -I ./lib -r phonetics
