#!/bin/bash

#Порождаем 3 контейнера без сети (нас докеровские сети не устраивают)

docker run -d --cap-add=NET_ADMIN --name="external-bird" --hostname="external-bird" --network=none -v "/var/lib/docker-extvols/external-bird/bird.conf:/etc/bird/bird.conf:ro" -v "/var/lib/docker-extvols/external-bird/bird.log:/var/log/bird.log:rw" -v "/var/lib/docker-extvols/external-bird/run:/usr/local/var/run" --restart=always inhavk/lab_bird:2.0.0

docker run -d --cap-add=NET_ADMIN --name="balancer-bird" --hostname="balancer-bird" --network=none -v "/var/lib/docker-extvols/balancer-bird/bird.conf:/etc/bird/bird.conf:ro" -v "/var/lib/docker-extvols/balancer-bird/bird.log:/var/log/bird.log:rw" -v "/var/lib/docker-extvols/balancer-bird/run:/usr/local/var/run" --restart=always inhavk/lab_bird:2.0.0

docker run -d --cap-add=NET_ADMIN --name="internal-bird" --hostname="internal-bird" --network=none -v "/var/lib/docker-extvols/internal-bird/bird.conf:/etc/bird/bird.conf:ro" -v "/var/lib/docker-extvols/internal-bird/bird.log:/var/log/bird.log:rw" -v "/var/lib/docker-extvols/internal-bird/run:/usr/local/var/run" --restart=always inhavk/lab_bird:2.0.0

#симлинки сетевых неймспейсов
mkdir -p /var/run/netns

ln -sf /proc/`docker inspect -f '{{.State.Pid}}' balancer-bird`/ns/net /var/run/netns/`docker inspect -f '{{.Name}}' balancer-bird | cut -c2-`
ln -sf /proc/`docker inspect -f '{{.State.Pid}}' external-bird`/ns/net /var/run/netns/`docker inspect -f '{{.Name}}' external-bird | cut -c2-`
ln -sf /proc/`docker inspect -f '{{.State.Pid}}' internal-bird`/ns/net /var/run/netns/`docker inspect -f '{{.Name}}' internal-bird | cut -c2-`

#создаем veth интерфейсы и прицепляем к неймспейсам (контейнерам)
ip link add veth1external type veth peer name veth2external
ip link set veth1external netns external-bird
ip link set veth2external netns balancer-bird

ip link add veth1internal type veth peer name veth2internal
ip link set veth1internal netns internal-bird
ip link set veth2internal netns balancer-bird

#устанавливаем нужные адреса и поднимаем интерфейсы внутри контейнеров
docker exec external-bird bash -c 'ip addr add 172.20.20.1/30 dev veth1external; ip link set veth1external up'
docker exec internal-bird bash -c 'ip addr add 172.20.30.1/30 dev veth1internal; ip link set veth1internal up'
docker exec balancer-bird bash -c 'ip addr add 172.20.20.2/30 dev veth2external; ip link set veth2external up; ip addr add 172.20.30.2/30 dev veth2internal; ip link set veth2internal up'

#снимаем блок на запуск bird-ов
docker exec external-bird touch /bird_run
docker exec internal-bird touch /bird_run
docker exec balancer-bird touch /bird_run

