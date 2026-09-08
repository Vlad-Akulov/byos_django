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

# libmagickwand-dev, not the `imagemagick` CLI package too: `wand` (see
# Pipfile) is a ctypes binding straight to libMagickWand, and this codebase
# never shells out to `convert`/`identify`/etc (confirmed - no subprocess
# call to ImageMagick's CLI anywhere in the app) - the CLI tools were
# always dead weight here, just less obviously than perl/libraw/OpenEXR.
# Still need the -dev variant specifically (not just the runtime lib)
# because ctypes.util.find_library() looks for the *unversioned* .so
# symlink, which Debian only ships in the -dev package - confirmed via the
# currently-deployed image's own installed package list.
# --no-install-recommends so apt doesn't pull in anything beyond what
# these actually require.
RUN apt-get update && apt-get install -y --no-install-recommends nginx libmagickwand-dev && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY etc/nginx.conf /etc/nginx/sites-available/default

COPY . .

RUN python manage.py collectstatic --noinput

EXPOSE 8000

# Command to run
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
