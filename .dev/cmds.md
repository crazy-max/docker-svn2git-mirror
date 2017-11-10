docker build -t svngit -f ./Dockerfile .
docker run --rm -d --name svngit svngit
docker run --rm -i -t --name svngit svngit sh

docker-compose up -d --build
docker-compose exec svngit sh
docker-compose logs -f
docker-compose down
