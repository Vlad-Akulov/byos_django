# Slim, not the full image - the full image's package set only ever
# mattered for ImageMagick, and this image no longer uses it at all (see
# trmnl/consumers.py, trmnl/models.py - Pillow replaced wand/ImageMagick
# entirely, dropping perl/libraw/OpenEXR/glib-introspection along with it,
# not just the CLI tools).
FROM python:3.13-slim

WORKDIR /src

# done first so we can cache dependencies between code changes
COPY Pipfile Pipfile.lock ./
RUN pip install -U pipenv
RUN pipenv install --system

RUN apt-get update && apt-get install -y --no-install-recommends nginx && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY etc/nginx.conf /etc/nginx/sites-available/default

COPY . .

RUN python manage.py collectstatic --noinput

EXPOSE 8000

# Command to run
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
