FROM willcliffy/godot-server-builder

RUN apt-get update && apt-get install -y netcat libfontconfig

WORKDIR /app
COPY client/ .

RUN godot --server --headless --export-pack "Linux/X11" gameserver.pck

EXPOSE 8080/tcp
CMD godot --server --headless --main-pack gameserver.pck
