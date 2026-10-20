# opstool

Internal ops tool. Python app + the old PHP admin pages + label jar.

## Run

    pip install -r requirements.txt
    python app.py            # :8080
    php -S 0.0.0.0:8081 -t web

Nightly job is in `jobs/nightly.sh` (cron on ops-box-02).

Config comes from `/etc/opstool.ini`. Ask Dave before changing anything in `core/`.
