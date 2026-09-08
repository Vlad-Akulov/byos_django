# Slim, not the full image - confirmed via a live deployment that the only
# reason the full image's package set mattered at all is ImageMagick
# (installed explicitly below now), which `wand` needs at runtime via
# ctypes/dlopen, not compiled in. Everything else the full image bundled
# (perl, a full MariaDB client, GObject introspection tooling, etc.) was
# unused bloat - each carrying its own share of CVEs for zero benefit.
FROM python:3.13-slim

WORKDIR /src

# done first so we can cache dependencies between code changes
COPY Pipfile Pipfile.lock ./
RUN pip install -U pipenv
RUN pipenv install --system

# imagemagick + libmagickwand-dev: `wand` (see Pipfile) is a ctypes binding
# to ImageMagick, not a compiled extension - it needs the library present
# at runtime, not just a build-time header. libmagickwand-dev specifically
# (not just the runtime lib) because ctypes.util.find_library() looks for
# the *unversioned* .so symlink, which Debian only ships in the -dev
# package, not the runtime one - confirmed via the currently-deployed
# image's own installed package list. --no-install-recommends so apt
# doesn't pull in anything beyond what these two packages actually
# require.
RUN apt-get update && apt-get install -y --no-install-recommends nginx imagemagick libmagickwand-dev && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY etc/nginx.conf /etc/nginx/sites-available/default

COPY . .

RUN python manage.py collectstatic --noinput

EXPOSE 8000

# Command to run
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
